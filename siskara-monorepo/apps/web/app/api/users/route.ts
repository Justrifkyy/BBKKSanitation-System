import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminAuth, adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS } from '@/lib/constants';

const USER_ROLES = [
  'kepala_kapal',
  'kepala_penerbangan',
  'staf_bbkk',
  'validator_admin',
] as const;

/**
 * GET /api/users
 * List all users. Role required: validator_admin or staf_bbkk.
 */
export async function GET(request: NextRequest) {
  const authResult = await verifyAuth(request, ['validator_admin', 'staf_bbkk']);
  if ('error' in authResult) return authResult.error;

  const { searchParams } = new URL(request.url);
  const role = searchParams.get('role');
  const search = searchParams.get('search')?.trim().toLocaleLowerCase('id-ID');

  let query: FirebaseFirestore.Query = adminDb.collection(COLLECTIONS.USERS);

  if (role && !USER_ROLES.includes(role as (typeof USER_ROLES)[number])) {
    return NextResponse.json({ error: 'Filter role tidak valid.' }, { status: 400 });
  }
  if (role) {
    query = query.where('role', '==', role);
  }

  query = query.orderBy('created_at', 'desc').limit(500);

  const snapshot = await query.get();
  const profiles = snapshot.docs
    .map((doc): Record<string, unknown> & { id: string } => ({
      id: doc.id,
      ...(doc.data() as Record<string, unknown>),
    }))
    .filter((user) => {
      if (!search) return true;
      return [user.nama, user.phone, user.id_number, user.role]
        .some((value) => typeof value === 'string' && value.toLocaleLowerCase('id-ID').includes(search));
    });
  const accountGroups = await Promise.all(
    Array.from({ length: Math.ceil(profiles.length / 100) }, (_, index) =>
      adminAuth.getUsers(
        profiles.slice(index * 100, (index + 1) * 100).map((profile) => ({ uid: profile.id })),
      ),
    ),
  );
  const accounts = new Map(
    accountGroups.flatMap((group) => group.users.map((account) => [account.uid, account] as const)),
  );
  const users = profiles.map((profile) => {
    const account = accounts.get(profile.id);
    return {
      ...profile,
      email: account?.email ?? null,
      is_active: Boolean(account && !account.disabled && profile.is_active !== false),
    };
  });

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
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Body JSON tidak valid.' }, { status: 400 });
  }
  const { email, password, nama, phone, role, id_number } = body;

  if (
    typeof email !== 'string' ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
    typeof password !== 'string' ||
    password.length < 6 ||
    typeof nama !== 'string' ||
    !nama.trim() ||
    typeof phone !== 'string' ||
    !phone.trim() ||
    typeof role !== 'string' ||
    !USER_ROLES.includes(role as (typeof USER_ROLES)[number])
  ) {
    return NextResponse.json(
      { error: 'Nama, email valid, nomor telepon, role, dan kata sandi minimal 6 karakter wajib diisi.' },
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

  let createdUid: string | null = null;
  try {
    // Create Firebase Auth user
    const userRecord = await adminAuth.createUser({
      email: email.trim().toLowerCase(),
      password,
      displayName: nama.trim(),
      disabled: false,
    });
    createdUid = userRecord.uid;

    // Set custom claim for role
    await adminAuth.setCustomUserClaims(userRecord.uid, { role });

    // Create Firestore user document (mirror)
    await adminDb.collection(COLLECTIONS.USERS).doc(userRecord.uid).set({
      nama: nama.trim(),
      role,
      role_id: role,
      phone: phone.trim(),
      id_number: typeof id_number === 'string' && id_number.trim() ? id_number.trim() : null,
      signature_url: null,
      has_pin: false,
      dibuat_oleh: admin.uid,
      is_active: true,
      created_at: new Date(),
      updated_at: new Date(),
    });

    // Audit log
    await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
      user_id: admin.uid,
      aksi: 'create_user',
      entitas_terkait: `users/${userRecord.uid}`,
      waktu: new Date(),
    });

    return NextResponse.json(
      { id: userRecord.uid, nama: nama.trim(), role, phone: phone.trim(), email: userRecord.email },
      { status: 201 }
    );
  } catch (error: unknown) {
    if (createdUid) {
      await adminAuth.deleteUser(createdUid).catch((cleanupError: unknown) => {
        console.error('Failed to clean up partially created Firebase Auth user.', cleanupError);
      });
      await adminDb.collection(COLLECTIONS.USERS).doc(createdUid).delete().catch((cleanupError: unknown) => {
        console.error('Failed to clean up partially created Firestore profile.', cleanupError);
      });
    }
    const message = error instanceof Error ? error.message : 'Unknown error';
    const status = typeof error === 'object' && error !== null && 'code' in error &&
      (error.code === 'auth/email-already-exists' || error.code === 'auth/invalid-password')
      ? 400
      : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
