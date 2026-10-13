import { verifyAuth } from "@/lib/auth";
import { hashPin, isValidPin } from "@/lib/pin";
import { adminDb } from "@/lib/firebase-admin";
import { COLLECTIONS } from "@/lib/constants";
import { NextRequest, NextResponse } from "next/server";

export async function POST(request: NextRequest) {
  const authResult = await verifyAuth(request, [
    "kepala_kapal",
    "kepala_penerbangan",
    "staf_bbkk",
  ]);
  if ("error" in authResult) return authResult.error;

  const body = (await request.json()) as { pin?: unknown };
  if (!isValidPin(body.pin)) {
    return NextResponse.json(
      { error: "PIN harus terdiri dari 6 angka." },
      { status: 400 },
    );
  }

  const userRef = adminDb.collection(COLLECTIONS.USERS).doc(authResult.user.uid);
  const pinHash = await hashPin(body.pin);
  const securityRef = adminDb.collection("user_security").doc(authResult.user.uid);
  const auditRef = adminDb.collection(COLLECTIONS.AUDIT_LOG).doc();
  let pinWasAlreadySet = false;
  const userWasMissing = await adminDb.runTransaction(async (transaction) => {
    const [userDoc, securityDoc] = await Promise.all([
      transaction.get(userRef),
      transaction.get(securityRef),
    ]);
    if (!userDoc.exists) return true;
    if (userDoc.data()?.has_pin === true || securityDoc.exists) {
      pinWasAlreadySet = true;
      return false;
    }
    const now = new Date();
    transaction.create(securityRef, {
      pin_hash: pinHash,
      created_at: now,
      failed_attempts: 0,
      locked_until: null,
    });
    transaction.update(userRef, { has_pin: true });
    transaction.create(auditRef, {
      user_id: authResult.user.uid,
      aksi: "set_pin",
      entitas_terkait: `users/${authResult.user.uid}`,
      waktu: now,
    });
    return false;
  });

  if (userWasMissing) {
    return NextResponse.json(
      { error: "Profil pengguna tidak ditemukan." },
      { status: 404 },
    );
  }
  if (pinWasAlreadySet) {
    return NextResponse.json(
      { error: "PIN sudah diatur dan tidak dapat diubah dari proses pendaftaran." },
      { status: 409 },
    );
  }

  return NextResponse.json({ success: true });
}
