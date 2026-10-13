'use client';

import { useState } from 'react';
import { AdminShell, useAdmin } from '../admin-shell';

function ExportsContent() {
  const { user } = useAdmin();
  const [mode, setMode] = useState('semua');
  const [status, setStatus] = useState('semua');
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const [exporting, setExporting] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  async function exportData(format: 'xlsx' | 'csv' | 'pdf') {
    setExporting(format);
    setError('');
    setNotice('');
    try {
      const params = new URLSearchParams({ format });
      if (mode !== 'semua') params.set('moda', mode);
      if (status !== 'semua') params.set('status', status);
      if (start) params.set('dari', start);
      if (end) params.set('sampai', end);
      const token = await user.getIdToken();
      const response = await fetch(`/api/export?${params}`, {
        headers: { Authorization: `Bearer ${token}` },
        cache: 'no-store',
      });
      if (!response.ok) {
        const body = await response.json() as { error?: string };
        throw new Error(body.error ?? `Ekspor gagal (${response.status}).`);
      }
      const blob = await response.blob();
      const disposition = response.headers.get('Content-Disposition') ?? '';
      const filename = disposition.match(/filename="([^"]+)"/)?.[1] ?? `siskara-pengajuan.${format}`;
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      link.click();
      URL.revokeObjectURL(url);
      setNotice(`File ${filename} berhasil diunduh.`);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Ekspor gagal dibuat.');
    } finally {
      setExporting('');
    }
  }

  return <>
    <section className="admin-page-heading"><div><span className="eyebrow">PELAPORAN</span><h1>Ekspor data</h1><p>Unduh laporan pengajuan sesuai moda, status, dan rentang tanggal. Data dibatasi hingga 5.000 pengajuan terbaru per ekspor.</p></div></section>
    {error && <p className="admin-error" role="alert">{error}</p>}
    {notice && <p className="admin-success" role="status">{notice}</p>}
    <section className="admin-card">
      <h2 className="panel-heading__title">Filter laporan</h2>
      <form onSubmit={(event) => { event.preventDefault(); void exportData('xlsx'); }}>
        <div className="admin-form-grid">
          <label className="admin-form-field">Moda transportasi<select className="admin-select" value={mode} onChange={(event) => setMode(event.target.value)}><option value="semua">Semua moda</option><option value="kapal">Kapal</option><option value="pesawat">Pesawat</option></select></label>
          <label className="admin-form-field">Status pengajuan<select className="admin-select" value={status} onChange={(event) => setStatus(event.target.value)}><option value="semua">Semua status</option><option value="draft">Draft</option><option value="ditolak_otomatis">Ditolak otomatis</option><option value="menunggu_verifikasi_staf">Menunggu verifikasi</option><option value="ditolak_staf">Ditolak staf</option><option value="final">Selesai</option></select></label>
          <label className="admin-form-field">Tanggal mulai<input className="admin-input" type="date" value={start} max={end || undefined} onChange={(event) => setStart(event.target.value)} /></label>
          <label className="admin-form-field">Tanggal akhir<input className="admin-input" type="date" value={end} min={start || undefined} onChange={(event) => setEnd(event.target.value)} /></label>
        </div>
        <div className="admin-form-footer">
          <button className="button button--secondary" type="button" disabled={Boolean(exporting)} onClick={() => void exportData('csv')}>{exporting === 'csv' ? 'Membuat CSV…' : 'Unduh CSV'}</button>
          <button className="button button--secondary" type="button" disabled={Boolean(exporting)} onClick={() => void exportData('pdf')}>{exporting === 'pdf' ? 'Membuat PDF…' : 'Unduh PDF'}</button>
          <button className="login-submit" type="submit" disabled={Boolean(exporting)}>{exporting === 'xlsx' ? 'Membuat Excel…' : 'Unduh Excel (.xlsx)'}</button>
        </div>
      </form>
    </section>
    <section className="admin-card"><strong>Informasi ekspor</strong><ul className="admin-notes"><li>File memuat identitas pengajuan, moda transportasi, lokasi asal, waktu dibuat, dan status.</li><li>CSV menggunakan UTF-8 dengan BOM agar karakter Indonesia terbaca di aplikasi lembar kerja umum.</li><li>Data ekspor hanya untuk pelaporan; keputusan verifikasi tetap dilakukan oleh staf BBKK.</li></ul></section>
  </>;
}

export default function ExportsPage() {
  return <AdminShell title="Ekspor data"><ExportsContent /></AdminShell>;
}
