import { NextRequest, NextResponse } from "next/server";
import { verifyAuth } from "@/lib/auth";
import { adminDb } from "@/lib/firebase-admin";
import { COLLECTIONS } from "@/lib/constants";
import { getDownloadUrl, parseStoragePath } from "@/lib/r2";

const KEY_PATTERN = /^[A-Za-z0-9_-]+(?:\/[A-Za-z0-9_.-]+)+$/;

export async function POST(request: NextRequest) {
  const authResult = await verifyAuth(request);
  if ("error" in authResult) return authResult.error;

  const body = (await request.json()) as { storage_path?: unknown };
  if (typeof body.storage_path !== "string") {
    return NextResponse.json(
      { error: "Lokasi berkas tidak valid." },
      { status: 400 },
    );
  }
  const key = parseStoragePath(body.storage_path);
  if (!key || !KEY_PATTERN.test(key)) {
    return NextResponse.json(
      { error: "Lokasi berkas tidak valid." },
      { status: 400 },
    );
  }

  const isPrivileged =
    authResult.user.role === "staf_bbkk" ||
    authResult.user.role === "validator_admin";
  const signatureMatch = key.match(/^signatures\/([A-Za-z0-9_-]+)\/signature\.png$/);
  if (signatureMatch) {
    if (!isPrivileged && signatureMatch[1] !== authResult.user.uid) {
      return NextResponse.json(
        { error: "Anda tidak dapat mengakses tanda tangan akun lain." },
        { status: 403 },
      );
    }
    const signatureOwner = await adminDb
      .collection(COLLECTIONS.USERS)
      .doc(signatureMatch[1])
      .get();
    if (signatureOwner.data()?.signature_url !== body.storage_path) {
      return NextResponse.json(
        { error: "Tanda tangan tidak ditemukan." },
        { status: 404 },
      );
    }
  } else {
    const documentMatch = key.match(
      /^documents\/([A-Za-z0-9_-]+)\/[A-Za-z0-9_.-]+$/,
    );
    if (documentMatch) {
      if (
        authResult.user.role !== "validator_admin" &&
        authResult.user.role !== "staf_bbkk"
      ) {
        return NextResponse.json(
          { error: "Anda tidak dapat mengakses dokumen hasil ini." },
          { status: 403 },
        );
      }
      const result = await adminDb
        .collection(COLLECTIONS.DOKUMEN_HASIL)
        .where("submission_id", "==", documentMatch[1])
        .limit(1)
        .get();
      if (
        result.empty ||
        result.docs[0].data().file_pdf_url !== body.storage_path ||
        result.docs[0].data().status !== "final"
      ) {
        return NextResponse.json(
          { error: "Dokumen hasil tidak ditemukan." },
          { status: 404 },
        );
      }
      return NextResponse.json({ download_url: await getDownloadUrl(key) });
    }

    const evidenceMatch = key.match(
      /^submissions\/([A-Za-z0-9_-]+)\/answers\/([A-Za-z0-9_-]+)\/[A-Za-z0-9_.-]+$/,
    );
    if (!evidenceMatch) {
      return NextResponse.json(
        { error: "Lokasi berkas tidak valid." },
        { status: 400 },
      );
    }

    const submission = await adminDb
      .collection(COLLECTIONS.SUBMISSIONS)
      .doc(evidenceMatch[1])
      .get();
    if (!submission.exists) {
      return NextResponse.json(
        { error: "Pengajuan tidak ditemukan." },
        { status: 404 },
      );
    }
    if (!isPrivileged && submission.data()?.pengisi_id !== authResult.user.uid) {
      return NextResponse.json(
        { error: "Anda tidak dapat mengakses bukti pengajuan ini." },
        { status: 403 },
      );
    }
    const media = await adminDb
      .collection(COLLECTIONS.SUBMISSIONS)
      .doc(evidenceMatch[1])
      .collection(COLLECTIONS.SUBMISSION_ANSWERS)
      .doc(evidenceMatch[2])
      .collection(COLLECTIONS.SUBMISSION_ANSWER_MEDIA)
      .where("file_url", "==", body.storage_path)
      .limit(1)
      .get();
    if (media.empty) {
      return NextResponse.json(
        { error: "Bukti tidak ditemukan pada pengajuan ini." },
        { status: 404 },
      );
    }
  }

  return NextResponse.json({ download_url: await getDownloadUrl(key) });
}
