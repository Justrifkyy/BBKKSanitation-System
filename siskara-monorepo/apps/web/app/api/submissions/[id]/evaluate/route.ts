import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS } from '@/lib/constants';
import {
  evaluateSubmissionAnswers,
  SubmissionValidationError,
} from '@/lib/submission-evaluation';

/**
 * POST /api/submissions/[id]/evaluate
 * Server-side auto-reject evaluation against the active checklist template rules.
 * Called right after the kepala submits. Sets status to
 * `ditolak_otomatis` or `menunggu_verifikasi_staf`.
 */
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id: submissionId } = await params;

  const authResult = await verifyAuth(request, ['kepala_kapal', 'kepala_penerbangan']);
  if ('error' in authResult) return authResult.error;

  const { user } = authResult;

  // Fetch submission
  const subDoc = await adminDb
    .collection(COLLECTIONS.SUBMISSIONS)
    .doc(submissionId)
    .get();

  if (!subDoc.exists) {
    return NextResponse.json({ error: 'Submission not found' }, { status: 404 });
  }

  const submission = subDoc.data()!;

  // Verify ownership
  if (submission.pengisi_id !== user.uid) {
    return NextResponse.json({ error: 'Not your submission' }, { status: 403 });
  }

  const declarantSignature = await adminDb
    .collection(COLLECTIONS.DOCUMENT_SIGNATURES)
    .doc(`${submissionId}_declarant`)
    .get();
  if (!declarantSignature.exists) {
    return NextResponse.json(
      { error: 'Deklarasi harus ditandatangani dan dikonfirmasi dengan PIN.' },
      { status: 409 }
    );
  }

  const submissionRef = adminDb
    .collection(COLLECTIONS.SUBMISSIONS)
    .doc(submissionId);
  let evaluation: Awaited<ReturnType<typeof evaluateSubmissionAnswers>>;
  try {
    evaluation = await evaluateSubmissionAnswers(submissionRef);
  } catch (error) {
    if (error instanceof SubmissionValidationError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }
    throw error;
  }

  // Update submission status
  await submissionRef.update({
      status: evaluation.status,
      updated_at: new Date(),
    });

  // Audit log
  await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
    user_id: user.uid,
    aksi: evaluation.hasAutoReject ? 'auto_reject' : 'pass_to_review',
    entitas_terkait: `submissions/${submissionId}`,
    waktu: new Date(),
  });

  return NextResponse.json({
    submission_id: submissionId,
    status: evaluation.status,
    has_failure: evaluation.hasAutoReject,
  });
}
