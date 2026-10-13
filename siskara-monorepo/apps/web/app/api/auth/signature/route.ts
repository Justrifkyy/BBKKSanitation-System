import { verifyAuth } from "@/lib/auth";
import { adminDb, adminStorage } from "@/lib/firebase-admin";
import { COLLECTIONS } from "@/lib/constants";
import { NextRequest, NextResponse } from "next/server";

export async function POST(request: NextRequest) {
  const authResult = await verifyAuth(request, [
    "kepala_kapal",
    "kepala_penerbangan",
    "staf_bbkk",
  ]);
  if ("error" in authResult) return authResult.error;

  const body = (await request.json()) as { signature_url?: unknown };
  if (typeof body.signature_url !== "string") {
    return NextResponse.json(
      { error: "Tautan tanda tangan tidak valid." },
      { status: 400 },
    );
  }

  let signatureUrl: URL;
  try {
    signatureUrl = new URL(body.signature_url);
  } catch {
    return NextResponse.json(
      { error: "Tautan tanda tangan tidak valid." },
      { status: 400 },
    );
  }

  const filePath = `signatures/${authResult.user.uid}/signature.png`;
  const expectedPath = `/v0/b/${adminStorage.bucket().name}/o/${encodeURIComponent(filePath)}`;
  if (
    signatureUrl.protocol !== "https:" ||
    signatureUrl.hostname !== "firebasestorage.googleapis.com" ||
    signatureUrl.pathname !== expectedPath
  ) {
    return NextResponse.json(
      { error: "Tanda tangan harus berasal dari penyimpanan akun ini." },
      { status: 400 },
    );
  }

  const [fileExists] = await adminStorage.bucket().file(filePath).exists();
  if (!fileExists) {
    return NextResponse.json(
      { error: "Berkas tanda tangan belum diunggah." },
      { status: 404 },
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
  const currentSignature = userDoc.data()?.signature_url;
  if (typeof currentSignature === "string" && currentSignature.length > 0) {
    return NextResponse.json(
      { error: "Tanda tangan sudah disimpan dan tidak dapat diganti." },
      { status: 409 },
    );
  }

  await userRef.update({ signature_url: body.signature_url });
  await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
    user_id: authResult.user.uid,
    aksi: "save_signature",
    entitas_terkait: `users/${authResult.user.uid}`,
    waktu: new Date(),
  });

  return NextResponse.json({ success: true });
}
