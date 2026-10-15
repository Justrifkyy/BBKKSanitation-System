import { NextResponse } from 'next/server';
import { isFirebaseAdminConfigured } from '@/lib/firebase-admin';
import { isR2Configured } from '@/lib/r2';

export async function GET() {
  const envStatus = {
    FIREBASE_PROJECT_ID: Boolean(process.env.FIREBASE_PROJECT_ID),
    FIREBASE_CLIENT_EMAIL: Boolean(process.env.FIREBASE_CLIENT_EMAIL),
    FIREBASE_PRIVATE_KEY: Boolean(process.env.FIREBASE_PRIVATE_KEY),
    FIRESTORE_DATABASE_ID: Boolean(process.env.FIRESTORE_DATABASE_ID),
    R2_ACCOUNT_ID: Boolean(process.env.R2_ACCOUNT_ID),
    R2_BUCKET_NAME: Boolean(process.env.R2_BUCKET_NAME),
    R2_ACCESS_KEY_ID: Boolean(process.env.R2_ACCESS_KEY_ID),
    R2_SECRET_ACCESS_KEY: Boolean(process.env.R2_SECRET_ACCESS_KEY),
    isFirebaseAdminReady: isFirebaseAdminConfigured(),
    isR2Ready: isR2Configured(),
  };

  const allReady = envStatus.isFirebaseAdminReady && envStatus.isR2Ready;

  return NextResponse.json(
    {
      status: allReady ? 'healthy' : 'degraded',
      message: allReady
        ? 'Semua layanan server terkonfigurasi dengan benar.'
        : 'Beberapa variabel lingkungan belum diatur di server hosting (Vercel).',
      env: envStatus,
    },
    { status: allReady ? 200 : 503 }
  );
}
