import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS } from '@/lib/constants';

/**
 * GET /api/checklist-templates
 * List all checklist templates.
 */
export async function GET(request: NextRequest) {
  const authResult = await verifyAuth(request);
  if ('error' in authResult) return authResult.error;

  const { searchParams } = new URL(request.url);
  const moda = searchParams.get('moda_transportasi');
  const activeOnly = searchParams.get('active_only') === 'true';

  let query: FirebaseFirestore.Query = adminDb.collection(COLLECTIONS.CHECKLIST_TEMPLATES);

  if (moda) {
    query = query.where('moda_transportasi', '==', moda);
  }
  if (activeOnly) {
    query = query.where('is_active', '==', true);
  }

  const snapshot = await query.orderBy('versi', 'desc').get();
  const templates = await Promise.all(snapshot.docs.map(async (doc) => {
    const items = await doc.ref
      .collection(COLLECTIONS.CHECKLIST_TEMPLATE_ITEMS)
      .orderBy('order', 'asc')
      .get();
    return {
      id: doc.id,
      ...doc.data(),
      items: items.docs.map((item) => ({ id: item.id, ...item.data() })),
    };
  }));

  return NextResponse.json({ templates });
}

/**
 * POST /api/checklist-templates
 * Create a new checklist template.
 * Role required: validator_admin.
 */
export async function POST(request: NextRequest) {
  const authResult = await verifyAuth(request, ['validator_admin']);
  if ('error' in authResult) return authResult.error;

  const { user } = authResult;
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Body JSON tidak valid.' }, { status: 400 });
  }
  const { moda_transportasi, nama_template, items } = body;

  if (
    !['kapal', 'pesawat'].includes(String(moda_transportasi)) ||
    typeof nama_template !== 'string' ||
    !nama_template.trim() ||
    !Array.isArray(items) ||
    items.length === 0 ||
    items.length > 200 ||
    items.some((item) => !item || typeof item !== 'object' ||
      typeof (item as Record<string, unknown>).label !== 'string' ||
      !(item as Record<string, unknown>).label?.toString().trim())
  ) {
    return NextResponse.json(
      { error: 'Moda, nama template, atau daftar item tidak valid (1–200 item berlabel wajib).' },
      { status: 400 }
    );
  }

  // Get the latest version number for this transport mode
  const existingSnapshot = await adminDb
    .collection(COLLECTIONS.CHECKLIST_TEMPLATES)
    .where('moda_transportasi', '==', moda_transportasi)
    .orderBy('versi', 'desc')
    .limit(1)
    .get();

  const latestVersion = existingSnapshot.empty ? 0 : Number(existingSnapshot.docs[0].data().versi) || 0;

  const templateRef = adminDb.collection(COLLECTIONS.CHECKLIST_TEMPLATES).doc();
  const batch = adminDb.batch();
  batch.create(templateRef, {
    moda_transportasi,
    nama_template: nama_template.trim(),
    versi: latestVersion + 1,
    is_active: false, // Must be explicitly activated
    created_at: new Date(),
  });

  items.forEach((rawItem, index) => {
    const item = rawItem as Record<string, unknown>;
    const itemRef = templateRef.collection(COLLECTIONS.CHECKLIST_TEMPLATE_ITEMS).doc();
    batch.create(itemRef, {
      template_id: templateRef.id,
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
  batch.create(adminDb.collection(COLLECTIONS.AUDIT_LOG).doc(), {
    user_id: user.uid,
    aksi: 'create_checklist_template',
    entitas_terkait: `checklist_templates/${templateRef.id}`,
    waktu: new Date(),
  });
  await batch.commit();

  return NextResponse.json(
    { id: templateRef.id, versi: latestVersion + 1 },
    { status: 201 }
  );
}
