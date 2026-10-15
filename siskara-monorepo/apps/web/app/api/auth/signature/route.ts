import { verifyAuth } from "@/lib/auth";
import { adminDb } from "@/lib/firebase-admin";
import { COLLECTIONS } from "@/lib/constants";
import { NextRequest, NextResponse } from "next/server";
import {
  deleteObject,
  headObject,
  isR2Configured,
  parseStoragePath,
  promoteObject,
  readObjectBytes,
  storagePath,
} from "@/lib/r2";

function isValidSignatureSvg(bytes: Uint8Array): boolean {
  let content: string;
  try {
    content = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    return false;
  }

  const svg = content
    .replace(/^\uFEFF/, "")
    .replace(/^<\?xml[^>]*>\s*/i, "")
    .trim();
  return (
    /^<svg(?:\s|>)[\s\S]*<\/svg>$/i.test(svg) &&
    !/<!DOCTYPE|<!ENTITY|<\s*(?:script|style|foreignObject|iframe|object|embed|image)\b|\bon[a-z]+\s*=|\b(?:href|xlink:href)\s*=|url\s*\(|javascript:/i.test(
      svg,
    )
  );
}

export async function POST(request: NextRequest) {
  const authResult = await verifyAuth(request, [
    "kepala_kapal",
    "kepala_penerbangan",
    "staf_bbkk",
  ]);
  if ("error" in authResult) return authResult.error;
  if (!isR2Configured()) {
    return NextResponse.json(
      { error: "Penyimpanan tanda tangan belum dikonfigurasi di server." },
      { status: 503 },
    );
  }

  const body = (await request.json()) as { signature_url?: unknown };
  if (typeof body.signature_url !== "string") {
    return NextResponse.json(
      { error: "Tautan tanda tangan tidak valid." },
      { status: 400 },
    );
  }

  const filePath = parseStoragePath(body.signature_url);
  const uploadMatch = filePath?.match(
    /^staging\/signatures\/([A-Za-z0-9_-]+)\/([0-9a-f-]{36})\.(png|svg)$/i,
  );
  if (!filePath || !uploadMatch || uploadMatch[1] !== authResult.user.uid) {
    return NextResponse.json(
      { error: "Lokasi tanda tangan tidak sesuai dengan akun ini." },
      { status: 400 },
    );
  }

  const extension = uploadMatch[3].toLowerCase();
  const expectedContentType =
    extension === "png" ? "image/png" : "image/svg+xml";
  const [uploadedObject, uploadedBytes] = await Promise.all([
    headObject(filePath),
    readObjectBytes(filePath),
  ]);
  const hasValidContent =
    extension === "png"
      ? uploadedBytes != null &&
        uploadedBytes.length >= 8 &&
        Buffer.from(uploadedBytes.subarray(0, 8)).equals(
          Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        )
      : uploadedBytes != null && isValidSignatureSvg(uploadedBytes);
  if (
    !uploadedObject ||
    uploadedObject.ContentType !== expectedContentType ||
    (uploadedObject.ContentLength ?? 0) <= 0 ||
    (uploadedObject.ContentLength ?? Infinity) > 512 * 1024 ||
    !hasValidContent
  ) {
    return NextResponse.json(
      { error: "Berkas tanda tangan belum diunggah atau tidak valid." },
      { status: 400 },
    );
  }

  const userRef = adminDb.collection(COLLECTIONS.USERS).doc(authResult.user.uid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    return NextResponse.json(
      { error: "Profil pengguna tidak ditemukan." },
      { status: 404 },
    );
  }
  const permanentKey = `signatures/${authResult.user.uid}/${uploadMatch[2]}.${extension}`;
  await promoteObject(filePath, permanentKey);
  const signatureUrl = storagePath(permanentKey);
  const auditRef = adminDb.collection(COLLECTIONS.AUDIT_LOG).doc();
  let previousSignature: unknown;
  try {
    await adminDb.runTransaction(async (transaction) => {
      const currentUser = await transaction.get(userRef);
      if (!currentUser.exists) {
        throw new Error("SIGNATURE_PROFILE_NOT_FOUND");
      }
      previousSignature = currentUser.data()?.signature_url;
      transaction.update(userRef, { signature_url: signatureUrl });
      transaction.set(auditRef, {
        user_id: authResult.user.uid,
        aksi:
          typeof previousSignature === "string" && previousSignature.length > 0
            ? "update_signature"
            : "save_signature",
        entitas_terkait: `users/${authResult.user.uid}`,
        waktu: new Date(),
      });
    });
  } catch (error) {
    await deleteObject(permanentKey);
    if (
      error instanceof Error &&
      error.message === "SIGNATURE_PROFILE_NOT_FOUND"
    ) {
      return NextResponse.json(
        { error: "Profil pengguna tidak ditemukan." },
        { status: 404 },
      );
    }
    throw error;
  }

  const previousPath =
    typeof previousSignature === "string"
      ? parseStoragePath(previousSignature)
      : null;
  const previousParts = previousPath?.split("/") ?? [];
  const previousIsOwnedSignature =
    previousParts.length === 3 &&
    previousParts[0] === "signatures" &&
    previousParts[1] === authResult.user.uid &&
    /^(?:signature\.png|[0-9a-f-]{36}\.(?:png|svg))$/i.test(
      previousParts[2],
    );
  if (
    previousPath !== null &&
    previousIsOwnedSignature &&
    previousPath !== permanentKey
  ) {
    try {
      await deleteObject(previousPath);
    } catch (error) {
      console.error("Unable to remove replaced signature from R2.", error);
    }
  }

  return NextResponse.json({ success: true });
}
