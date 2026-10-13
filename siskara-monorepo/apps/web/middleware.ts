import { NextRequest, NextResponse } from 'next/server';
import { verifyAuth } from '@/lib/auth';
import { NextResponse as NR } from 'next/server';
import { cookies } from 'next/headers';

/**
 * Next.js Middleware
 * Protects all routes under /dashboard — requires authenticated session.
 * API routes use their own auth (Firebase ID token in Authorization header).
 */
export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Skip API routes (they handle their own auth via verifyAuth)
  if (pathname.startsWith('/api')) {
    return NR.next();
  }

  // Skip public routes
  if (
    pathname === '/login' ||
    pathname === '/' ||
    pathname.startsWith('/_next') ||
    pathname.startsWith('/favicon')
  ) {
    return NR.next();
  }

  // For dashboard routes, check for session cookie
  const cookieStore = await cookies();
  const sessionCookie = cookieStore.get('session');

  if (!sessionCookie) {
    return NR.redirect(new URL('/login', request.url));
  }

  return NR.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
