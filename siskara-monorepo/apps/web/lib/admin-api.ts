import type { User } from 'firebase/auth';

export async function adminFetch<T>(
  user: User,
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const token = await user.getIdToken();
  const response = await fetch(path, {
    ...init,
    headers: {
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...init.headers,
      Authorization: `Bearer ${token}`,
    },
    cache: 'no-store',
  });
  const result = await response.json() as T & { error?: string };
  if (!response.ok) {
    throw new Error(result.error || `Permintaan gagal (${response.status}).`);
  }
  return result;
}

export function formatAdminDate(value: unknown): string {
  let date: Date | null = null;
  if (value instanceof Date) date = value;
  else if (typeof value === 'string' || typeof value === 'number') date = new Date(value);
  else if (value && typeof value === 'object') {
    const record = value as { seconds?: unknown; _seconds?: unknown };
    const seconds = typeof record.seconds === 'number' ? record.seconds : record._seconds;
    if (typeof seconds === 'number') date = new Date(seconds * 1000);
  }
  if (!date || Number.isNaN(date.getTime())) return '—';
  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
}
