import { initializeApp, getApps, getApp, cert, type ServiceAccount } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const serviceAccount: ServiceAccount = {
  projectId: process.env.FIREBASE_PROJECT_ID,
  clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
  privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
};

// Initialize Firebase Admin (singleton)
const adminApp =
  getApps().length === 0
    ? initializeApp({
      credential: cert(serviceAccount),
      storageBucket: `${process.env.FIREBASE_PROJECT_ID}.firebasestorage.app`,
    })
    : getApp();

export const adminAuth = getAuth(adminApp);
export const adminDb = getFirestore(
  adminApp,
  process.env.FIRESTORE_DATABASE_ID || 'bbkkmakassar',
);
