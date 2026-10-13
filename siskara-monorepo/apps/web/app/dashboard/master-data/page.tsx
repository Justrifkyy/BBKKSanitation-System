'use client';

import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import { AdminShell, useAdmin } from '../admin-shell';
import { adminFetch, formatAdminDate } from '@/lib/admin-api';

type MasterType = 'ships' | 'aircraft' | 'locations';
type MasterRecord = {
  id: string;
  is_active?: boolean;
  created_at?: unknown;
  nama_kapal?: string;
  jenis_kapal?: string;
  besar_kapal_grt?: number | null;
  bendera?: string;
  nomor_imo?: string;
  nama_pemilik_agen?: string;
  pemilik_atau_penyelenggara?: string;
  tanda_kebangsaan_dan_pendaftaran?: string;
  nama?: string;
  jenis?: string;
  kode?: string;
};
type MasterResponse = { master_data: Record<MasterType, MasterRecord[]> };

const labels: Record<MasterType, string> = {
  ships: 'Kapal',
  aircraft: 'Pesawat',
  locations: 'Pelabuhan & lokasi',
};
const emptyForms: Record<MasterType, Record<string, string>> = {
  ships: {
    nama_kapal: '',
    jenis_kapal: '',
    besar_kapal_grt: '',
    bendera: '',
    nomor_imo: '',
    nama_pemilik_agen: '',
  },
  aircraft: {
    pemilik_atau_penyelenggara: '',
    tanda_kebangsaan_dan_pendaftaran: '',
  },
  locations: { nama: '', jenis: 'pelabuhan', kode: '' },
};

function masterName(type: MasterType, record: MasterRecord) {
  if (type === 'ships') return record.nama_kapal ?? 'Kapal';
  if (type === 'aircraft') return record.tanda_kebangsaan_dan_pendaftaran ?? 'Pesawat';
  return record.nama ?? 'Lokasi';
}

function DataMasterContent() {
  const { user } = useAdmin();
  const [records, setRecords] = useState<Record<MasterType, MasterRecord[]>>({
    ships: [],
    aircraft: [],
    locations: [],
  });
  const [type, setType] = useState<MasterType>('ships');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [search, setSearch] = useState('');
  const [includeInactive, setIncludeInactive] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<MasterRecord | null>(null);
  const [form, setForm] = useState<Record<string, string>>(emptyForms.ships);

  const load = useCallback(async () => {
    try {
      const query = includeInactive ? '?include_inactive=true' : '';
      const result = await adminFetch<MasterResponse>(user, `/api/master-data${query}`);
      setRecords(result.master_data);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Data master gagal dimuat.');
    } finally {
      setLoading(false);
    }
  }, [includeInactive, user]);

  useEffect(() => {
    let active = true;
    void adminFetch<MasterResponse>(user, `/api/master-data${includeInactive ? '?include_inactive=true' : ''}`)
      .then((result) => { if (active) setRecords(result.master_data); })
      .catch((cause: unknown) => {
        if (active) setError(cause instanceof Error ? cause.message : 'Data master gagal dimuat.');
      })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [includeInactive, user]);

  const visibleRecords = useMemo(() => {
    const term = search.trim().toLocaleLowerCase('id-ID');
    return (records[type] ?? []).filter((record) =>
      !term || Object.entries(record).some(([key, value]) =>
        key !== 'id' && typeof value === 'string' && value.toLocaleLowerCase('id-ID').includes(term),
      ),
    );
  }, [records, search, type]);

  function openCreate() {
    setEditing(null);
    setForm({ ...emptyForms[type] });
    setShowForm(true);
    setError('');
    setNotice('');
  }

  function openEdit(record: MasterRecord) {
    setEditing(record);
    setShowForm(true);
    if (type === 'ships') {
      setForm({
        nama_kapal: record.nama_kapal ?? '',
        jenis_kapal: record.jenis_kapal ?? '',
        besar_kapal_grt: record.besar_kapal_grt == null ? '' : String(record.besar_kapal_grt),
        bendera: record.bendera ?? '',
        nomor_imo: record.nomor_imo ?? '',
        nama_pemilik_agen: record.nama_pemilik_agen ?? '',
      });
    } else if (type === 'aircraft') {
      setForm({
        pemilik_atau_penyelenggara: record.pemilik_atau_penyelenggara ?? '',
        tanda_kebangsaan_dan_pendaftaran: record.tanda_kebangsaan_dan_pendaftaran ?? '',
      });
    } else {
      setForm({ nama: record.nama ?? '', jenis: record.jenis ?? 'pelabuhan', kode: record.kode ?? '' });
    }
    setError('');
    setNotice('');
  }

  function payload() {
    if (type !== 'ships') return form;
    if (form.besar_kapal_grt.trim() && (!Number.isFinite(Number(form.besar_kapal_grt)) || Number(form.besar_kapal_grt) < 0)) {
      throw new Error('Nilai GRT harus berupa angka nol atau lebih.');
    }
    return {
      ...form,
      besar_kapal_grt: form.besar_kapal_grt.trim() ? Number(form.besar_kapal_grt) : null,
    };
  }

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError('');
    setNotice('');
    try {
      const data = payload();
      await adminFetch(user, editing
        ? `/api/master-data/${encodeURIComponent(editing.id)}`
        : '/api/master-data', {
        method: editing ? 'PATCH' : 'POST',
        body: JSON.stringify({ type, ...data }),
      });
      setShowForm(false);
      setEditing(null);
      setNotice(editing ? 'Data master diperbarui.' : 'Data master berhasil ditambahkan.');
      await load();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Perubahan data master gagal disimpan.');
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive(record: MasterRecord) {
    const active = record.is_active !== false;
    if (active && !window.confirm(`Nonaktifkan ${masterName(type, record)}? Data tidak akan dihapus dan tetap tersimpan pada riwayat.`)) return;
    setError('');
    setNotice('');
    try {
      await adminFetch(user, `/api/master-data/${encodeURIComponent(record.id)}`, {
        method: 'PATCH',
        body: JSON.stringify({ type, is_active: !active }),
      });
      setNotice(active ? 'Data master dinonaktifkan.' : 'Data master diaktifkan kembali.');
      await load();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Status data master gagal diperbarui.');
    }
  }

  const activeCount = (records[type] ?? []).filter((record) => record.is_active !== false).length;

  return <>
    <section className="admin-page-heading">
      <div><span className="eyebrow">REFERENSI OPERASIONAL</span><h1>Data master</h1><p>Kelola kapal, pesawat, pelabuhan, bandara, dan lokasi sandar yang digunakan sebagai referensi. Nonaktifkan data lama agar tidak hilang dari riwayat.</p></div>
      <button className="button button--secondary" type="button" onClick={openCreate}>+ Tambah {type === 'locations' ? 'lokasi' : type === 'ships' ? 'kapal' : 'pesawat'}</button>
    </section>
    {error && <p className="admin-error" role="alert">{error}</p>}
    {notice && <p className="admin-success" role="status">{notice}</p>}
    <section className="admin-card">
      <div className="admin-master-tabs" role="tablist" aria-label="Jenis data master">
        {(Object.keys(labels) as MasterType[]).map((key) => (
          <button className={`admin-master-tab${key === type ? ' is-active' : ''}`} type="button" role="tab" aria-selected={key === type} key={key} onClick={() => { setType(key); setSearch(''); setError(''); }}>
            {labels[key]} <span>{records[key].length}</span>
          </button>
        ))}
      </div>
      <div className="admin-toolbar">
        <input className="admin-input admin-search" type="search" placeholder="Cari nama, IMO, registrasi, kode…" value={search} onChange={(event) => setSearch(event.target.value)} />
        <div className="admin-toolbar__filters">
          <label className="admin-check"><input type="checkbox" checked={includeInactive} onChange={(event) => { setLoading(true); setIncludeInactive(event.target.checked); }} /> Tampilkan nonaktif</label>
          <button className="button button--secondary" type="button" disabled={loading} onClick={() => { setLoading(true); void load(); }}>Perbarui</button>
        </div>
      </div>
      <div className="admin-table-wrap">
        <table className="admin-table">
          {type === 'ships' && <><thead><tr><th>Nama kapal</th><th>Jenis / bendera</th><th>IMO</th><th>GRT</th><th>Status</th><th>Aksi</th></tr></thead><tbody>
            {loading ? <tr><td colSpan={6} className="admin-empty">Memuat data…</td></tr> : visibleRecords.length ? visibleRecords.map((record) => <tr key={record.id}><td><span className="admin-cell-stack"><strong>{record.nama_kapal}</strong><small>{record.nama_pemilik_agen || 'Pemilik/agen belum dicatat'}</small></span></td><td>{[record.jenis_kapal, record.bendera].filter(Boolean).join(' · ') || '—'}</td><td>{record.nomor_imo || '—'}</td><td>{record.besar_kapal_grt ?? '—'}</td><td><span className={`admin-state${record.is_active === false ? ' admin-state--off' : ''}`}>{record.is_active === false ? 'Nonaktif' : 'Aktif'}</span></td><td><span className="admin-inline-actions"><button className="admin-link-button" type="button" onClick={() => openEdit(record)}>Edit</button><button className="admin-link-button" type="button" onClick={() => void toggleActive(record)}>{record.is_active === false ? 'Aktifkan' : 'Nonaktifkan'}</button></span></td></tr>) : <tr><td colSpan={6} className="admin-empty">Belum ada data kapal aktif. Tambahkan kapal untuk memulai.</td></tr>}
          </tbody></>}
          {type === 'aircraft' && <><thead><tr><th>Tanda pendaftaran</th><th>Pemilik / penyelenggara</th><th>Status</th><th>Terdaftar</th><th>Aksi</th></tr></thead><tbody>
            {loading ? <tr><td colSpan={5} className="admin-empty">Memuat data…</td></tr> : visibleRecords.length ? visibleRecords.map((record) => <tr key={record.id}><td><strong>{record.tanda_kebangsaan_dan_pendaftaran}</strong></td><td>{record.pemilik_atau_penyelenggara}</td><td><span className={`admin-state${record.is_active === false ? ' admin-state--off' : ''}`}>{record.is_active === false ? 'Nonaktif' : 'Aktif'}</span></td><td>{formatAdminDate(record.created_at)}</td><td><span className="admin-inline-actions"><button className="admin-link-button" type="button" onClick={() => openEdit(record)}>Edit</button><button className="admin-link-button" type="button" onClick={() => void toggleActive(record)}>{record.is_active === false ? 'Aktifkan' : 'Nonaktifkan'}</button></span></td></tr>) : <tr><td colSpan={5} className="admin-empty">Belum ada data pesawat aktif. Tambahkan pesawat untuk memulai.</td></tr>}
          </tbody></>}
          {type === 'locations' && <><thead><tr><th>Nama lokasi</th><th>Jenis</th><th>Kode</th><th>Status</th><th>Aksi</th></tr></thead><tbody>
            {loading ? <tr><td colSpan={5} className="admin-empty">Memuat data…</td></tr> : visibleRecords.length ? visibleRecords.map((record) => <tr key={record.id}><td><strong>{record.nama}</strong></td><td>{record.jenis === 'pelabuhan' ? 'Pelabuhan' : record.jenis === 'bandara' ? 'Bandara' : 'Lokasi sandar'}</td><td>{record.kode || '—'}</td><td><span className={`admin-state${record.is_active === false ? ' admin-state--off' : ''}`}>{record.is_active === false ? 'Nonaktif' : 'Aktif'}</span></td><td><span className="admin-inline-actions"><button className="admin-link-button" type="button" onClick={() => openEdit(record)}>Edit</button><button className="admin-link-button" type="button" onClick={() => void toggleActive(record)}>{record.is_active === false ? 'Aktifkan' : 'Nonaktifkan'}</button></span></td></tr>) : <tr><td colSpan={5} className="admin-empty">Belum ada lokasi. Tambahkan pelabuhan, bandara, atau lokasi sandar.</td></tr>}
          </tbody></>}
        </table>
      </div>
      <p className="table-footnote">Menampilkan {visibleRecords.length} {labels[type].toLocaleLowerCase('id-ID')} · {activeCount} aktif. Data nonaktif dipertahankan karena pengajuan lama dapat merujuk kepadanya.</p>
    </section>

    {showForm && <div className="admin-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) { setShowForm(false); setEditing(null); } }}>
      <section className="admin-modal admin-modal--narrow" role="dialog" aria-modal="true" aria-labelledby="master-form-title">
        <div className="admin-modal__header"><div><h2 id="master-form-title">{editing ? 'Edit' : 'Tambah'} {type === 'locations' ? 'lokasi' : type === 'ships' ? 'kapal' : 'pesawat'}</h2><p>Data tersimpan di Firestore dan perubahan dicatat di log aktivitas.</p></div><button className="detail-dialog__close" type="button" aria-label="Tutup" onClick={() => { setShowForm(false); setEditing(null); }}>×</button></div>
        <form onSubmit={(event) => void save(event)}>
          <div className="admin-form-grid">
            {type === 'ships' && <>
              <label className="admin-form-field">Nama kapal<input className="admin-input" required value={form.nama_kapal} onChange={(event) => setForm({ ...form, nama_kapal: event.target.value })} /></label>
              <label className="admin-form-field">Jenis kapal<input className="admin-input" value={form.jenis_kapal} onChange={(event) => setForm({ ...form, jenis_kapal: event.target.value })} /></label>
              <label className="admin-form-field">Nomor IMO<input className="admin-input" value={form.nomor_imo} onChange={(event) => setForm({ ...form, nomor_imo: event.target.value })} /></label>
              <label className="admin-form-field">Bendera<input className="admin-input" value={form.bendera} onChange={(event) => setForm({ ...form, bendera: event.target.value })} /></label>
              <label className="admin-form-field">Besar kapal (GRT)<input className="admin-input" type="number" min="0" step="any" value={form.besar_kapal_grt} onChange={(event) => setForm({ ...form, besar_kapal_grt: event.target.value })} /></label>
              <label className="admin-form-field">Pemilik / agen<input className="admin-input" value={form.nama_pemilik_agen} onChange={(event) => setForm({ ...form, nama_pemilik_agen: event.target.value })} /></label>
            </>}
            {type === 'aircraft' && <>
              <label className="admin-form-field">Tanda kebangsaan dan pendaftaran<input className="admin-input" required value={form.tanda_kebangsaan_dan_pendaftaran} onChange={(event) => setForm({ ...form, tanda_kebangsaan_dan_pendaftaran: event.target.value })} /></label>
              <label className="admin-form-field">Pemilik / penyelenggara<input className="admin-input" required value={form.pemilik_atau_penyelenggara} onChange={(event) => setForm({ ...form, pemilik_atau_penyelenggara: event.target.value })} /></label>
            </>}
            {type === 'locations' && <>
              <label className="admin-form-field">Nama lokasi<input className="admin-input" required value={form.nama} onChange={(event) => setForm({ ...form, nama: event.target.value })} /></label>
              <label className="admin-form-field">Jenis lokasi<select className="admin-select" value={form.jenis} onChange={(event) => setForm({ ...form, jenis: event.target.value })}><option value="pelabuhan">Pelabuhan</option><option value="bandara">Bandara</option><option value="lokasi_sandar">Lokasi sandar</option></select></label>
              <label className="admin-form-field">Kode lokasi (opsional)<input className="admin-input" value={form.kode} onChange={(event) => setForm({ ...form, kode: event.target.value })} /></label>
            </>}
          </div>
          {error && <p className="admin-error" role="alert">{error}</p>}
          <div className="admin-form-footer"><button className="button button--secondary" type="button" onClick={() => { setShowForm(false); setEditing(null); }}>Batal</button><button className="login-submit" type="submit" disabled={saving}>{saving ? 'Menyimpan…' : 'Simpan data'}</button></div>
        </form>
      </section>
    </div>}
  </>;
}

export default function MasterDataPage() {
  return <AdminShell title="Data master"><DataMasterContent /></AdminShell>;
}
