import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS } from '@/lib/constants';

export async function GET(request: NextRequest) {
  const authResult = await verifyAuth(request, ['validator_admin']);
  if ('error' in authResult) return authResult.error;

  const snapshot = await adminDb.collection(COLLECTIONS.DOKUMEN_HASIL)
    .orderBy('tanggal_generate', 'desc')
    .limit(300)
    .get();
  const documents = await Promise.all(snapshot.docs.map(async (doc) => {
    const data = doc.data();
    const submission = typeof data.submission_id === 'string'
      ? await adminDb.collection(COLLECTIONS.SUBMISSIONS).doc(data.submission_id).get()
      : null;
    return {
      id: doc.id,
      ...data,
      submission_id: data.submission_id,
      submission: submission?.exists
        ? { id: submission.id, ...submission.data() }
        : null,
    };
  }));
  return NextResponse.json({ documents });
}
