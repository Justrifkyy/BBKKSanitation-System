import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS, SUBMISSION_STATUS } from '@/lib/constants';

/**
 * GET /api/submissions
 * List submissions with optional filters.
 * - kepala roles: only their own submissions
 * - staf_bbkk: all submissions (for review)
 * - validator_admin: all submissions (read-only)
 */
export async function GET(request: NextRequest) {
  const authResult = await verifyAuth(request);
  if ('error' in authResult) return authResult.error;

  const { user } = authResult;
  const { searchParams } = new URL(request.url);
  const status = searchParams.get('status');
  const moda = searchParams.get('moda_transportasi');

  let query: FirebaseFirestore.Query = adminDb.collection(COLLECTIONS.SUBMISSIONS);

  // Role-based filtering
  if (user.role === 'kepala_kapal' || user.role === 'kepala_penerbangan') {
    query = query.where('pengisi_id', '==', user.uid);
  }

  // Optional filters
  if (status) {
    query = query.where('status', '==', status);
  }
  if (moda) {
    query = query.where('moda_transportasi', '==', moda);
  }

  query = query.orderBy('created_at', 'desc').limit(50);

  const snapshot = await query.get();
  const submissions = snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  return NextResponse.json({ submissions });
}

/**
 * POST /api/submissions
 * Create a new self-declared submission.
 * Only kepala_kapal and kepala_penerbangan can create submissions.
 */
export async function POST(request: NextRequest) {
  const authResult = await verifyAuth(request, ['kepala_kapal', 'kepala_penerbangan']);
  if ('error' in authResult) return authResult.error;

  const { user } = authResult;
  const body = await request.json();

  const submission = {
    moda_transportasi: user.role === 'kepala_kapal' ? 'kapal' : 'pesawat',
    template_id: body.template_id,
    data_umum: body.data_umum,
    pengisi_id: user.uid,
    verifikator_id: null,
    status: SUBMISSION_STATUS.DRAFT,
    created_at: new Date(),
    updated_at: new Date(),
  };

  const docRef = await adminDb.collection(COLLECTIONS.SUBMISSIONS).add(submission);

  // Write audit log
  await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
    user_id: user.uid,
    aksi: 'submit_declaration',
    entitas_terkait: `submissions/${docRef.id}`,
    waktu: new Date(),
  });

  return NextResponse.json({ id: docRef.id, ...submission }, { status: 201 });
}
