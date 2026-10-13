import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS, SUBMISSION_STATUS } from '@/lib/constants';

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

  // Fetch answers
  const answersSnapshot = await adminDb
    .collection(COLLECTIONS.SUBMISSIONS)
    .doc(submissionId)
    .collection(COLLECTIONS.SUBMISSION_ANSWERS)
    .get();

  // Check if any answer has status_gagal = true
  const hasFailure = answersSnapshot.docs.some((doc) => doc.data().status_gagal === true);

  const newStatus = hasFailure
    ? SUBMISSION_STATUS.AUTO_REJECTED
    : SUBMISSION_STATUS.PENDING_REVIEW;

  // Update submission status
  await adminDb
    .collection(COLLECTIONS.SUBMISSIONS)
    .doc(submissionId)
    .update({
      status: newStatus,
      updated_at: new Date(),
    });

  // Audit log
  await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
    user_id: user.uid,
    aksi: hasFailure ? 'auto_reject' : 'pass_to_review',
    entitas_terkait: `submissions/${submissionId}`,
    waktu: new Date(),
  });

  return NextResponse.json({
    submission_id: submissionId,
    status: newStatus,
    has_failure: hasFailure,
  });
}
