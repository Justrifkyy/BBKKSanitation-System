import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminAuth, adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS } from '@/lib/constants';

/**
 * GET /api/users
 * List all users. Role required: validator_admin or staf_bbkk.
 */
export async function GET(request: NextRequest) {
  const authResult = await verifyAuth(request, ['validator_admin', 'staf_bbkk']);
  if ('error' in authResult) return authResult.error;

  const { searchParams } = new URL(request.url);
  const role = searchParams.get('role');

  let query: FirebaseFirestore.Query = adminDb.collection(COLLECTIONS.USERS);

  if (role) {
    query = query.where('role', '==', role);
  }

  query = query.orderBy('created_at', 'desc').limit(100);

  const snapshot = await query.get();
  const users = snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  return NextResponse.json({ users });
}

/**
 * POST /api/users
 * Create a new user and set their custom claim role.
 * validator_admin can create any role.
 * staf_bbkk can only create kepala_kapal or kepala_penerbangan.
 */
export async function POST(request: NextRequest) {
  const authResult = await verifyAuth(request, ['validator_admin', 'staf_bbkk']);
  if ('error' in authResult) return authResult.error;

  const { user: admin } = authResult;
  const body = await request.json();
  const { email, password, nama, phone, role, id_number } = body;

  // Validate required fields
  if (!email || !password || !nama || !phone || !role) {
    return NextResponse.json(
      { error: 'Missing required fields: email, password, nama, phone, role' },
      { status: 400 }
    );
  }

  // staf_bbkk can only create kepala roles
  if (
    admin.role === 'staf_bbkk' &&
    !['kepala_kapal', 'kepala_penerbangan'].includes(role)
  ) {
    return NextResponse.json(
      { error: 'staf_bbkk can only create kepala_kapal or kepala_penerbangan accounts' },
      { status: 403 }
    );
  }

  try {
    // Create Firebase Auth user
    const userRecord = await adminAuth.createUser({
      email,
      password,
      displayName: nama,
    });

    // Set custom claim for role
    await adminAuth.setCustomUserClaims(userRecord.uid, { role });

    // Create Firestore user document (mirror)
    await adminDb.collection(COLLECTIONS.USERS).doc(userRecord.uid).set({
      nama,
      role,
      phone,
      id_number: id_number || null,
      signature_url: null,
      pin_hash: null,
      dibuat_oleh: admin.uid,
      created_at: new Date(),
    });

    // Audit log
    await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
      user_id: admin.uid,
      aksi: 'create_user',
      entitas_terkait: `users/${userRecord.uid}`,
      waktu: new Date(),
    });

    return NextResponse.json(
      { id: userRecord.uid, nama, role, phone },
      { status: 201 }
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
