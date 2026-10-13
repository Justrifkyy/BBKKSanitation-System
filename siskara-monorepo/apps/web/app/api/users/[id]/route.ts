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
  if ('role' in body || 'role_id' in body) {
    return NextResponse.json({ error: 'Role pengguna bersifat tetap dan tidak dapat diubah.' }, { status: 400 });
  }

  const update: Record<string, unknown> = { updated_at: new Date() };
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
    waktu: new Date(),
  });
  return NextResponse.json({
    user: { id, ...profile.data(), ...update, email: account.email ?? null, disabled: typeof body.is_active === 'boolean' ? !body.is_active : account.disabled },
  });
}

export async function DELETE(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const response = await PATCH(
    new NextRequest(request.url, {
      method: 'PATCH',
      headers: request.headers,
      body: JSON.stringify({ is_active: false }),
    }),
    { params: Promise.resolve({ id }) },
  );
  if (response.ok) {
    return NextResponse.json({ success: true, is_active: false });
  }
  return response;
}
