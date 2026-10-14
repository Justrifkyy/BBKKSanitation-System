import { GeoPoint, Timestamp } from "firebase-admin/firestore";
import { NextRequest, NextResponse } from "next/server";
import { verifyAuth } from "@/lib/auth";
import { adminDb } from "@/lib/firebase-admin";
import { COLLECTIONS } from "@/lib/constants";
import {
  headObject,
  isR2Configured,
  parseStoragePath,
  promoteObject,
  storagePath,
} from "@/lib/r2";

const MAX_PHOTO_BYTES = 2 * 1024 * 1024;
const MAX_VIDEO_BYTES = 50 * 1024 * 1024;
const EVIDENCE_KEY_PATTERN =
  /^staging\/submissions\/([A-Za-z0-9_-]{1,128})\/answers\/([A-Za-z0-9_-]{1,128})\/([0-9a-f-]{36}\.(jpg|png|webp|mp4|mov))$/i;
const EXTENSION_BY_CONTENT_TYPE: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "video/mp4": "mp4",
  "video/quicktime": "mov",
};

export async function POST(request: NextRequest) {
  const authResult = await verifyAuth(request, [
    "kepala_kapal",
    "kepala_penerbangan",
  ]);
  if ("error" in authResult) return authResult.error;
  if (!isR2Configured()) {
    return NextResponse.json(
      { error: "Penyimpanan bukti media belum dikonfigurasi di server." },
      { status: 503 },
    );
  }

  const body = (await request.json()) as Record<string, unknown>;
  if (
    typeof body.storage_path !== "string" ||
    typeof body.latitude !== "number" ||
    !Number.isFinite(body.latitude) ||
    body.latitude < -90 ||
    body.latitude > 90 ||
    typeof body.longitude !== "number" ||
    !Number.isFinite(body.longitude) ||
    body.longitude < -180 ||
    body.longitude > 180 ||
    typeof body.timestamp !== "string" ||
    typeof body.tipe !== "string" ||
    !["foto", "video"].includes(body.tipe)
  ) {
    return NextResponse.json(
      { error: "Metadata bukti pemeriksaan tidak valid." },
      { status: 400 },
    );
  }

  const key = parseStoragePath(body.storage_path);
  const match = key?.match(EVIDENCE_KEY_PATTERN);
  if (!key || !match) {
    return NextResponse.json(
      { error: "Lokasi berkas bukti tidak valid." },
      { status: 400 },
    );
  }
  const [, submissionId, answerId, fileName, extension] = match;
  const captureTime = new Date(body.timestamp);
  if (
    Number.isNaN(captureTime.getTime()) ||
    captureTime.getTime() > Date.now() + 5 * 60 * 1000
  ) {
    return NextResponse.json(
      { error: "Waktu pengambilan bukti tidak valid." },
      { status: 400 },
    );
  }

  const submissionRef = adminDb
    .collection(COLLECTIONS.SUBMISSIONS)
    .doc(submissionId);
  const answerRef = submissionRef
    .collection(COLLECTIONS.SUBMISSION_ANSWERS)
    .doc(answerId);
  const [submissionSnapshot, answerSnapshot] = await Promise.all([
    submissionRef.get(),
    answerRef.get(),
  ]);
  if (!submissionSnapshot.exists || !answerSnapshot.exists) {
    return NextResponse.json(
      { error: "Pengajuan atau jawaban checklist tidak ditemukan." },
      { status: 404 },
    );
  }

  const submission = submissionSnapshot.data()!;
  const expectedMode =
    authResult.user.role === "kepala_kapal" ? "kapal" : "pesawat";
  if (
    submission.pengisi_id !== authResult.user.uid ||
    submission.moda_transportasi !== expectedMode
  ) {
    return NextResponse.json(
      { error: "Bukti hanya dapat ditambahkan ke pengajuan milik akun Anda." },
      { status: 403 },
    );
  }
  if (submission.status !== "draft") {
    return NextResponse.json(
      { error: "Bukti hanya dapat ditambahkan selama pengajuan berstatus draft." },
      { status: 409 },
    );
  }

  const object = await headObject(key);
  const isVideo = body.tipe === "video";
  const validType = isVideo
    ? ["video/mp4", "video/quicktime"].includes(object?.ContentType ?? "")
    : ["image/jpeg", "image/png", "image/webp"].includes(object?.ContentType ?? "");
  const expectedExtension =
    EXTENSION_BY_CONTENT_TYPE[object?.ContentType ?? ""];
  const size = object?.ContentLength ?? 0;
  if (
    !object ||
    !validType ||
    expectedExtension !== extension.toLowerCase() ||
    size <= 0 ||
    size > (isVideo ? MAX_VIDEO_BYTES : MAX_PHOTO_BYTES)
  ) {
    return NextResponse.json(
      { error: "Berkas bukti belum diunggah atau tidak memenuhi batas ukuran/jenis." },
      { status: 400 },
    );
  }

  const permanentKey = `submissions/${submissionId}/answers/${answerId}/${fileName}`;
  await promoteObject(key, permanentKey);

  const mediaRef = answerRef
    .collection(COLLECTIONS.SUBMISSION_ANSWER_MEDIA)
    .doc("evidence");
  await mediaRef.set({
    answer_id: answerId,
    tipe: body.tipe,
    file_url: storagePath(permanentKey),
    content_type: object.ContentType,
    size_bytes: size,
    gps: new GeoPoint(body.latitude, body.longitude),
    timestamp: Timestamp.fromDate(captureTime),
  });

  return NextResponse.json({
    success: true,
    storage_path: storagePath(permanentKey),
  });
}
