import { NextRequest, NextResponse } from 'next/server';

/**
 * Next.js Middleware
 * Protects all routes under /dashboard — requires authenticated session.
 * API routes handle their own auth via verifyAuth (Firebase ID token).
 */
export function middleware(request: NextRequest) {
  const sessionCookie = request.cookies.get('session');

  if (!sessionCookie?.value) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/dashboard/:path*'],
};
