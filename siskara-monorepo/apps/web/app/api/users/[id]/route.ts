import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminAuth, adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS } from '@/lib/constants';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await verifyAuth(request, ['validator_admin']);
  if ('error' in authResult) return authResult.error;

  const { id } = await params;
  const [profile, account] = await Promise.all([
    adminDb.collection(COLLECTIONS.USERS).doc(id).get(),
    adminAuth.getUser(id).catch((error: unknown) => {
      if (typeof error === 'object' && error !== null && 'code' in error &&
        error.code === 'auth/user-not-found') return null;
      throw error;
    }),
  ]);
  if (!profile.exists || !account) {
    return NextResponse.json({ error: 'Pengguna tidak ditemukan.' }, { status: 404 });
  }
  return NextResponse.json({
    user: { id, ...profile.data(), email: account.email ?? null, disabled: account.disabled },
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
  if (id === authResult.user.uid && body.is_active === false) {
    return NextResponse.json({ error: 'Akun admin yang sedang digunakan tidak dapat dinonaktifkan.' }, { status: 409 });
  }
  const profileRef = adminDb.collection(COLLECTIONS.USERS).doc(id);
  const profile = await profileRef.get();
  if (!profile.exists) {
    return NextResponse.json({ error: 'Pengguna tidak ditemukan.' }, { status: 404 });
  }

  const update: Record<string, unknown> = { updated_at: new Date() };

  // Allow updating role with custom claims synchronization
  if ('role' in body && typeof body.role === 'string') {
    const validRoles = ['kepala_kapal', 'kepala_penerbangan', 'staf_bbkk', 'validator_admin'];
    if (!validRoles.includes(body.role)) {
      return NextResponse.json({ error: 'Role tidak valid.' }, { status: 400 });
    }
    update.role = body.role;
    await adminAuth.setCustomUserClaims(id, { role: body.role });
  }

  if ('nama' in body) {
    if (typeof body.nama !== 'string' || !body.nama.trim()) {
      return NextResponse.json({ error: 'Nama tidak boleh kosong.' }, { status: 400 });
    }
    update.nama = body.nama.trim();
  }
  if ('phone' in body) {
    if (typeof body.phone !== 'string' || !body.phone.trim()) {
      return NextResponse.json({ error: 'Nomor telepon tidak boleh kosong.' }, { status: 400 });
    }
    update.phone = body.phone.trim();
  }
  if ('id_number' in body) {
    if (body.id_number !== null && typeof body.id_number !== 'string') {
      return NextResponse.json({ error: 'Nomor identitas tidak valid.' }, { status: 400 });
    }
    update.id_number = typeof body.id_number === 'string' && body.id_number.trim() ? body.id_number.trim() : null;
  }

  // Update password if provided
  if ('password' in body && typeof body.password === 'string' && body.password.length > 0) {
    if (body.password.length < 6) {
      return NextResponse.json({ error: 'Kata sandi minimal 6 karakter.' }, { status: 400 });
    }
    await adminAuth.updateUser(id, { password: body.password });
  }

  // Update email if provided
  if ('email' in body && typeof body.email === 'string' && body.email.trim()) {
    const newEmail = body.email.trim();
    await adminAuth.updateUser(id, { email: newEmail });
    update.email = newEmail;
  }

  const account = await adminAuth.getUser(id);
  if (typeof body.is_active === 'boolean') {
    await adminAuth.updateUser(id, { disabled: !body.is_active });
    update.is_active = body.is_active;
  }
  if (typeof update.nama === 'string') {
    await adminAuth.updateUser(id, { displayName: update.nama });
  }
  await profileRef.update(update);
  await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
    user_id: authResult.user.uid,
    aksi: typeof body.is_active === 'boolean'
      ? body.is_active ? 'activate_user' : 'deactivate_user'
      : 'update_user',
    entitas_terkait: `users/${id}`,
    detail: { updated_fields: Object.keys(update) },
    waktu: new Date(),
  });
  return NextResponse.json({
    user: { id, ...profile.data(), ...update, email: account.email ?? null, disabled: typeof body.is_active === 'boolean' ? !body.is_active : account.disabled },
  });
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await verifyAuth(request, ['validator_admin']);
  if ('error' in authResult) return authResult.error;

  const { id } = await params;
  if (id === authResult.user.uid) {
    return NextResponse.json(
      { error: 'Akun admin yang sedang Anda gunakan tidak dapat dihapus.' },
      { status: 409 },
    );
  }

  // Delete from Firebase Auth
  await adminAuth.deleteUser(id).catch((err: unknown) => {
    if (typeof err === 'object' && err !== null && 'code' in err && (err as { code: string }).code === 'auth/user-not-found') {
      return;
    }
    throw err;
  });

  // Delete Firestore profile
  await adminDb.collection(COLLECTIONS.USERS).doc(id).delete();

  // Audit log
  await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
    user_id: authResult.user.uid,
    aksi: 'delete_user',
    entitas_terkait: `users/${id}`,
    waktu: new Date(),
  });

  return NextResponse.json({ success: true, message: 'Akun berhasil dihapus permanen.' });
}
