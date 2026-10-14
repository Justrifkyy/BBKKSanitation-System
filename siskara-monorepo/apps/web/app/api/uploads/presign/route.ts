import { randomUUID } from "node:crypto";
import { NextRequest, NextResponse } from "next/server";
import { verifyAuth } from "@/lib/auth";
import { adminDb } from "@/lib/firebase-admin";
import { COLLECTIONS } from "@/lib/constants";
import { createUploadUrl, storagePath } from "@/lib/r2";

const MAX_SIGNATURE_BYTES = 512 * 1024;
const MAX_PHOTO_BYTES = 2 * 1024 * 1024;
const MAX_VIDEO_BYTES = 50 * 1024 * 1024;
const ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

const evidenceTypes: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "video/mp4": "mp4",
  "video/quicktime": "mov",
};
const signatureTypes: Record<string, string> = {
  "image/png": "png",
  "image/svg+xml": "svg",
};

export async function POST(request: NextRequest) {
  const authResult = await verifyAuth(request, [
    "kepala_kapal",
    "kepala_penerbangan",
    "staf_bbkk",
  ]);
  if ("error" in authResult) return authResult.error;

  const body = (await request.json()) as Record<string, unknown>;
  const purpose = body.purpose;
  const contentType = body.content_type;
  const size = body.size;

  if (
    typeof contentType !== "string" ||
    typeof size !== "number" ||
    !Number.isSafeInteger(size) ||
    size <= 0
  ) {
    return NextResponse.json(
      { error: "Jenis atau ukuran berkas tidak valid." },
      { status: 400 },
    );
  }

  if (purpose === "signature") {
    if (
      authResult.user.role === "kepala_kapal" ||
      authResult.user.role === "kepala_penerbangan" ||
      authResult.user.role === "staf_bbkk"
    ) {
      const extension =
        typeof contentType === "string" ? signatureTypes[contentType] : null;
      if (!extension || size > MAX_SIGNATURE_BYTES) {
        return NextResponse.json(
          { error: "Tanda tangan harus PNG atau SVG dengan ukuran maksimal 512 KB." },
          { status: 400 },
        );
      }

      const userRef = adminDb.collection(COLLECTIONS.USERS).doc(authResult.user.uid);
      const userSnapshot = await userRef.get();
      if (!userSnapshot.exists) {
        return NextResponse.json(
          { error: "Profil pengguna tidak ditemukan." },
          { status: 404 },
        );
      }
      if (userSnapshot.data()?.signature_url) {
        return NextResponse.json(
          { error: "Tanda tangan sudah disimpan dan tidak dapat diganti." },
          { status: 409 },
        );
      }

      const key = `staging/signatures/${authResult.user.uid}/${randomUUID()}.${extension}`;
      return NextResponse.json({
        upload_url: await createUploadUrl(key, {
          contentLength: size,
          contentType,
        }),
        storage_path: storagePath(key),
        required_headers: {
          "Content-Type": contentType,
          "Content-Length": String(size),
        },
      });
    }
  }

  if (purpose !== "evidence") {
    return NextResponse.json(
      { error: "Tujuan unggah tidak valid." },
      { status: 400 },
    );
  }
  if (
    authResult.user.role !== "kepala_kapal" &&
    authResult.user.role !== "kepala_penerbangan"
  ) {
    return NextResponse.json(
      { error: "Hanya Nahkoda atau Pilot yang dapat mengunggah bukti." },
      { status: 403 },
    );
  }

  const maxSize = contentType.startsWith("video/")
    ? MAX_VIDEO_BYTES
    : MAX_PHOTO_BYTES;
  const extension = evidenceTypes[contentType];
  if (!extension || size > maxSize) {
    return NextResponse.json(
      { error: "Jenis berkas tidak didukung atau ukuran berkas terlalu besar." },
      { status: 400 },
    );
  }

  const submissionId = body.submission_id;
  const answerId = body.answer_id;
  if (
    typeof submissionId !== "string" ||
    !ID_PATTERN.test(submissionId) ||
    typeof answerId !== "string" ||
    !ID_PATTERN.test(answerId)
  ) {
    return NextResponse.json(
      { error: "Identitas pengajuan atau jawaban tidak valid." },
      { status: 400 },
    );
  }

  const submissionRef = adminDb
    .collection(COLLECTIONS.SUBMISSIONS)
    .doc(submissionId);
  const [submissionSnapshot, answerSnapshot] = await Promise.all([
    submissionRef.get(),
    submissionRef
      .collection(COLLECTIONS.SUBMISSION_ANSWERS)
      .doc(answerId)
      .get(),
  ]);
  if (!submissionSnapshot.exists) {
    return NextResponse.json(
      { error: "Pengajuan tidak ditemukan." },
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
      { error: "Pengajuan ini bukan milik akun atau moda transportasi Anda." },
      { status: 403 },
    );
  }
  if (submission.status !== "draft") {
    return NextResponse.json(
      { error: "Bukti hanya dapat diunggah untuk pengajuan draft." },
      { status: 409 },
    );
  }
  if (!answerSnapshot.exists) {
    return NextResponse.json(
      { error: "Jawaban checklist belum tersimpan." },
      { status: 409 },
    );
  }

  const key = `staging/submissions/${submissionId}/answers/${answerId}/${randomUUID()}.${extension}`;
  return NextResponse.json({
    upload_url: await createUploadUrl(key, {
      contentLength: size,
      contentType,
    }),
    storage_path: storagePath(key),
    required_headers: {
      "Content-Type": contentType,
      "Content-Length": String(size),
    },
  });
}
