'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { AdminShell, useAdmin } from '../admin-shell';
import { adminFetch, formatAdminDate } from '@/lib/admin-api';

type Submission = {
  id: string;
  moda_transportasi?: string;
  status?: string;
  created_at?: unknown;
  data_umum?: Record<string, unknown>;
  pengisi_id?: string;
  verifikator_id?: string | null;
};
type SubmissionResponse = { submissions: Submission[] };
type Answer = {
  id: string;
  template_item_id?: string;
  nilai_jawaban?: unknown;
  alasan?: string;
  status_gagal?: boolean;
  item?: { label?: string; kategori?: string } | null;
  media?: { id: string; tipe?: string; file_url?: string; timestamp?: unknown; gps?: unknown }[];
};
type SubmissionDetail = Submission & {
  pengisi?: { id: string; nama?: string | null } | null;
  verifikator?: { id: string; nama?: string | null } | null;
  answers?: Answer[];
  catatan_verifikator?: string | null;
  document?: { file_pdf_url?: string; jenis_dokumen?: string; status?: string } | null;
};
type DetailResponse = { submission: SubmissionDetail };
type SignedUrlResponse = { download_url: string };

const statusLabels: Record<string, string> = {
  draft: 'Draft',
  ditolak_otomatis: 'Ditolak otomatis',
  menunggu_verifikasi_staf: 'Menunggu verifikasi',
  ditolak_staf: 'Ditolak staf',
  final: 'Selesai',
};

function summaryName(submission: Submission) {
  const data = submission.data_umum ?? {};
  const value = submission.moda_transportasi === 'kapal' ? data.nama_kapal : data.nomor_penerbangan;
  return typeof value === 'string' && value.trim() ? value : 'Data belum tersedia';
}

function printable(value: unknown) {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') return String(value);
  return JSON.stringify(value);
}

function SubmissionsContent() {
  const { user } = useAdmin();
  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('semua');
  const [mode, setMode] = useState('semua');
  const [selected, setSelected] = useState<SubmissionDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [openingMedia, setOpeningMedia] = useState('');

  const load = useCallback(async () => {
    try {
      const result = await adminFetch<SubmissionResponse>(user, '/api/submissions');
      setSubmissions(result.submissions);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Pengajuan gagal dimuat.');
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    let active = true;
    void adminFetch<SubmissionResponse>(user, '/api/submissions')
      .then((result) => { if (active) setSubmissions(result.submissions); })
      .catch((cause: unknown) => {
        if (active) setError(cause instanceof Error ? cause.message : 'Pengajuan gagal dimuat.');
      })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [user]);

  const visible = useMemo(() => {
    const term = search.trim().toLocaleLowerCase('id-ID');
    return submissions.filter((submission) => {
      const matchesStatus = status === 'semua' || submission.status === status;
      const matchesMode = mode === 'semua' || submission.moda_transportasi === mode;
      const fields = [summaryName(submission), submission.id, ...Object.values(submission.data_umum ?? {})];
      return matchesStatus && matchesMode && (!term || fields.some((value) => printable(value).toLocaleLowerCase('id-ID').includes(term)));
    });
  }, [mode, search, status, submissions]);

  async function showDetail(record: Submission) {
    setDetailLoading(true);
    setError('');
    try {
      const result = await adminFetch<DetailResponse>(user, `/api/submissions/${encodeURIComponent(record.id)}`);
      setSelected(result.submission);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Detail pengajuan gagal dimuat.');
    } finally {
      setDetailLoading(false);
    }
  }

  async function openMedia(path: string) {
    setOpeningMedia(path);
    setError('');
    try {
      const result = await adminFetch<SignedUrlResponse>(user, '/api/uploads/download', {
        method: 'POST',
        body: JSON.stringify({ storage_path: path }),
      });
      window.open(result.download_url, '_blank', 'noopener,noreferrer');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Bukti media tidak dapat dibuka.');
    } finally {
      setOpeningMedia('');
    }
  }

  return <>
    <section className="admin-page-heading"><div><span className="eyebrow">PEMANTAUAN</span><h1>Pengajuan</h1><p>Daftar deklarasi dari nahkoda dan pilot. Admin memiliki akses baca saja dan tidak dapat memberi keputusan verifikasi.</p></div><button className="button button--secondary" type="button" disabled={loading} onClick={() => { setLoading(true); void load(); }}>Perbarui</button></section>
    {error && <p className="admin-error" role="alert">{error}</p>}
    <section className="admin-card">
      <div className="admin-toolbar">
        <input className="admin-input admin-search" type="search" placeholder="Cari kapal, nomor penerbangan, ID…" value={search} onChange={(event) => setSearch(event.target.value)} />
        <div className="admin-toolbar__filters">
          <select className="admin-select" value={mode} onChange={(event) => setMode(event.target.value)} aria-label="Filter moda"><option value="semua">Semua moda</option><option value="kapal">Kapal</option><option value="pesawat">Pesawat</option></select>
          <select className="admin-select" value={status} onChange={(event) => setStatus(event.target.value)} aria-label="Filter status"><option value="semua">Semua status</option>{Object.entries(statusLabels).map(([value, label]) => <option value={value} key={value}>{label}</option>)}</select>
        </div>
      </div>
      <div className="admin-table-wrap"><table className="admin-table">
        <thead><tr><th>Identitas</th><th>Moda</th><th>Pengisi</th><th>Tanggal</th><th>Status</th><th></th></tr></thead>
        <tbody>{loading ? <tr><td colSpan={6} className="admin-empty">Memuat pengajuan…</td></tr>
          : visible.length ? visible.map((record) => <tr key={record.id}>
            <td><span className="admin-cell-stack"><strong>{summaryName(record)}</strong><small>{record.id}</small></span></td>
            <td>{record.moda_transportasi === 'kapal' ? 'Kapal' : record.moda_transportasi === 'pesawat' ? 'Pesawat' : '—'}</td>
            <td>{record.pengisi_id ?? '—'}</td><td>{formatAdminDate(record.created_at)}</td>
            <td><span className={`admin-state${record.status === 'final' ? '' : record.status?.includes('tolak') ? ' admin-state--off' : ' admin-state--warning'}`}>{statusLabels[record.status ?? ''] ?? record.status ?? '—'}</span></td>
            <td><button className="admin-link-button" type="button" onClick={() => void showDetail(record)}>Lihat detail</button></td>
          </tr>) : <tr><td colSpan={6} className="admin-empty">Tidak ada pengajuan yang sesuai.</td></tr>}
        </tbody>
      </table></div>
      <p className="table-footnote">Menampilkan sampai 50 pengajuan terbaru dari Firestore. Gunakan menu Ekspor Data untuk laporan yang lebih luas.</p>
    </section>
    {detailLoading && <div className="admin-modal-backdrop"><div className="admin-modal admin-loading" role="status">Memuat detail pengajuan…</div></div>}
    {selected && <div className="admin-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setSelected(null); }}>
      <section className="admin-modal" role="dialog" aria-modal="true" aria-labelledby="submission-detail-title">
        <div className="admin-modal__header"><div><span className="eyebrow">{selected.moda_transportasi === 'kapal' ? 'KAPAL' : 'PESAWAT'} · {statusLabels[selected.status ?? ''] ?? selected.status}</span><h2 id="submission-detail-title">{summaryName(selected)}</h2><p>ID {selected.id} · Dibuat {formatAdminDate(selected.created_at)}</p></div><button className="detail-dialog__close" type="button" aria-label="Tutup" onClick={() => setSelected(null)}>×</button></div>
        <div className="admin-card"><strong>Data umum</strong><dl className="detail-list">{Object.entries(selected.data_umum ?? {}).map(([key, value]) => <div key={key}><dt>{key.replaceAll('_', ' ')}</dt><dd>{printable(value)}</dd></div>)}</dl></div>
        <div className="admin-card"><strong>Checklist dan bukti</strong>
          {(selected.answers ?? []).length ? selected.answers?.map((answer) => <article className="submission-answer-card" key={answer.id}>
            <h3>{answer.item?.label ?? answer.template_item_id ?? 'Item checklist'}{answer.item?.kategori ? ` · ${answer.item.kategori}` : ''}</h3>
            <p>Jawaban: {printable(answer.nilai_jawaban)}{answer.status_gagal ? ' · Temuan' : ''}</p>
            {answer.alasan && <p>Alasan: {answer.alasan}</p>}
            {answer.media?.map((media) => media.file_url ? <button className="admin-media-link admin-link-button" type="button" key={media.id} disabled={openingMedia === media.file_url} onClick={() => void openMedia(media.file_url!)}>{openingMedia === media.file_url ? 'Membuka bukti…' : `Buka ${media.tipe ?? 'bukti'} · ${formatAdminDate(media.timestamp)}`}</button> : null)}
          </article>) : <p className="admin-empty">Belum ada jawaban checklist.</p>}
        </div>
        <div className="admin-card"><strong>Verifikasi dan dokumen</strong><p className="submission-answer-card">Pengisi: {selected.pengisi?.nama ?? selected.pengisi_id ?? '—'} · Verifikator: {selected.verifikator?.nama ?? selected.verifikator_id ?? 'Belum diverifikasi'}</p>
          {selected.catatan_verifikator && <p>Catatan verifikator: {selected.catatan_verifikator}</p>}
          {selected.document && <p>Dokumen {selected.document.jenis_dokumen ?? ''}: {selected.document.status ?? '—'}</p>}
          <p className="detail-dialog__note">Keputusan approve/reject hanya tersedia bagi staf BBKK melalui aplikasi verifikator.</p>
        </div>
      </section>
    </div>}
  </>;
}

export default function SubmissionsPage() {
  return <AdminShell title="Pengajuan"><SubmissionsContent /></AdminShell>;
}
