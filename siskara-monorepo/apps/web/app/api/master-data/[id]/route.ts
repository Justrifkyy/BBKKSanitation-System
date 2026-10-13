import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS } from '@/lib/constants';

const MASTER_COLLECTIONS = {
  ships: COLLECTIONS.MASTER_SHIPS,
  aircraft: COLLECTIONS.MASTER_AIRCRAFT,
  locations: COLLECTIONS.MASTER_LOCATIONS,
} as const;
type MasterType = keyof typeof MASTER_COLLECTIONS;

function isMasterType(value: unknown): value is MasterType {
  return typeof value === 'string' && value in MASTER_COLLECTIONS;
}

function normalized(value: string) {
  return value.trim().toLocaleLowerCase('id-ID').replace(/\s+/g, ' ');
}

function buildData(type: MasterType, body: Record<string, unknown>, current: FirebaseFirestore.DocumentData) {
  if (type === 'ships') {
    const nama = typeof body.nama_kapal === 'string' ? body.nama_kapal.trim() : current.nama_kapal;
    const imo = typeof body.nomor_imo === 'string' ? body.nomor_imo.trim().toUpperCase() : current.nomor_imo ?? '';
    const grt = 'besar_kapal_grt' in body ? body.besar_kapal_grt : current.besar_kapal_grt;
    if (typeof nama !== 'string' || !nama.trim()) throw new Error('Nama kapal wajib diisi.');
    if (grt !== null && grt !== undefined && (typeof grt !== 'number' || !Number.isFinite(grt) || grt < 0)) {
      throw new Error('Nilai GRT harus berupa angka nol atau lebih.');
    }
    return {
      nama_kapal: nama.trim(),
      jenis_kapal: typeof body.jenis_kapal === 'string' ? body.jenis_kapal.trim() : current.jenis_kapal ?? '',
      besar_kapal_grt: typeof grt === 'number' ? grt : null,
      bendera: typeof body.bendera === 'string' ? body.bendera.trim() : current.bendera ?? '',
      nomor_imo: imo,
      nama_pemilik_agen: typeof body.nama_pemilik_agen === 'string' ? body.nama_pemilik_agen.trim() : current.nama_pemilik_agen ?? '',
      normalized_key: imo ? `imo:${imo}` : `name:${normalized(nama)}`,
    };
  }
  if (type === 'aircraft') {
    const operator = typeof body.pemilik_atau_penyelenggara === 'string'
      ? body.pemilik_atau_penyelenggara.trim()
      : current.pemilik_atau_penyelenggara;
    const registration = typeof body.tanda_kebangsaan_dan_pendaftaran === 'string'
      ? body.tanda_kebangsaan_dan_pendaftaran.trim().toUpperCase()
      : current.tanda_kebangsaan_dan_pendaftaran;
    if (typeof operator !== 'string' || !operator || typeof registration !== 'string' || !registration) {
      throw new Error('Pemilik/penyelenggara dan tanda pendaftaran wajib diisi.');
    }
    return {
      pemilik_atau_penyelenggara: operator,
      tanda_kebangsaan_dan_pendaftaran: registration,
      normalized_key: `registration:${registration}`,
    };
  }
  const name = typeof body.nama === 'string' ? body.nama.trim() : current.nama;
  const kind = typeof body.jenis === 'string' ? body.jenis : current.jenis;
  const code = typeof body.kode === 'string' ? body.kode.trim().toUpperCase() : current.kode ?? '';
  if (typeof name !== 'string' || !name ||
    !['pelabuhan', 'bandara', 'lokasi_sandar'].includes(kind)) {
    throw new Error('Nama dan jenis lokasi wajib diisi dengan nilai yang valid.');
  }
  return { nama: name, jenis: kind, kode: code, normalized_key: `${kind}:${normalized(name)}` };
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
  if (!isMasterType(body.type)) {
    return NextResponse.json({ error: 'Jenis data master tidak valid.' }, { status: 400 });
  }
  const collection = adminDb.collection(MASTER_COLLECTIONS[body.type]);
  const ref = collection.doc(id);
  const snapshot = await ref.get();
  if (!snapshot.exists) {
    return NextResponse.json({ error: 'Data master tidak ditemukan.' }, { status: 404 });
  }

  let update: Record<string, unknown>;
  try {
    update = buildData(body.type, body, snapshot.data()!);
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : 'Data master tidak valid.' }, { status: 400 });
  }
  const duplicate = await collection.where('normalized_key', '==', update.normalized_key).limit(2).get();
  if (duplicate.docs.some((document) => document.id !== id)) {
    return NextResponse.json({ error: 'Data dengan identitas tersebut sudah terdaftar.' }, { status: 409 });
  }
  if ('is_active' in body && typeof body.is_active !== 'boolean') {
    return NextResponse.json({ error: 'Status aktif harus berupa boolean.' }, { status: 400 });
  }
  const now = new Date();
  const profileUpdate = {
    ...update,
    ...(typeof body.is_active === 'boolean' ? { is_active: body.is_active } : {}),
    updated_at: now,
    diubah_oleh: authResult.user.uid,
  };
  const batch = adminDb.batch();
  batch.update(ref, profileUpdate);
  batch.create(adminDb.collection(COLLECTIONS.AUDIT_LOG).doc(), {
    user_id: authResult.user.uid,
    aksi: typeof body.is_active === 'boolean'
      ? body.is_active ? `activate_master_${body.type}` : `deactivate_master_${body.type}`
      : `update_master_${body.type}`,
    entitas_terkait: `${MASTER_COLLECTIONS[body.type]}/${id}`,
    waktu: now,
  });
  await batch.commit();
  return NextResponse.json({ record: { id, ...snapshot.data(), ...profileUpdate } });
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Body JSON tidak valid.' }, { status: 400 });
  }
  const response = await PATCH(
    new NextRequest(request.url, {
      method: 'PATCH',
      headers: request.headers,
      body: JSON.stringify({ ...body, is_active: false }),
    }),
    { params: Promise.resolve({ id }) },
  );
  if (response.ok) return NextResponse.json({ success: true, is_active: false });
  return response;
}
