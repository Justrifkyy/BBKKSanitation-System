import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS } from '@/lib/constants';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await verifyAuth(request);
  if ('error' in authResult) return authResult.error;
  const { id } = await params;
  const ref = adminDb.collection(COLLECTIONS.CHECKLIST_TEMPLATES).doc(id);
  const [template, items] = await Promise.all([
    ref.get(),
    ref.collection(COLLECTIONS.CHECKLIST_TEMPLATE_ITEMS).orderBy('order', 'asc').get(),
  ]);
  if (!template.exists) {
    return NextResponse.json({ error: 'Template tidak ditemukan.' }, { status: 404 });
  }
  return NextResponse.json({
    template: { id, ...template.data(), items: items.docs.map((item) => ({ id: item.id, ...item.data() })) },
  });
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const authResult = await verifyAuth(request, ['validator_admin']);
  if ('error' in authResult) return authResult.error;
  const { id } = await params;
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Body JSON tidak valid.' }, { status: 400 });
  }

  const ref = adminDb.collection(COLLECTIONS.CHECKLIST_TEMPLATES).doc(id);
  const current = await ref.get();
  if (!current.exists) {
    return NextResponse.json({ error: 'Template tidak ditemukan.' }, { status: 404 });
  }
  if ('moda_transportasi' in body || 'versi' in body) {
    return NextResponse.json({ error: 'Moda dan versi template tidak dapat diubah.' }, { status: 400 });
  }

  const update: Record<string, unknown> = { updated_at: new Date() };
  if ('nama_template' in body) {
    if (typeof body.nama_template !== 'string' || !body.nama_template.trim()) {
      return NextResponse.json({ error: 'Nama template tidak boleh kosong.' }, { status: 400 });
    }
    update.nama_template = body.nama_template.trim();
  }
  if ('is_active' in body) {
    if (typeof body.is_active !== 'boolean') {
      return NextResponse.json({ error: 'Status aktif template tidak valid.' }, { status: 400 });
    }
    update.is_active = body.is_active;
  }
  if (
    'items' in body &&
    (!Array.isArray(body.items) || body.items.length === 0 || body.items.length > 200 ||
      body.items.some((item) => !item || typeof item !== 'object' ||
        typeof (item as Record<string, unknown>).label !== 'string' ||
        !(item as Record<string, unknown>).label?.toString().trim()))
  ) {
    return NextResponse.json({ error: 'Daftar item tidak valid (1–200 item berlabel wajib).' }, { status: 400 });
  }
  const replacementItems = Array.isArray(body.items)
    ? body.items as Record<string, unknown>[]
    : null;

  const previousItems = await ref.collection(COLLECTIONS.CHECKLIST_TEMPLATE_ITEMS).get();
  if (body.is_active === true && previousItems.empty && !('items' in body)) {
    return NextResponse.json({ error: 'Template tanpa item tidak dapat diaktifkan.' }, { status: 409 });
  }
  if ('items' in body) {
    const usedBySubmission = await adminDb.collection(COLLECTIONS.SUBMISSIONS)
      .where('template_id', '==', id)
      .limit(1)
      .get();
    if (!usedBySubmission.empty) {
      return NextResponse.json({
        error: 'Template sudah digunakan oleh pengajuan. Buat versi template baru agar riwayat tetap utuh.',
      }, { status: 409 });
    }
  }

  const batch = adminDb.batch();
  let operationCount = previousItems.size + 2;
  if (body.is_active === true) {
    const siblings = await adminDb.collection(COLLECTIONS.CHECKLIST_TEMPLATES)
      .where('moda_transportasi', '==', current.data()?.moda_transportasi)
      .get();
    siblings.docs.forEach((sibling) => {
      if (sibling.id !== id && sibling.data().is_active === true) {
        operationCount += 1;
        batch.update(sibling.ref, { is_active: false, updated_at: new Date() });
      }
    });
  }
  if ('items' in body) {
    operationCount += replacementItems?.length ?? 0;
    if (operationCount > 500) {
      return NextResponse.json({ error: 'Perubahan melebihi batas operasi transaksi Firestore.' }, { status: 400 });
    }
    previousItems.docs.forEach((item) => batch.delete(item.ref));
    replacementItems?.forEach((item, index) => {
      const itemRef = ref.collection(COLLECTIONS.CHECKLIST_TEMPLATE_ITEMS).doc();
      batch.create(itemRef, {
        template_id: id,
        kategori: typeof item.kategori === 'string' ? item.kategori.trim() : '',
        label: (item.label as string).trim(),
        tipe_input: typeof item.tipe_input === 'string' ? item.tipe_input : 'binary',
        opsi_jawaban: Array.isArray(item.opsi_jawaban) ? item.opsi_jawaban : [],
        nilai_gagal: item.nilai_gagal ?? '',
        nilai_perlu_alasan: item.nilai_perlu_alasan ?? null,
        nilai_perlu_media: item.nilai_perlu_media ?? null,
        auto_reject_on_fail: item.auto_reject_on_fail === true,
        requires_media_on_fail: item.requires_media_on_fail === true,
        wajib_diisi: item.wajib_diisi !== false,
        wajib_jika: item.wajib_jika ?? null,
        order: index,
      });
    });
  }
  batch.update(ref, update);
  batch.create(adminDb.collection(COLLECTIONS.AUDIT_LOG).doc(), {
    user_id: authResult.user.uid,
    aksi: body.is_active === true ? 'activate_checklist_template' : 'update_checklist_template',
    entitas_terkait: `checklist_templates/${id}`,
    waktu: new Date(),
  });
  await batch.commit();
  return NextResponse.json({ id, ...current.data(), ...update });
}
