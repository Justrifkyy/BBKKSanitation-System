'use client';

import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { AdminShell, useAdmin } from '../admin-shell';
import { adminFetch } from '@/lib/admin-api';

type ChecklistItem = {
  id?: string;
  kategori: string;
  label: string;
  tipe_input: string;
  opsi_jawaban: string[];
  nilai_gagal: unknown;
  nilai_perlu_alasan: unknown;
  nilai_perlu_media: unknown;
  auto_reject_on_fail: boolean;
  requires_media_on_fail: boolean;
  wajib_diisi: boolean;
  wajib_jika: unknown;
  order?: number;
};
type Template = {
  id: string;
  moda_transportasi: 'kapal' | 'pesawat';
  nama_template: string;
  versi: number;
  is_active: boolean;
  items: ChecklistItem[];
};
type TemplatesResponse = { templates: Template[] };
type FormState = { moda_transportasi: 'kapal' | 'pesawat'; nama_template: string; items: ChecklistItem[] };

function newItem(): ChecklistItem {
  return {
    kategori: '',
    label: '',
    tipe_input: 'binary',
    opsi_jawaban: [],
    nilai_gagal: '',
    nilai_perlu_alasan: '',
    nilai_perlu_media: '',
    auto_reject_on_fail: false,
    requires_media_on_fail: false,
    wajib_diisi: true,
    wajib_jika: null,
  };
}

function failureText(value: unknown): string {
  if (typeof value === 'string') return value;
  if (value === null || value === undefined) return '';
  return JSON.stringify(value);
}

function parseRule(value: unknown): unknown {
  const raw = failureText(value).trim();
  if (raw.startsWith('[') || raw.startsWith('{')) {
    try { return JSON.parse(raw); } catch { return raw; }
  }
  return raw || null;
}

function prepareItem(item: ChecklistItem) {
  return {
    kategori: item.kategori,
    label: item.label,
    tipe_input: item.tipe_input,
    opsi_jawaban: item.opsi_jawaban,
    nilai_gagal: parseRule(item.nilai_gagal) ?? '',
    nilai_perlu_alasan: parseRule(item.nilai_perlu_alasan),
    nilai_perlu_media: parseRule(item.nilai_perlu_media),
    auto_reject_on_fail: item.auto_reject_on_fail,
    requires_media_on_fail: item.requires_media_on_fail,
    wajib_diisi: item.wajib_diisi,
    wajib_jika: parseRule(item.wajib_jika),
  };
}

function ChecklistContent() {
  const { user } = useAdmin();
  const [templates, setTemplates] = useState<Template[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [modeFilter, setModeFilter] = useState('semua');
  const [form, setForm] = useState<FormState | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);

  const loadTemplates = useCallback(async () => {
    try {
      const result = await adminFetch<TemplatesResponse>(user, '/api/checklist-templates');
      setTemplates(result.templates);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Template checklist gagal dimuat.');
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    let active = true;
    void adminFetch<TemplatesResponse>(user, '/api/checklist-templates')
      .then((result) => { if (active) setTemplates(result.templates); })
      .catch((cause: unknown) => {
        if (active) setError(cause instanceof Error ? cause.message : 'Template checklist gagal dimuat.');
      })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [user]);

  function openNew(mode: 'kapal' | 'pesawat') {
    const previous = templates.find((template) => template.moda_transportasi === mode);
    setEditingId(null);
    setForm({ moda_transportasi: mode, nama_template: previous?.nama_template ?? '', items: [] });
    setError('');
    setNotice('');
  }

  function openEdit(template: Template) {
    setEditingId(template.id);
    setForm({
      moda_transportasi: template.moda_transportasi,
      nama_template: template.nama_template,
      items: template.items.map((item) => ({ ...newItem(), ...item, opsi_jawaban: Array.isArray(item.opsi_jawaban) ? item.opsi_jawaban : [] })),
    });
    setError('');
    setNotice('');
  }

  async function saveTemplate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!form) return;
    if (form.items.some((item) => !item.label.trim())) {
      setError('Setiap item checklist harus memiliki label.');
      return;
    }
    setSaving(true);
    setError('');
    try {
      if (editingId) {
        await adminFetch(user, `/api/checklist-templates/${encodeURIComponent(editingId)}`, {
          method: 'PATCH',
          body: JSON.stringify({ nama_template: form.nama_template, items: form.items.map(prepareItem) }),
        });
        setNotice('Template berhasil diperbarui.');
      } else {
        await adminFetch(user, '/api/checklist-templates', {
          method: 'POST',
          body: JSON.stringify({
            moda_transportasi: form.moda_transportasi,
            nama_template: form.nama_template,
            items: form.items.map(prepareItem),
          }),
        });
        setNotice('Versi template baru berhasil dibuat dalam status nonaktif.');
      }
      setForm(null);
      await loadTemplates();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Template gagal disimpan.');
    } finally {
      setSaving(false);
    }
  }

  async function activate(template: Template) {
    if (template.is_active) return;
    if (!window.confirm(`Aktifkan ${template.nama_template} versi ${template.versi}? Versi aktif lama untuk moda ini akan dinonaktifkan.`)) return;
    setError('');
    setNotice('');
    try {
      await adminFetch(user, `/api/checklist-templates/${encodeURIComponent(template.id)}`, {
        method: 'PATCH',
        body: JSON.stringify({ is_active: true }),
      });
      setNotice('Versi template aktif berhasil diganti.');
      await loadTemplates();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Template gagal diaktifkan.');
    }
  }

  const visible = modeFilter === 'semua'
    ? templates
    : templates.filter((template) => template.moda_transportasi === modeFilter);

  function updateItem(index: number, patch: Partial<ChecklistItem>) {
    setForm((current) => current ? {
      ...current,
      items: current.items.map((item, itemIndex) => itemIndex === index ? { ...item, ...patch } : item),
    } : current);
  }

  return <>
    <section className="admin-page-heading">
      <div><span className="eyebrow">KONFIGURASI FORM</span><h1>Checklist</h1><p>Kelola versi dan aturan item checklist. Perubahan pada template yang sudah dipakai pengajuan dilindungi agar riwayat tetap konsisten.</p></div>
      <div className="admin-inline-actions">
        <button className="button button--secondary" type="button" onClick={() => openNew('kapal')}>+ Template kapal</button>
        <button className="button button--secondary" type="button" onClick={() => openNew('pesawat')}>+ Template pesawat</button>
      </div>
    </section>
    {error && <p className="admin-error" role="alert">{error}</p>}
    {notice && <p className="admin-success" role="status">{notice}</p>}
    <section className="admin-card">
      <div className="admin-toolbar">
        <div><strong>Versi checklist</strong><p className="table-footnote">Buat versi baru saat template yang aktif telah digunakan dalam pengajuan.</p></div>
        <select className="admin-select" aria-label="Filter moda transportasi" value={modeFilter} onChange={(event) => setModeFilter(event.target.value)}>
          <option value="semua">Semua moda</option><option value="kapal">Kapal</option><option value="pesawat">Pesawat</option>
        </select>
      </div>
      <div className="admin-table-wrap"><table className="admin-table">
        <thead><tr><th>Template</th><th>Moda</th><th>Versi</th><th>Item</th><th>Status</th><th>Aksi</th></tr></thead>
        <tbody>{loading ? <tr><td className="admin-empty" colSpan={6}>Memuat template…</td></tr>
          : visible.length ? visible.map((template) => <tr key={template.id}>
            <td><span className="admin-cell-stack"><strong>{template.nama_template}</strong><small>{template.id}</small></span></td>
            <td>{template.moda_transportasi === 'kapal' ? 'Kapal' : 'Pesawat'}</td>
            <td>v{template.versi}</td><td>{template.items?.length ?? 0}</td>
            <td><span className={`admin-state${template.is_active ? '' : ' admin-state--off'}`}>{template.is_active ? 'Aktif' : 'Arsip'}</span></td>
            <td><span className="admin-inline-actions"><button className="admin-link-button" type="button" onClick={() => openEdit(template)}>Edit</button>{!template.is_active && <button className="admin-link-button" type="button" onClick={() => void activate(template)}>Aktifkan</button>}</span></td>
          </tr>) : <tr><td colSpan={6} className="admin-empty">Belum ada template untuk filter ini.</td></tr>}
        </tbody>
      </table></div>
    </section>

    {form && <div className="admin-modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setForm(null); }}>
      <section className="admin-modal" role="dialog" aria-modal="true" aria-labelledby="template-title">
        <div className="admin-modal__header"><div><h2 id="template-title">{editingId ? 'Edit checklist template' : 'Buat versi template'}</h2><p>{form.moda_transportasi === 'kapal' ? 'Kapal' : 'Pesawat'} · item urut sesuai susunan daftar.</p></div><button className="detail-dialog__close" type="button" aria-label="Tutup" onClick={() => setForm(null)}>×</button></div>
        <form onSubmit={saveTemplate}>
          <label className="admin-form-field">Nama template<input className="admin-input" required value={form.nama_template} onChange={(event) => setForm({ ...form, nama_template: event.target.value })} /></label>
          <div className="admin-toolbar" style={{ marginTop: 20 }}>
            <div><strong>Item checklist ({form.items.length})</strong><p className="table-footnote">Nilai gagal menerima satu nilai atau JSON array. Pilihan dipisahkan dengan koma.</p></div>
            <button className="button button--secondary" type="button" onClick={() => setForm({ ...form, items: [...form.items, newItem()] })}>+ Tambah item</button>
          </div>
          {form.items.map((item, index) => <div className="template-item-editor" key={`${item.id ?? 'new'}-${index}`}>
            <label className="admin-form-field">Kategori<input className="admin-input" value={item.kategori} onChange={(event) => updateItem(index, { kategori: event.target.value })} /></label>
            <label className="admin-form-field">Label item<input className="admin-input" required value={item.label} onChange={(event) => updateItem(index, { label: event.target.value })} /></label>
            <label className="admin-form-field">Tipe input<select className="admin-select" value={item.tipe_input} onChange={(event) => updateItem(index, { tipe_input: event.target.value })}>{['binary', 'three_level', 'multi_choice', 'single_select', 'numeric', 'text', 'textarea'].map((type) => <option key={type}>{type}</option>)}</select></label>
            <label className="admin-form-field">Nilai gagal<input className="admin-input" placeholder="contoh: tidak_layak" value={failureText(item.nilai_gagal)} onChange={(event) => updateItem(index, { nilai_gagal: event.target.value })} /></label>
            <button className="admin-link-button" type="button" aria-label={`Hapus item ${index + 1}`} onClick={() => setForm({ ...form, items: form.items.filter((_, itemIndex) => itemIndex !== index) })}>Hapus</button>
            <label className="admin-form-field">Pilihan (pisahkan koma)<input className="admin-input" value={item.opsi_jawaban.join(', ')} onChange={(event) => updateItem(index, { opsi_jawaban: event.target.value.split(',').map((option) => option.trim()).filter(Boolean) })} /></label>
            <label className="admin-form-field">Butuh alasan untuk<input className="admin-input" value={failureText(item.nilai_perlu_alasan)} onChange={(event) => updateItem(index, { nilai_perlu_alasan: event.target.value })} /></label>
            <label className="admin-form-field">Butuh media untuk<input className="admin-input" value={failureText(item.nilai_perlu_media)} onChange={(event) => updateItem(index, { nilai_perlu_media: event.target.value })} /></label>
            <label className="admin-form-field">Syarat wajib (JSON, opsional)<input className="admin-input" placeholder='{"field":"...","equals":"..."}' value={failureText(item.wajib_jika)} onChange={(event) => updateItem(index, { wajib_jika: event.target.value })} /></label>
            <label className="admin-form-field">Opsi aturan
              <span><input type="checkbox" checked={item.auto_reject_on_fail} onChange={(event) => updateItem(index, { auto_reject_on_fail: event.target.checked })} /> Tolak otomatis</span>
              <span><input type="checkbox" checked={item.requires_media_on_fail} onChange={(event) => updateItem(index, { requires_media_on_fail: event.target.checked })} /> Wajib media saat gagal</span>
              <span><input type="checkbox" checked={item.wajib_diisi} onChange={(event) => updateItem(index, { wajib_diisi: event.target.checked })} /> Wajib diisi</span>
            </label>
          </div>)}
          {!form.items.length && <p className="admin-empty">Belum ada item. Tambahkan item checklist sebelum menyimpan.</p>}
          {error && <p className="admin-error" role="alert">{error}</p>}
          <div className="admin-form-footer"><button className="button button--secondary" type="button" onClick={() => setForm(null)}>Batal</button><button className="login-submit" type="submit" disabled={saving || !form.items.length}>{saving ? 'Menyimpan…' : 'Simpan template'}</button></div>
        </form>
      </section>
    </div>}
  </>;
}

export default function ChecklistsPage() {
  return <AdminShell title="Checklist"><ChecklistContent /></AdminShell>;
}
