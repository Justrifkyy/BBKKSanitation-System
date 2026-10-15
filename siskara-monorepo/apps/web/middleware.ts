import { NextRequest } from 'next/server';
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

  // Skip public routes and static assets (images, icons, etc.)
  if (
    pathname === '/login' ||
    pathname === '/' ||
    pathname.startsWith('/_next') ||
    pathname.startsWith('/favicon') ||
    /\.(?:png|jpg|jpeg|gif|webp|svg|ico|json)$/i.test(pathname)
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
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:png|jpg|jpeg|gif|webp|svg|ico)$).*)'],
};
