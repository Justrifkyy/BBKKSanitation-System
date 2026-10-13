import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS } from '@/lib/constants';

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
