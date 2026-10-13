import { NextRequest, NextResponse } from 'next/server';
import { adminAuth } from './firebase-admin';

export type UserRole = 'kepala_kapal' | 'kepala_penerbangan' | 'staf_bbkk' | 'validator_admin';

export interface AuthenticatedUser {
  uid: string;
  role: UserRole;
  email?: string;
}

/**
 * Verify Firebase ID token from the Authorization header and check role.
 * Every API route MUST call this before executing any logic.
 */
export async function verifyAuth(
  request: NextRequest,
  allowedRoles?: UserRole[]
): Promise<{ user: AuthenticatedUser } | { error: NextResponse }> {
  const authHeader = request.headers.get('Authorization');

  if (!authHeader?.startsWith('Bearer ')) {
    return {
      error: NextResponse.json(
        { error: 'Missing or invalid Authorization header' },
        { status: 401 }
      ),
    };
  }

  const token = authHeader.slice(7);

  try {
    const decodedToken = await adminAuth.verifyIdToken(token);
    const role = decodedToken.role as UserRole | undefined;

    if (!role) {
      return {
        error: NextResponse.json(
          { error: 'User has no assigned role' },
          { status: 403 }
        ),
      };
    }

    if (allowedRoles && !allowedRoles.includes(role)) {
      return {
        error: NextResponse.json(
          { error: `Role '${role}' is not authorized for this action` },
          { status: 403 }
        ),
      };
    }

    return {
      user: {
        uid: decodedToken.uid,
        role,
        email: decodedToken.email,
      },
    };
  } catch {
    return {
      error: NextResponse.json(
        { error: 'Invalid or expired token' },
        { status: 401 }
      ),
    };
  }
}
