'use client';

import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
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
  catatan_verifikator?: string | null;
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
  document?: { file_pdf_url?: string; jenis_dokumen?: string; status?: string } | null;
};
type DetailResponse = { submission: SubmissionDetail };
type SignedUrlResponse = { download_url: string };

const statusLabels: Record<string, string> = {
  draft: 'Draft',
  ditolak_otomatis: 'Ditolak otomatis',
  menunggu_verifikasi_staf: 'Menunggu verifikasi',
  ditolak_staf: 'Ditolak staf',
  final: 'Diterima / Selesai',
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
  const [notice, setNotice] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('semua');
  const [mode, setMode] = useState('semua');
  const [selected, setSelected] = useState<SubmissionDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [openingMedia, setOpeningMedia] = useState('');
  const [newStatus, setNewStatus] = useState<string>('');
  const [adminNotes, setAdminNotes] = useState<string>('');
  const [updatingStatus, setUpdatingStatus] = useState(false);
  const [deletingId, setDeletingId] = useState<string>('');

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
    setNotice('');
    try {
      const result = await adminFetch<DetailResponse>(user, `/api/submissions/${encodeURIComponent(record.id)}`);
      setSelected(result.submission);
      setNewStatus(result.submission.status ?? 'menunggu_verifikasi_staf');
      setAdminNotes(result.submission.catatan_verifikator ?? '');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Detail pengajuan gagal dimuat.');
    } finally {
      setDetailLoading(false);
    }
  }

  async function handleSaveStatus(event: FormEvent) {
    event.preventDefault();
    if (!selected || !newStatus) return;
    setUpdatingStatus(true);
    setError('');
    setNotice('');
    try {
      await adminFetch(user, `/api/submissions/${encodeURIComponent(selected.id)}`, {
        method: 'PATCH',
        body: JSON.stringify({
          status: newStatus,
          catatan_verifikator: adminNotes,
        }),
      });
      setSubmissions((prev) =>
        prev.map((s) => (s.id === selected.id ? { ...s, status: newStatus, catatan_verifikator: adminNotes } : s))
      );
      setSelected((prev) => (prev ? { ...prev, status: newStatus, catatan_verifikator: adminNotes } : null));
      setNotice(`Status berhasil diubah menjadi: ${statusLabels[newStatus] ?? newStatus}`);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Gagal memperbarui status pengajuan.');
    } finally {
      setUpdatingStatus(false);
    }
  }

  async function deleteSubmission(submission: Submission) {
    const name = summaryName(submission);
    const confirmed = window.confirm(
      `HAPUS PERMANEN pengajuan "${name}" (ID: ${submission.id})?\n\nPerhatian: Seluruh data formulir, jawaban checklist, foto bukti, dan sertifikat terkait akan dihapus secara permanen.`
    );
    if (!confirmed) return;
    setDeletingId(submission.id);
    setError('');
    setNotice('');
    try {
      await adminFetch(user, `/api/submissions/${encodeURIComponent(submission.id)}`, {
        method: 'DELETE',
      });
      setSubmissions((prev) => prev.filter((s) => s.id !== submission.id));
      if (selected?.id === submission.id) setSelected(null);
      setNotice(`Pengajuan "${name}" berhasil dihapus.`);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Gagal menghapus pengajuan.');
    } finally {
      setDeletingId('');
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

  return (
    <>
      <section className="admin-page-heading">
        <div>
          <span className="eyebrow">PEMANTAUAN & KEPUTUSAN</span>
          <h1>Hasil Skrining</h1>
          <p>Daftar seluruh deklarasi dan skrining transportasi. Admin memiliki wewenang penuh untuk meninjau detail, mengubah status persetujuan, maupun menghapus berkas.</p>
        </div>
        <button className="button button--secondary" type="button" disabled={loading} onClick={() => { setLoading(true); void load(); }}>Perbarui</button>
      </section>

      {error && <p className="admin-error" role="alert">{error}</p>}
      {notice && <p className="admin-success" role="status">{notice}</p>}

      <section className="admin-card">
        <div className="admin-toolbar">
          <input className="admin-input admin-search" type="search" placeholder="Cari kapal, nomor penerbangan, ID…" value={search} onChange={(event) => setSearch(event.target.value)} />
          <div className="admin-toolbar__filters">
            <select className="admin-select" value={mode} onChange={(event) => setMode(event.target.value)} aria-label="Filter moda">
              <option value="semua">Semua moda</option>
              <option value="kapal">Kapal</option>
              <option value="pesawat">Pesawat</option>
            </select>
            <select className="admin-select" value={status} onChange={(event) => setStatus(event.target.value)} aria-label="Filter status">
              <option value="semua">Semua status</option>
              {Object.entries(statusLabels).map(([value, label]) => <option value={value} key={value}>{label}</option>)}
            </select>
          </div>
        </div>

        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Identitas</th>
                <th>Moda</th>
                <th>Pengisi</th>
                <th>Tanggal</th>
                <th>Status</th>
                <th>Aksi</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={6} className="admin-empty">Memuat pengajuan…</td></tr>
              ) : visible.length ? (
                visible.map((record) => (
                  <tr key={record.id}>
                    <td><span className="admin-cell-stack"><strong>{summaryName(record)}</strong><small>{record.id}</small></span></td>
                    <td>{record.moda_transportasi === 'kapal' ? 'Kapal' : record.moda_transportasi === 'pesawat' ? 'Pesawat' : '—'}</td>
                    <td>{record.pengisi_id ?? '—'}</td>
                    <td>{formatAdminDate(record.created_at)}</td>
                    <td>
                      <span className={`admin-state${record.status === 'final' ? '' : record.status?.includes('tolak') ? ' admin-state--off' : ' admin-state--warning'}`}>
                        {statusLabels[record.status ?? ''] ?? record.status ?? '—'}
                      </span>
                    </td>
                    <td>
                      <span className="admin-inline-actions">
                        <button className="admin-link-button" type="button" onClick={() => void showDetail(record)}>
                          Detail & Status
                        </button>
                        <button
                          className="admin-link-button admin-link-button--danger"
                          type="button"
                          disabled={deletingId === record.id}
                          onClick={() => void deleteSubmission(record)}
                        >
                          {deletingId === record.id ? 'Menghapus…' : 'Hapus'}
                        </button>
                      </span>
                    </td>
                  </tr>
                ))
              ) : (
                <tr><td colSpan={6} className="admin-empty">Tidak ada pengajuan yang sesuai.</td></tr>
              )}
            </tbody>
          </table>
        </div>
        <p className="table-footnote">Menampilkan {visible.length} dari {submissions.length} pengajuan. Kelola status atau hapus langsung dari tabel ini.</p>
      </section>

      {detailLoading && (
        <div className="admin-modal-backdrop">
          <div className="admin-modal admin-loading" role="status">Memuat detail pengajuan…</div>
        </div>
      )}

      {selected && (
        <div className="admin-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setSelected(null); }}>
          <section className="admin-modal" role="dialog" aria-modal="true" aria-labelledby="submission-detail-title">
            <div className="admin-modal__header">
              <div>
                <span className="eyebrow">
                  {selected.moda_transportasi === 'kapal' ? 'KAPAL' : 'PESAWAT'} · {statusLabels[selected.status ?? ''] ?? selected.status}
                </span>
                <h2 id="submission-detail-title">{summaryName(selected)}</h2>
                <p>ID: {selected.id} · Dibuat: {formatAdminDate(selected.created_at)}</p>
              </div>
              <button className="detail-dialog__close" type="button" aria-label="Tutup" onClick={() => setSelected(null)}>×</button>
            </div>

            {/* Wewenang Admin: Ubah Status & Keputusan */}
            <div className="admin-card" style={{ borderLeft: '4px solid #0d9488', background: '#f0fdfa' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
                <strong style={{ color: '#0f766e', fontSize: 14 }}>Wewenang Admin: Ubah Status & Keputusan</strong>
                <span className={`admin-state${selected.status === 'final' ? '' : selected.status?.includes('tolak') ? ' admin-state--off' : ' admin-state--warning'}`}>
                  {statusLabels[selected.status ?? ''] ?? selected.status}
                </span>
              </div>
              <form onSubmit={handleSaveStatus}>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12, marginBottom: 14 }}>
                  <label className="admin-form-field">
                    Pilih status persetujuan
                    <select
                      className="admin-select"
                      value={newStatus}
                      onChange={(e) => setNewStatus(e.target.value)}
                      disabled={updatingStatus}
                      required
                    >
                      <option value="final">Diterima / Selesai (Final - Laik Operasional)</option>
                      <option value="ditolak_staf">Ditolak Staf (Tidak Memenuhi Syarat)</option>
                      <option value="menunggu_verifikasi_staf">Kembalikan ke Menunggu Verifikasi</option>
                      <option value="draft">Kembalikan ke Draft Pemohon</option>
                      <option value="ditolak_otomatis">Ditolak Otomatis Sistem</option>
                    </select>
                  </label>
                  <label className="admin-form-field">
                    Catatan verifikasi / alasan keputusan
                    <input
                      className="admin-input"
                      placeholder="Contoh: Disetujui oleh Validator Admin BBKK Makassar..."
                      value={adminNotes}
                      onChange={(e) => setAdminNotes(e.target.value)}
                      disabled={updatingStatus}
                    />
                  </label>
                </div>
                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
                  <button className="button button--secondary" type="submit" disabled={updatingStatus}>
                    {updatingStatus ? 'Menyimpan perubahan…' : 'Simpan Perubahan Status'}
                  </button>
                </div>
              </form>
            </div>

            <div className="admin-card">
              <strong>Data umum transportasi</strong>
              <dl className="detail-list">
                {Object.entries(selected.data_umum ?? {}).map(([key, value]) => (
                  <div key={key}>
                    <dt>{key.replaceAll('_', ' ')}</dt>
                    <dd>{printable(value)}</dd>
                  </div>
                ))}
              </dl>
            </div>

            <div className="admin-card">
              <strong>Checklist dan bukti foto</strong>
              {(selected.answers ?? []).length ? (
                selected.answers?.map((answer) => (
                  <article className="submission-answer-card" key={answer.id}>
                    <h3>{answer.item?.label ?? answer.template_item_id ?? 'Item checklist'}{answer.item?.kategori ? ` · ${answer.item.kategori}` : ''}</h3>
                    <p>Status: <strong>{printable(answer.nilai_jawaban)}</strong>{answer.status_gagal ? ' · Temuan Sanitasi' : ''}</p>
                    {answer.alasan && <p>Keterangan: {answer.alasan}</p>}
                    {answer.media?.map((media) => (
                      media.file_url ? (
                        <button
                          className="admin-media-link admin-link-button"
                          type="button"
                          key={media.id}
                          disabled={openingMedia === media.file_url}
                          onClick={() => void openMedia(media.file_url!)}
                        >
                          {openingMedia === media.file_url ? 'Membuka bukti…' : `Buka Foto ${media.tipe ?? 'Bukti'} · ${formatAdminDate(media.timestamp)}`}
                        </button>
                      ) : null
                    ))}
                  </article>
                ))
              ) : (
                <p className="admin-empty">Belum ada jawaban checklist.</p>
              )}
            </div>

            <div className="admin-card">
              <strong>Informasi Verifikator & Sertifikat</strong>
              <p className="submission-answer-card">
                Pemohon: <strong>{selected.pengisi?.nama ?? selected.pengisi_id ?? '—'}</strong> ·
                Verifikator: <strong>{selected.verifikator?.nama ?? selected.verifikator_id ?? 'Belum diverifikasi'}</strong>
              </p>
              {selected.catatan_verifikator && <p>Catatan: {selected.catatan_verifikator}</p>}
              {selected.document && <p>Dokumen {selected.document.jenis_dokumen ?? ''}: {selected.document.status ?? '—'}</p>}
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 14 }}>
              <button
                className="button button--danger"
                type="button"
                onClick={() => void deleteSubmission(selected)}
              >
                Hapus Pengajuan Ini
              </button>
              <button
                className="button button--secondary"
                type="button"
                onClick={() => setSelected(null)}
              >
                Tutup
              </button>
            </div>
          </section>
        </div>
      )}
    </>
  );
}

export default function SubmissionsPage() {
  return <AdminShell title="Hasil Skrining"><SubmissionsContent /></AdminShell>;
}
