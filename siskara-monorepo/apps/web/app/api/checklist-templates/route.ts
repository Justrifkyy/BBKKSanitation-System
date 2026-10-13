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
  const templates = snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
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
  const body = await request.json();
  const { moda_transportasi, nama_template, items } = body;

  if (!moda_transportasi || !nama_template) {
    return NextResponse.json(
      { error: 'Missing required fields: moda_transportasi, nama_template' },
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

  const latestVersion = existingSnapshot.empty ? 0 : existingSnapshot.docs[0].data().versi;

  // Create the template
  const templateRef = await adminDb.collection(COLLECTIONS.CHECKLIST_TEMPLATES).add({
    moda_transportasi,
    nama_template,
    versi: latestVersion + 1,
    is_active: false, // Must be explicitly activated
  });

  // Create template items if provided
  if (items && Array.isArray(items)) {
    const batch = adminDb.batch();
    items.forEach((item: Record<string, unknown>, index: number) => {
      const itemRef = templateRef.collection(COLLECTIONS.CHECKLIST_TEMPLATE_ITEMS).doc();
      batch.set(itemRef, {
        template_id: templateRef.id,
        kategori: item.kategori || '',
        label: item.label || '',
        tipe_input: item.tipe_input || 'binary',
        nilai_gagal: item.nilai_gagal || '',
        auto_reject_on_fail: item.auto_reject_on_fail ?? false,
        requires_media_on_fail: item.requires_media_on_fail ?? false,
        order: index,
      });
    });
    await batch.commit();
  }

  // Audit log
  await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
    user_id: user.uid,
    aksi: 'create_checklist_template',
    entitas_terkait: `checklist_templates/${templateRef.id}`,
    waktu: new Date(),
  });

  return NextResponse.json(
    { id: templateRef.id, versi: latestVersion + 1 },
    { status: 201 }
  );
}
