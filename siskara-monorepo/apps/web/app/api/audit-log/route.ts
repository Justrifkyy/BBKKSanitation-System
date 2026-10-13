import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS } from '@/lib/constants';

export async function GET(request: NextRequest) {
  const authResult = await verifyAuth(request, ['validator_admin']);
  if ('error' in authResult) return authResult.error;
  const { searchParams } = new URL(request.url);
  const action = searchParams.get('aksi');
  const snapshot = await adminDb.collection(COLLECTIONS.AUDIT_LOG)
    .orderBy('waktu', 'desc')
    .limit(500)
    .get();
  const logs = snapshot.docs
    .map((doc): Record<string, unknown> & { id: string } => ({
      id: doc.id,
      ...(doc.data() as Record<string, unknown>),
    }))
    .filter((log) => !action || log.aksi === action);
  const userIds = [...new Set(logs.map((log) => log.user_id).filter((id): id is string => typeof id === 'string'))];
  const users = await Promise.all(userIds.map((id) => adminDb.collection(COLLECTIONS.USERS).doc(id).get()));
  const names = new Map(users.filter((user) => user.exists).map((user) => [user.id, user.data()?.nama ?? user.id]));
  return NextResponse.json({
    logs: logs.map((log) => ({
      ...log,
      nama_pengguna: typeof log.user_id === 'string' ? names.get(log.user_id) ?? 'Pengguna tidak ditemukan' : 'Sistem',
    })),
  });
}
