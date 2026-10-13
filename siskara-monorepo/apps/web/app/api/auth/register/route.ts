import { adminAuth, adminDb } from "@/lib/firebase-admin";
import { COLLECTIONS } from "@/lib/constants";
import { NextRequest, NextResponse } from "next/server";

const SELF_REGISTERED_ROLES = ["kepala_kapal", "kepala_penerbangan"] as const;

export async function POST(request: NextRequest) {
  const body = (await request.json()) as Record<string, unknown>;
  const { email, password, nama, phone, role, id_number } = body;

  if (
    typeof email !== "string" ||
    typeof password !== "string" ||
    typeof nama !== "string" ||
    typeof phone !== "string" ||
    typeof role !== "string" ||
    !email.trim() ||
    !nama.trim() ||
    !phone.trim()
  ) {
    return NextResponse.json(
      { error: "Nama, email, kata sandi, nomor telepon, dan peran wajib diisi." },
      { status: 400 },
    );
  }

  if (password.length < 8) {
    return NextResponse.json(
      { error: "Kata sandi harus terdiri dari minimal 8 karakter." },
      { status: 400 },
    );
  }

  if (!(SELF_REGISTERED_ROLES as readonly string[]).includes(role)) {
    return NextResponse.json(
      { error: "Pendaftaran mandiri hanya tersedia untuk Nahkoda dan Pilot." },
      { status: 400 },
    );
  }

  let userRecord;
  try {
    userRecord = await adminAuth.createUser({
      email: email.trim(),
      password,
      displayName: nama.trim(),
    });
  } catch (error) {
    const code =
      typeof error === "object" && error !== null && "code" in error
        ? error.code
        : undefined;

    if (code === "auth/email-already-exists") {
      return NextResponse.json(
        { error: "Email sudah terdaftar. Silakan masuk dengan akun Anda." },
        { status: 409 },
      );
    }

    if (code === "auth/invalid-email") {
      return NextResponse.json(
        { error: "Format email tidak valid." },
        { status: 400 },
      );
    }

    if (code === "auth/weak-password") {
      return NextResponse.json(
        { error: "Kata sandi terlalu lemah." },
        { status: 400 },
      );
    }

    throw error;
  }

  try {
    await adminAuth.setCustomUserClaims(userRecord.uid, { role });
    await adminDb.collection(COLLECTIONS.USERS).doc(userRecord.uid).set({
      nama: nama.trim(),
      role,
      role_id: role,
      phone: phone.trim(),
      id_number: typeof id_number === "string" && id_number.trim() ? id_number.trim() : null,
      signature_url: null,
      has_pin: false,
      dibuat_oleh: null,
      created_at: new Date(),
    });
    await adminDb.collection(COLLECTIONS.AUDIT_LOG).add({
      user_id: userRecord.uid,
      aksi: "self_register",
      entitas_terkait: `users/${userRecord.uid}`,
      waktu: new Date(),
    });

    return NextResponse.json({ id: userRecord.uid }, { status: 201 });
  } catch (error) {
    try {
      await adminAuth.deleteUser(userRecord.uid);
    } catch (cleanupError) {
      console.error("Unable to roll back incomplete self-registration", cleanupError);
    }
    throw error;
  }
}
