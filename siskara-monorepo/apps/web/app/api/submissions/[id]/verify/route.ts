import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS, SUBMISSION_STATUS, DOCUMENT_TYPE, TRANSPORT_MODE } from '@/lib/constants';
import { isValidPin, verifyUserPin } from '@/lib/pin';

/**
 * POST /api/submissions/[id]/verify
 * staf_bbkk's approve/reject decision. This is FINAL and single-stage.
 * Approving triggers automatic document generation.
 * Role required: staf_bbkk ONLY.
 */
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id: submissionId } = await params;

  // CRITICAL: staf_bbkk only
  const authResult = await verifyAuth(request, ['staf_bbkk']);
  if ('error' in authResult) return authResult.error;

  const { user } = authResult;
  const body = await request.json();
  const { decision, catatan, pin } = body; // decision: 'approve' | 'reject'

  if (!['approve', 'reject'].includes(decision)) {
    return NextResponse.json(
      { error: 'Decision must be "approve" or "reject"' },
      { status: 400 }
    );
  }

  if (!isValidPin(pin)) {
    return NextResponse.json(
      { error: 'PIN harus terdiri dari 6 angka.' },
      { status: 400 }
    );
  }

  const pinCheck = await verifyUserPin(user.uid, pin);
  if (!pinCheck.valid) {
    return NextResponse.json(
      {
        error: pinCheck.locked
          ? 'PIN dikunci selama 15 menit setelah 5 percobaan yang salah.'
          : 'PIN tidak sesuai.',
      },
      { status: pinCheck.locked ? 429 : 403 }
    );
  }

  const verifierProfile = await adminDb.collection(COLLECTIONS.USERS).doc(user.uid).get();
  if (!verifierProfile.data()?.signature_url) {
    return NextResponse.json(
      { error: 'Tanda tangan digital belum disiapkan.' },
      { status: 409 }
    );
  }

  // Fetch submission
  const subDoc = await adminDb
    .collection(COLLECTIONS.SUBMISSIONS)
    .doc(submissionId)
    .get();

  if (!subDoc.exists) {
    return NextResponse.json({ error: 'Submission not found' }, { status: 404 });
  }

  const submission = subDoc.data()!;
  const submissionRef = adminDb.collection(COLLECTIONS.SUBMISSIONS).doc(submissionId);
  const signatureRef = adminDb
    .collection(COLLECTIONS.DOCUMENT_SIGNATURES)
    .doc(`${submissionId}_verifier`);

  // Must be in pending review status
  if (submission.status !== SUBMISSION_STATUS.PENDING_REVIEW) {
    return NextResponse.json(
      { error: `Cannot verify submission with status "${submission.status}"` },
      { status: 400 }
    );
  }

  if (decision === 'reject') {
    await adminDb.runTransaction(async (transaction) => {
      const current = await transaction.get(submissionRef);
      if (current.data()?.status !== SUBMISSION_STATUS.PENDING_REVIEW) {
        throw new Error('Pengajuan sudah diverifikasi oleh petugas lain.');
      }
      transaction.update(submissionRef, {
        status: SUBMISSION_STATUS.REJECTED_BY_STAFF,
        verifikator_id: user.uid,
        catatan_verifikator: catatan || null,
        updated_at: new Date(),
      });
      transaction.create(signatureRef, {
        submission_id: submissionId,
        user_id: user.uid,
        role_saat_ttd: 'verifikator',
        waktu_ttd: new Date(),
      });
    });

    // Audit log
    await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
      user_id: user.uid,
      aksi: 'reject',
      entitas_terkait: `submissions/${submissionId}`,
      waktu: new Date(),
    });

    return NextResponse.json({
      submission_id: submissionId,
      status: SUBMISSION_STATUS.REJECTED_BY_STAFF,
    });
  }

  // ─── APPROVE (final, triggers document generation) ───

  // Determine document type based on transport mode
  const jenisDokumen =
    submission.moda_transportasi === TRANSPORT_MODE.KAPAL
      ? DOCUMENT_TYPE.PHQC
      : DOCUMENT_TYPE.BERKAS_VERIFIKASI;

  // Update submission to final
  await adminDb.runTransaction(async (transaction) => {
    const current = await transaction.get(submissionRef);
    if (current.data()?.status !== SUBMISSION_STATUS.PENDING_REVIEW) {
      throw new Error('Pengajuan sudah diverifikasi oleh petugas lain.');
    }
    transaction.update(submissionRef, {
      status: SUBMISSION_STATUS.FINAL,
      verifikator_id: user.uid,
      updated_at: new Date(),
    });
    transaction.create(signatureRef, {
      submission_id: submissionId,
      user_id: user.uid,
      role_saat_ttd: 'verifikator',
      waktu_ttd: new Date(),
    });
  });

  // Create dokumen_hasil record (PDF generation is a separate step)
  const dokumenRef = await adminDb.collection(COLLECTIONS.DOKUMEN_HASIL).add({
    submission_id: submissionId,
    jenis_dokumen: jenisDokumen,
    file_pdf_url: '', // Will be populated by document generation
    status: 'draft',
    tanggal_generate: new Date(),
  });

  // TODO: Trigger PDF generation via /api/documents/[submissionId]/generate

  // Audit log
  await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
    user_id: user.uid,
    aksi: 'approve',
    entitas_terkait: `submissions/${submissionId}`,
    waktu: new Date(),
  });

  await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
    user_id: user.uid,
    aksi: 'generate_document',
    entitas_terkait: `dokumen_hasil/${dokumenRef.id}`,
    waktu: new Date(),
  });

  return NextResponse.json({
    submission_id: submissionId,
    status: SUBMISSION_STATUS.FINAL,
    jenis_dokumen: jenisDokumen,
    dokumen_hasil_id: dokumenRef.id,
  });
}
