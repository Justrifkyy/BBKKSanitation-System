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

function validationError(type: MasterType, body: Record<string, unknown>) {
  if (type === 'ships') {
    if (typeof body.nama_kapal !== 'string' || !body.nama_kapal.trim()) return 'Nama kapal wajib diisi.';
    if (
      body.besar_kapal_grt !== undefined &&
      body.besar_kapal_grt !== null &&
      (typeof body.besar_kapal_grt !== 'number' ||
        !Number.isFinite(body.besar_kapal_grt) ||
        body.besar_kapal_grt < 0)
    ) return 'Nilai GRT harus berupa angka nol atau lebih.';
  } else if (type === 'aircraft') {
    if (typeof body.pemilik_atau_penyelenggara !== 'string' || !body.pemilik_atau_penyelenggara.trim()) {
      return 'Pemilik atau penyelenggara wajib diisi.';
    }
    if (typeof body.tanda_kebangsaan_dan_pendaftaran !== 'string' || !body.tanda_kebangsaan_dan_pendaftaran.trim()) {
      return 'Tanda kebangsaan dan pendaftaran wajib diisi.';
    }
  } else {
    if (typeof body.nama !== 'string' || !body.nama.trim()) return 'Nama lokasi wajib diisi.';
    if (!['pelabuhan', 'bandara', 'lokasi_sandar'].includes(String(body.jenis))) {
      return 'Jenis lokasi harus pelabuhan, bandara, atau lokasi sandar.';
    }
  }
  for (const field of ['jenis_kapal', 'bendera', 'nomor_imo', 'nama_pemilik_agen', 'kode']) {
    if (field in body && body[field] !== null && typeof body[field] !== 'string') {
      return `Nilai ${field} tidak valid.`;
    }
  }
  return null;
}

function masterData(type: MasterType, body: Record<string, unknown>) {
  if (type === 'ships') {
    const nama = (body.nama_kapal as string).trim();
    const imo = typeof body.nomor_imo === 'string' ? body.nomor_imo.trim().toUpperCase() : '';
    return {
      nama_kapal: nama,
      jenis_kapal: typeof body.jenis_kapal === 'string' ? body.jenis_kapal.trim() : '',
      besar_kapal_grt: typeof body.besar_kapal_grt === 'number' ? body.besar_kapal_grt : null,
      bendera: typeof body.bendera === 'string' ? body.bendera.trim() : '',
      nomor_imo: imo,
      nama_pemilik_agen: typeof body.nama_pemilik_agen === 'string' ? body.nama_pemilik_agen.trim() : '',
      normalized_key: imo ? `imo:${imo}` : `name:${normalized(nama)}`,
    };
  }
  if (type === 'aircraft') {
    const registration = (body.tanda_kebangsaan_dan_pendaftaran as string).trim().toUpperCase();
    return {
      pemilik_atau_penyelenggara: (body.pemilik_atau_penyelenggara as string).trim(),
      tanda_kebangsaan_dan_pendaftaran: registration,
      normalized_key: `registration:${registration}`,
    };
  }
  const name = (body.nama as string).trim();
  const kind = body.jenis as string;
  return {
    nama: name,
    jenis: kind,
    kode: typeof body.kode === 'string' ? body.kode.trim().toUpperCase() : '',
    normalized_key: `${kind}:${normalized(name)}`,
  };
}

async function duplicateRecord(type: MasterType, key: string, excludeId?: string) {
  const duplicate = await adminDb.collection(MASTER_COLLECTIONS[type])
    .where('normalized_key', '==', key)
    .limit(2)
    .get();
  return duplicate.docs.find((document) => document.id !== excludeId) ?? null;
}

export async function GET(request: NextRequest) {
  const authResult = await verifyAuth(request, ['validator_admin']);
  if ('error' in authResult) return authResult.error;
  const includeInactive = new URL(request.url).searchParams.get('include_inactive') === 'true';
  const collections = await Promise.all(
    Object.entries(MASTER_COLLECTIONS).map(async ([type, collection]) => {
      const snapshot = await adminDb.collection(collection).limit(1000).get();
      const records = snapshot.docs
        .map((doc): Record<string, unknown> => ({ ...doc.data(), id: doc.id }))
        .filter((record) => includeInactive || record.is_active !== false);
      return [type, records] as const;
    }),
  );
  return NextResponse.json({ master_data: Object.fromEntries(collections) });
}

export async function POST(request: NextRequest) {
  const authResult = await verifyAuth(request, ['validator_admin']);
  if ('error' in authResult) return authResult.error;
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Body JSON tidak valid.' }, { status: 400 });
  }
  if (!isMasterType(body.type)) {
    return NextResponse.json({ error: 'Jenis data master tidak valid.' }, { status: 400 });
  }
  const error = validationError(body.type, body);
  if (error) return NextResponse.json({ error }, { status: 400 });
  const data = masterData(body.type, body);
  const duplicate = await duplicateRecord(body.type, data.normalized_key);
  if (duplicate) {
    return NextResponse.json({ error: 'Data dengan identitas tersebut sudah terdaftar.' }, { status: 409 });
  }

  const collection = adminDb.collection(MASTER_COLLECTIONS[body.type]);
  const ref = collection.doc();
  const now = new Date();
  const record = {
    ...data,
    is_active: true,
    created_at: now,
    updated_at: now,
    dibuat_oleh: authResult.user.uid,
    diubah_oleh: authResult.user.uid,
  };
  const batch = adminDb.batch();
  batch.create(ref, record);
  batch.create(adminDb.collection(COLLECTIONS.AUDIT_LOG).doc(), {
    user_id: authResult.user.uid,
    aksi: `create_master_${body.type}`,
    entitas_terkait: `${MASTER_COLLECTIONS[body.type]}/${ref.id}`,
    waktu: now,
  });
  await batch.commit();
  return NextResponse.json({ record: { id: ref.id, ...record } }, { status: 201 });
}
