import { initializeApp, getApps, getApp, cert, type App, type ServiceAccount } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';

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
  if (!key) return undefined;
  let cleaned = key.trim();
  if (
    (cleaned.startsWith('"') && cleaned.endsWith('"')) ||
    (cleaned.startsWith("'") && cleaned.endsWith("'"))
  ) {
    cleaned = cleaned.slice(1, -1).trim();
  }
  return cleaned.replace(/\\n/g, '\n');
}

export function isFirebaseAdminConfigured(): boolean {
  const projectId = sanitizeEnv(process.env.FIREBASE_PROJECT_ID);
  const clientEmail = sanitizeEnv(process.env.FIREBASE_CLIENT_EMAIL);
  const privateKey = sanitizePrivateKey(process.env.FIREBASE_PRIVATE_KEY);
  return Boolean(projectId && clientEmail && privateKey);
}

export function getAdminApp(): App {
  if (getApps().length > 0) {
    return getApp();
  }

  const projectId = sanitizeEnv(process.env.FIREBASE_PROJECT_ID);
  const clientEmail = sanitizeEnv(process.env.FIREBASE_CLIENT_EMAIL);
  const privateKey = sanitizePrivateKey(process.env.FIREBASE_PRIVATE_KEY);

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error(
      `Firebase Admin credentials incomplete on server. ` +
      `projectId: ${Boolean(projectId)}, clientEmail: ${Boolean(clientEmail)}, privateKey: ${Boolean(privateKey)}. ` +
      `Pastikan variabel FIREBASE_* diatur di Vercel Environment Variables.`
    );
  }

  const serviceAccount: ServiceAccount = {
    projectId,
    clientEmail,
    privateKey,
  };

  return initializeApp({
    credential: cert(serviceAccount),
    storageBucket: `${projectId}.firebasestorage.app`,
  });
}

export const adminAuth = new Proxy({} as Auth, {
  get(_, prop: string | symbol) {
    const auth = getAuth(getAdminApp());
    const val = (auth as unknown as Record<string | symbol, unknown>)[prop];
    return typeof val === 'function' ? val.bind(auth) : val;
  },
});

export const adminDb = new Proxy({} as Firestore, {
  get(_, prop: string | symbol) {
    const databaseId = sanitizeEnv(process.env.FIRESTORE_DATABASE_ID) || 'bbkkmakassar';
    const db = getFirestore(getAdminApp(), databaseId);
    const val = (db as unknown as Record<string | symbol, unknown>)[prop];
    return typeof val === 'function' ? val.bind(db) : val;
  },
});
