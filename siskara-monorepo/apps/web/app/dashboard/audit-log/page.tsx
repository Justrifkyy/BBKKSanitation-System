'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { AdminShell, useAdmin } from '../admin-shell';
import { adminFetch, formatAdminDate } from '@/lib/admin-api';

type AuditEntry = {
  id: string;
  aksi?: string;
  entitas_terkait?: string;
  waktu?: unknown;
  user_id?: string;
  nama_pengguna?: string;
};
type AuditResponse = { logs: AuditEntry[] };

function AuditContent() {
  const { user } = useAdmin();
  const [logs, setLogs] = useState<AuditEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [action, setAction] = useState('semua');
  const [search, setSearch] = useState('');

  const load = useCallback(async () => {
    try {
      const result = await adminFetch<AuditResponse>(user, '/api/audit-log');
      setLogs(result.logs);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Log aktivitas tidak dapat dimuat.');
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    let active = true;
    void adminFetch<AuditResponse>(user, '/api/audit-log')
      .then((result) => { if (active) setLogs(result.logs); })
      .catch((cause: unknown) => {
        if (active) setError(cause instanceof Error ? cause.message : 'Log aktivitas tidak dapat dimuat.');
      })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [user]);

  const actions = useMemo(() => [...new Set(logs.map((log) => log.aksi).filter((value): value is string => Boolean(value)))].sort(), [logs]);
  const visible = useMemo(() => {
    const term = search.trim().toLocaleLowerCase('id-ID');
    return logs.filter((log) =>
      (action === 'semua' || log.aksi === action) &&
      (!term || [log.nama_pengguna, log.entitas_terkait, log.user_id, log.aksi]
        .some((value) => value?.toLocaleLowerCase('id-ID').includes(term))),
    );
  }, [action, logs, search]);

  return <>
    <section className="admin-page-heading"><div><span className="eyebrow">AUDITABILITAS</span><h1>Log aktivitas</h1><p>Jejak tindakan pengguna dan perubahan sistem yang tercatat pada koleksi audit_log.</p></div><button className="button button--secondary" type="button" onClick={() => { setLoading(true); void load(); }} disabled={loading}>Perbarui</button></section>
    {error && <p className="admin-error" role="alert">{error}</p>}
    <section className="admin-card">
      <div className="admin-toolbar">
        <input className="admin-input admin-search" type="search" placeholder="Cari aktor, entitas, atau tindakan…" value={search} onChange={(event) => setSearch(event.target.value)} />
        <select className="admin-select" aria-label="Filter jenis tindakan" value={action} onChange={(event) => setAction(event.target.value)}><option value="semua">Semua tindakan</option>{actions.map((item) => <option value={item} key={item}>{item.replaceAll('_', ' ')}</option>)}</select>
      </div>
      <div className="admin-table-wrap"><table className="admin-table">
        <thead><tr><th>Waktu</th><th>Pengguna</th><th>Tindakan</th><th>Entitas terkait</th></tr></thead>
        <tbody>{loading ? <tr><td colSpan={4} className="admin-empty">Memuat log…</td></tr>
          : visible.length ? visible.map((log) => <tr key={log.id}>
            <td>{formatAdminDate(log.waktu)}</td><td><span className="admin-cell-stack"><strong>{log.nama_pengguna ?? '—'}</strong><small>{log.user_id ?? '—'}</small></span></td><td>{log.aksi?.replaceAll('_', ' ') ?? '—'}</td><td>{log.entitas_terkait ?? '—'}</td>
          </tr>) : <tr><td colSpan={4} className="admin-empty">Tidak ada aktivitas untuk filter ini.</td></tr>}
        </tbody>
      </table></div>
      <p className="table-footnote">Menampilkan maksimal 500 entri terbaru. Log aktivitas ditampilkan apa adanya dan tidak dapat diedit dari portal.</p>
    </section>
  </>;
}

export default function AuditLogPage() {
  return <AdminShell title="Log aktivitas"><AuditContent /></AdminShell>;
}
