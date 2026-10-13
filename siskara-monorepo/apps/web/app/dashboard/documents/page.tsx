'use client';

import { useCallback, useEffect, useState } from 'react';
import { AdminShell, useAdmin } from '../admin-shell';
import { adminFetch, formatAdminDate } from '@/lib/admin-api';

type ResultDocument = {
  id: string;
  submission_id?: string;
  jenis_dokumen?: string;
  file_pdf_url?: string;
  status?: string;
  tanggal_generate?: unknown;
  submission?: {
    moda_transportasi?: string;
    data_umum?: Record<string, unknown>;
    status?: string;
  } | null;
};
type DocumentsResponse = { documents: ResultDocument[] };
type SignedUrlResponse = { download_url: string };

function DocumentsContent() {
  const { user } = useAdmin();
  const [documents, setDocuments] = useState<ResultDocument[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [opening, setOpening] = useState('');

  const load = useCallback(async () => {
    try {
      const result = await adminFetch<DocumentsResponse>(user, '/api/documents');
      setDocuments(result.documents);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Daftar dokumen tidak dapat dimuat.');
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    let active = true;
    void adminFetch<DocumentsResponse>(user, '/api/documents')
      .then((result) => { if (active) setDocuments(result.documents); })
      .catch((cause: unknown) => {
        if (active) setError(cause instanceof Error ? cause.message : 'Daftar dokumen tidak dapat dimuat.');
      })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [user]);

  async function download(document: ResultDocument) {
    if (!document.file_pdf_url) return;
    setOpening(document.id);
    setError('');
    try {
      const result = await adminFetch<SignedUrlResponse>(user, '/api/uploads/download', {
        method: 'POST',
        body: JSON.stringify({ storage_path: document.file_pdf_url }),
      });
      window.open(result.download_url, '_blank', 'noopener,noreferrer');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Dokumen tidak dapat diunduh.');
    } finally {
      setOpening('');
    }
  }

  return <>
    <section className="admin-page-heading"><div><span className="eyebrow">ARSIP HASIL</span><h1>Dokumen</h1><p>PHQC kapal dan berkas verifikasi pesawat yang tercatat pada pengajuan final.</p></div><button className="button button--secondary" type="button" onClick={() => { setLoading(true); void load(); }} disabled={loading}>Perbarui</button></section>
    {error && <p className="admin-error" role="alert">{error}</p>}
    <section className="admin-card">
      <div className="admin-table-wrap"><table className="admin-table">
        <thead><tr><th>Jenis dokumen</th><th>Pengajuan</th><th>Moda</th><th>Dibuat</th><th>Status</th><th>File</th></tr></thead>
        <tbody>{loading ? <tr><td colSpan={6} className="admin-empty">Memuat dokumen…</td></tr>
          : documents.length ? documents.map((document) => {
            const data = document.submission?.data_umum ?? {};
            const identity = document.submission?.moda_transportasi === 'kapal' ? data.nama_kapal : data.nomor_penerbangan;
            return <tr key={document.id}>
              <td><span className="admin-cell-stack"><strong>{document.jenis_dokumen === 'phqc' ? 'PHQC' : document.jenis_dokumen === 'berkas_verifikasi' ? 'Berkas Verifikasi' : 'Dokumen hasil'}</strong><small>{document.id}</small></span></td>
              <td><span className="admin-cell-stack"><strong>{typeof identity === 'string' ? identity : 'Pengajuan'}</strong><small>{document.submission_id}</small></span></td>
              <td>{document.submission?.moda_transportasi ?? '—'}</td><td>{formatAdminDate(document.tanggal_generate)}</td>
              <td><span className={`admin-state${document.status === 'final' ? '' : ' admin-state--warning'}`}>{document.status === 'final' ? 'Final' : 'Menunggu berkas PDF'}</span></td>
              <td>{document.file_pdf_url ? <button className="admin-link-button" type="button" disabled={opening === document.id} onClick={() => void download(document)}>{opening === document.id ? 'Menyiapkan…' : 'Buka PDF'}</button> : 'Belum tersedia'}</td>
            </tr>;
          }) : <tr><td colSpan={6} className="admin-empty">Belum ada dokumen hasil tercatat.</td></tr>}
        </tbody>
      </table></div>
      <p className="table-footnote">Dokumen hanya dapat dibuka melalui tautan privat sementara. Admin dapat melihat/mengunduh dokumen, tetapi tidak membuat atau mengubah keputusan verifikasi.</p>
    </section>
  </>;
}

export default function DocumentsPage() {
  return <AdminShell title="Dokumen"><DocumentsContent /></AdminShell>;
}
