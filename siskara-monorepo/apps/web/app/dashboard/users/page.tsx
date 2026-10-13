'use client';

import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import { AdminShell, useAdmin } from '../admin-shell';
import { adminFetch, formatAdminDate } from '@/lib/admin-api';

type Role = 'kepala_kapal' | 'kepala_penerbangan' | 'staf_bbkk' | 'validator_admin';
type ManagedUser = {
  id: string;
  email?: string | null;
  nama?: string;
  role?: Role;
  phone?: string;
  id_number?: string | null;
  is_active?: boolean;
  created_at?: unknown;
};
type UsersResponse = { users: ManagedUser[] };

const roleLabels: Record<Role, string> = {
  kepala_kapal: 'Nahkoda',
  kepala_penerbangan: 'Pilot',
  staf_bbkk: 'Staf BBKK',
  validator_admin: 'Admin',
};

const emptyForm = {
  nama: '',
  email: '',
  password: '',
  phone: '',
  id_number: '',
  role: 'kepala_kapal' as Role,
};

function UsersContent() {
  const { user } = useAdmin();
  const [users, setUsers] = useState<ManagedUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('semua');
  const [activeFilter, setActiveFilter] = useState('semua');
  const [editing, setEditing] = useState<ManagedUser | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(emptyForm);

  const loadUsers = useCallback(async () => {
    try {
      const result = await adminFetch<UsersResponse>(user, '/api/users');
      setUsers(result.users);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Daftar pengguna tidak dapat dimuat.');
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    let active = true;
    void adminFetch<UsersResponse>(user, '/api/users')
      .then((result) => { if (active) setUsers(result.users); })
      .catch((cause: unknown) => {
        if (active) setError(cause instanceof Error ? cause.message : 'Daftar pengguna tidak dapat dimuat.');
      })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [user]);

  const visibleUsers = useMemo(() => {
    const term = search.trim().toLocaleLowerCase('id-ID');
    return users.filter((record) => {
      const matchesRole = roleFilter === 'semua' || record.role === roleFilter;
      const active = record.is_active !== false;
      const matchesActive = activeFilter === 'semua' ||
        (activeFilter === 'aktif' ? active : !active);
      const matchesSearch = !term || [
        record.nama,
        record.phone,
        record.id_number,
        record.id,
      ].some((value) => value?.toLocaleLowerCase('id-ID').includes(term));
      return matchesRole && matchesActive && matchesSearch;
    });
  }, [activeFilter, roleFilter, search, users]);

  function openCreate() {
    setEditing(null);
    setForm(emptyForm);
    setShowForm(true);
    setError('');
    setNotice('');
  }

  function openEdit(record: ManagedUser) {
    setEditing(record);
    setForm({
      ...emptyForm,
      nama: record.nama ?? '',
      phone: record.phone ?? '',
      id_number: record.id_number ?? '',
      role: record.role ?? 'kepala_kapal',
    });
    setShowForm(true);
    setError('');
    setNotice('');
  }

  async function saveUser(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError('');
    setNotice('');
    try {
      if (editing) {
        await adminFetch(user, `/api/users/${encodeURIComponent(editing.id)}`, {
          method: 'PATCH',
          body: JSON.stringify({
            nama: form.nama,
            phone: form.phone,
            id_number: form.id_number || null,
          }),
        });
        setNotice('Perubahan profil pengguna berhasil disimpan.');
      } else {
        await adminFetch(user, '/api/users', {
          method: 'POST',
          body: JSON.stringify(form),
        });
        setNotice('Akun berhasil dibuat. Pengguna dapat melengkapi PIN dan tanda tangan melalui aplikasi.');
      }
      setShowForm(false);
      await loadUsers();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Perubahan pengguna gagal disimpan.');
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive(record: ManagedUser) {
    const active = record.is_active !== false;
    const prompt = active
      ? `Nonaktifkan akun ${record.nama ?? record.id}? Pengguna tidak dapat masuk selama akun nonaktif.`
      : `Aktifkan kembali akun ${record.nama ?? record.id}?`;
    if (!window.confirm(prompt)) return;
    setError('');
    setNotice('');
    try {
      await adminFetch(user, `/api/users/${encodeURIComponent(record.id)}`, {
        method: 'PATCH',
        body: JSON.stringify({ is_active: !active }),
      });
      setNotice(active ? 'Akun berhasil dinonaktifkan.' : 'Akun berhasil diaktifkan kembali.');
      await loadUsers();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Status akun gagal diperbarui.');
    }
  }

  return (
    <>
      <section className="admin-page-heading">
        <div>
          <span className="eyebrow">ADMINISTRASI</span>
          <h1>Pengguna</h1>
          <p>Kelola akun dan profil sistem. Role ditetapkan saat akun dibuat dan tidak dapat diubah.</p>
        </div>
        <button className="button button--secondary" type="button" onClick={openCreate}>+ Tambah pengguna</button>
      </section>
      {error && <p className="admin-error" role="alert">{error}</p>}
      {notice && <p className="admin-success" role="status">{notice}</p>}
      <section className="admin-card">
        <div className="admin-toolbar">
          <input className="admin-input admin-search" type="search" placeholder="Cari nama, nomor telepon, atau ID…" value={search} onChange={(event) => setSearch(event.target.value)} />
          <div className="admin-toolbar__filters">
            <select className="admin-select" aria-label="Filter role" value={roleFilter} onChange={(event) => setRoleFilter(event.target.value)}>
              <option value="semua">Semua role</option>
              {Object.entries(roleLabels).map(([role, label]) => <option key={role} value={role}>{label}</option>)}
            </select>
            <select className="admin-select" aria-label="Filter status akun" value={activeFilter} onChange={(event) => setActiveFilter(event.target.value)}>
              <option value="semua">Semua status</option><option value="aktif">Aktif</option><option value="nonaktif">Nonaktif</option>
            </select>
            <button className="button button--secondary" type="button" onClick={() => { setLoading(true); void loadUsers(); }} disabled={loading}>Perbarui</button>
          </div>
        </div>
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead><tr><th>Nama pengguna</th><th>Email login</th><th>Role</th><th>Identitas / Telepon</th><th>Dibuat</th><th>Status</th><th>Aksi</th></tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={7} className="admin-empty">Memuat pengguna…</td></tr>
                : visibleUsers.length ? visibleUsers.map((record) => {
                  const active = record.is_active !== false;
                  return <tr key={record.id}>
                    <td><span className="admin-cell-stack"><strong>{record.nama || 'Tanpa nama'}</strong><small>{record.id}</small></span></td>
                    <td>{record.email || '—'}</td>
                    <td>{record.role ? roleLabels[record.role] : 'Tidak diketahui'}</td>
                    <td><span className="admin-cell-stack"><strong>{record.phone || '—'}</strong><small>{record.id_number || 'ID belum diisi'}</small></span></td>
                    <td>{formatAdminDate(record.created_at)}</td>
                    <td><span className={`admin-state${active ? '' : ' admin-state--off'}`}>{active ? 'Aktif' : 'Nonaktif'}</span></td>
                    <td><span className="admin-inline-actions">
                      <button className="admin-link-button" type="button" onClick={() => openEdit(record)}>Edit</button>
                      {record.id !== user.uid && <button className="admin-link-button" type="button" onClick={() => void toggleActive(record)}>{active ? 'Nonaktifkan' : 'Aktifkan'}</button>}
                    </span></td>
                  </tr>;
                }) : <tr><td colSpan={7} className="admin-empty">Tidak ada akun sesuai filter.</td></tr>}
            </tbody>
          </table>
        </div>
        <p className="table-footnote">Menampilkan {visibleUsers.length} dari {users.length} akun yang dimuat. Nonaktifkan akun untuk mempertahankan riwayat dan relasi data.</p>
      </section>

      {showForm && <div className="admin-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setShowForm(false); }}>
        <section className="admin-modal" role="dialog" aria-modal="true" aria-labelledby="user-form-title">
          <div className="admin-modal__header"><div><h2 id="user-form-title">{editing ? 'Edit profil pengguna' : 'Tambah pengguna'}</h2><p>{editing ? `Role tetap: ${editing.role ? roleLabels[editing.role] : '—'}` : 'Akun dibuat permanen dengan role yang ditentukan di sini.'}</p></div><button className="detail-dialog__close" type="button" aria-label="Tutup" onClick={() => setShowForm(false)}>×</button></div>
          <form onSubmit={saveUser}>
            <div className="admin-form-grid">
              <label className="admin-form-field">Nama lengkap<input className="admin-input" required value={form.nama} onChange={(event) => setForm({ ...form, nama: event.target.value })} /></label>
              {!editing && <label className="admin-form-field">Email login<input className="admin-input" type="email" autoComplete="email" required value={form.email} onChange={(event) => setForm({ ...form, email: event.target.value })} /></label>}
              {!editing && <label className="admin-form-field">Kata sandi awal<input className="admin-input" type="password" minLength={6} autoComplete="new-password" required value={form.password} onChange={(event) => setForm({ ...form, password: event.target.value })} /><small>Minimal 6 karakter; minta pengguna menggantinya setelah pengaturan akses tersedia.</small></label>}
              <label className="admin-form-field">Nomor telepon<input className="admin-input" type="tel" required value={form.phone} onChange={(event) => setForm({ ...form, phone: event.target.value })} /></label>
              <label className="admin-form-field">Nomor identitas<input className="admin-input" value={form.id_number} onChange={(event) => setForm({ ...form, id_number: event.target.value })} /></label>
              {!editing && <label className="admin-form-field">Role akun<select className="admin-select" value={form.role} onChange={(event) => setForm({ ...form, role: event.target.value as Role })}>{Object.entries(roleLabels).map(([role, label]) => <option value={role} key={role}>{label}</option>)}</select></label>}
              {editing && <label className="admin-form-field">Role akun<input className="admin-input" readOnly value={editing.role ? roleLabels[editing.role] : '—'} /></label>}
            </div>
            {error && <p className="admin-error" role="alert">{error}</p>}
            <div className="admin-form-footer"><button className="button button--secondary" type="button" onClick={() => setShowForm(false)}>Batal</button><button className="login-submit" type="submit" disabled={saving}>{saving ? 'Menyimpan…' : editing ? 'Simpan perubahan' : 'Buat akun'}</button></div>
          </form>
        </section>
      </div>}
    </>
  );
}

export default function UsersPage() {
  return <AdminShell title="Pengguna"><UsersContent /></AdminShell>;
}
