import { adminAuth } from "@/lib/firebase-admin";
import { NextRequest, NextResponse } from "next/server";

const SESSION_DURATION_MS = 5 * 24 * 60 * 60 * 1000;

export async function POST(request: NextRequest) {
  const authorization = request.headers.get("Authorization");

  if (!authorization?.startsWith("Bearer ")) {
    return NextResponse.json(
      { error: "Token autentikasi tidak ditemukan." },
      { status: 401 },
    );
  }

  const idToken = authorization.slice("Bearer ".length);
  let decodedToken;
  try {
    decodedToken = await adminAuth.verifyIdToken(idToken);
  } catch (error) {
    const isFirebaseAuthError =
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      typeof error.code === "string" &&
      error.code.startsWith("auth/");

    if (!isFirebaseAuthError) throw error;

    return NextResponse.json(
      { error: "Token login tidak valid atau sudah kedaluwarsa." },
      { status: 401 },
    );
  }

  if (decodedToken.role !== "validator_admin") {
    return NextResponse.json(
      { error: "Halaman ini hanya dapat diakses oleh Admin." },
      { status: 403 },
    );
  }

  const sessionCookie = await adminAuth.createSessionCookie(idToken, {
    expiresIn: SESSION_DURATION_MS,
  });
  const response = NextResponse.json({ success: true });

  response.cookies.set("session", sessionCookie, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: SESSION_DURATION_MS / 1000,
  });

  return response;
}

export async function DELETE() {
  const response = NextResponse.json({ success: true });

  response.cookies.set("session", "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 0,
  });

  return response;
}
