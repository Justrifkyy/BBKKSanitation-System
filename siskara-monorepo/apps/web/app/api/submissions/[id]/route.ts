import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS, SUBMISSION_STATUS } from '@/lib/constants';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await verifyAuth(request, ['validator_admin', 'staf_bbkk']);
  if ('error' in authResult) return authResult.error;
  const { id } = await params;
  const submissionRef = adminDb.collection(COLLECTIONS.SUBMISSIONS).doc(id);
  const snapshot = await submissionRef.get();
  if (!snapshot.exists) {
    return NextResponse.json({ error: 'Pengajuan tidak ditemukan.' }, { status: 404 });
  }
  const submission = snapshot.data()!;
  const [answersSnapshot, signaturesSnapshot, documentsSnapshot, declarant, verifier] =
    await Promise.all([
      submissionRef.collection(COLLECTIONS.SUBMISSION_ANSWERS).get(),
      adminDb.collection(COLLECTIONS.DOCUMENT_SIGNATURES).where('submission_id', '==', id).get(),
      adminDb.collection(COLLECTIONS.DOKUMEN_HASIL).where('submission_id', '==', id).limit(1).get(),
      typeof submission.pengisi_id === 'string'
        ? adminDb.collection(COLLECTIONS.USERS).doc(submission.pengisi_id).get()
        : Promise.resolve(null),
      typeof submission.verifikator_id === 'string'
        ? adminDb.collection(COLLECTIONS.USERS).doc(submission.verifikator_id).get()
        : Promise.resolve(null),
    ]);

  const answers = await Promise.all(answersSnapshot.docs.map(async (answer) => {
    const [media, templateItem] = await Promise.all([
      answer.ref.collection(COLLECTIONS.SUBMISSION_ANSWER_MEDIA).get(),
      typeof answer.data().template_item_id === 'string'
        ? adminDb.collection(COLLECTIONS.CHECKLIST_TEMPLATES)
            .doc(String(submission.template_id))
            .collection(COLLECTIONS.CHECKLIST_TEMPLATE_ITEMS)
            .doc(answer.data().template_item_id)
            .get()
        : Promise.resolve(null),
    ]);
    return {
      id: answer.id,
      ...answer.data(),
      item: templateItem?.exists ? { id: templateItem.id, ...templateItem.data() } : null,
      media: media.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    };
  }));

  return NextResponse.json({
    submission: {
      id,
      ...submission,
      pengisi: declarant?.exists
        ? { id: declarant.id, nama: declarant.data()?.nama ?? null }
        : null,
      verifikator: verifier?.exists
        ? { id: verifier.id, nama: verifier.data()?.nama ?? null }
        : null,
      answers,
      signatures: signaturesSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
      document: documentsSnapshot.empty
        ? null
        : { id: documentsSnapshot.docs[0].id, ...documentsSnapshot.docs[0].data() },
    },
  });
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await verifyAuth(request, ['validator_admin']);
  if ('error' in authResult) return authResult.error;

  const { id } = await params;
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Body JSON tidak valid.' }, { status: 400 });
  }

  const submissionRef = adminDb.collection(COLLECTIONS.SUBMISSIONS).doc(id);
  const snapshot = await submissionRef.get();
  if (!snapshot.exists) {
    return NextResponse.json({ error: 'Pengajuan tidak ditemukan.' }, { status: 404 });
  }

  const currentData = snapshot.data()!;
  const update: Record<string, unknown> = { updated_at: new Date() };

  // Status update
  if (typeof body.status === 'string') {
    const validStatuses = ['final', 'ditolak_staf', 'menunggu_verifikasi_staf', 'draft', 'ditolak_otomatis'];
    if (!validStatuses.includes(body.status)) {
      return NextResponse.json({ error: 'Status pengajuan tidak valid.' }, { status: 400 });
    }
    update.status = body.status;
    update.verifikator_id = authResult.user.uid;
    if (body.status === 'final') {
      update.verified_at = new Date();
    }
  }

  // Verifier notes
  if ('catatan_verifikator' in body) {
    update.catatan_verifikator = typeof body.catatan_verifikator === 'string'
      ? body.catatan_verifikator.trim()
      : null;
  }

  // General data update
  if (typeof body.data_umum === 'object' && body.data_umum !== null) {
    update.data_umum = {
      ...(currentData.data_umum ?? {}),
      ...(body.data_umum as Record<string, unknown>),
    };
  }

  await submissionRef.update(update);

  // If status is updated to final, ensure a dokumen_hasil record exists
  if (update.status === 'final') {
    const docQuery = await adminDb.collection(COLLECTIONS.DOKUMEN_HASIL).where('submission_id', '==', id).limit(1).get();
    if (docQuery.empty) {
      const jenisDokumen = currentData.moda_transportasi === 'kapal' ? 'phqc' : 'berkas_verifikasi';
      await adminDb.collection(COLLECTIONS.DOKUMEN_HASIL).add({
        submission_id: id,
        jenis_dokumen: jenisDokumen,
        file_pdf_url: '',
        status: 'terbit',
        tanggal_generate: new Date(),
        dibuat_oleh: authResult.user.uid,
      });
    } else {
      await docQuery.docs[0].ref.update({
        status: 'terbit',
        updated_at: new Date(),
      });
    }
  }

  await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
    user_id: authResult.user.uid,
    aksi: 'admin_update_submission',
    entitas_terkait: `submissions/${id}`,
    detail: { status: update.status, catatan: update.catatan_verifikator },
    waktu: new Date(),
  });

  return NextResponse.json({
    success: true,
    submission: { id, ...currentData, ...update },
  });
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await verifyAuth(request, ['validator_admin']);
  if ('error' in authResult) return authResult.error;

  const { id } = await params;
  const submissionRef = adminDb.collection(COLLECTIONS.SUBMISSIONS).doc(id);
  const snapshot = await submissionRef.get();
  if (!snapshot.exists) {
    return NextResponse.json({ error: 'Pengajuan tidak ditemukan.' }, { status: 404 });
  }

  // Delete answers and subcollections
  const answersSnapshot = await submissionRef.collection(COLLECTIONS.SUBMISSION_ANSWERS).get();
  for (const answerDoc of answersSnapshot.docs) {
    const mediaSnapshot = await answerDoc.ref.collection(COLLECTIONS.SUBMISSION_ANSWER_MEDIA).get();
    for (const mediaDoc of mediaSnapshot.docs) {
      await mediaDoc.ref.delete();
    }
    await answerDoc.ref.delete();
  }

  // Delete related dokumen_hasil
  const docSnapshot = await adminDb.collection(COLLECTIONS.DOKUMEN_HASIL).where('submission_id', '==', id).get();
  for (const d of docSnapshot.docs) {
    await d.ref.delete();
  }

  // Delete related signatures
  const sigSnapshot = await adminDb.collection(COLLECTIONS.DOCUMENT_SIGNATURES).where('submission_id', '==', id).get();
  for (const s of sigSnapshot.docs) {
    await s.ref.delete();
  }

  // Delete submission document itself
  await submissionRef.delete();

  await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
    user_id: authResult.user.uid,
    aksi: 'admin_delete_submission',
    entitas_terkait: `submissions/${id}`,
    waktu: new Date(),
  });

  return NextResponse.json({ success: true, message: 'Pengajuan berhasil dihapus.' });
}
