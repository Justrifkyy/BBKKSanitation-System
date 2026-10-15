import { initializeApp, getApps, getApp, cert, type ServiceAccount } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

function sanitizeEnv(val: string | undefined): string | undefined {
  if (!val) return undefined;
  let cleaned = val.trim();
  if (
    (cleaned.startsWith('"') && cleaned.endsWith('"')) ||
    (cleaned.startsWith("'") && cleaned.endsWith("'"))
  ) {
    cleaned = cleaned.slice(1, -1).trim();
  }
  return cleaned;
}

function sanitizePrivateKey(key: string | undefined): string | undefined {
  const cleaned = sanitizeEnv(key);
  if (!cleaned) return undefined;
  return cleaned.replace(/\\n/g, '\n');
}

const serviceAccount: ServiceAccount = {
  projectId: sanitizeEnv(process.env.FIREBASE_PROJECT_ID),
  clientEmail: sanitizeEnv(process.env.FIREBASE_CLIENT_EMAIL),
  privateKey: sanitizePrivateKey(process.env.FIREBASE_PRIVATE_KEY),
};

// Initialize Firebase Admin (singleton)
const adminApp =
  getApps().length === 0
    ? initializeApp({
      credential: cert(serviceAccount),
      storageBucket: `${serviceAccount.projectId}.firebasestorage.app`,
    })
    : getApp();

export const adminAuth = getAuth(adminApp);
export const adminDb = getFirestore(
  adminApp,
  sanitizeEnv(process.env.FIRESTORE_DATABASE_ID) || 'bbkkmakassar',
);

