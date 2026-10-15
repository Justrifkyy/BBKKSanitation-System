import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  return NextResponse.json({
    ok: true,
    url: request.url,
    time: new Date().toISOString(),
  });
}

export async function POST(request: NextRequest) {
  const body = await request.json().catch(() => ({}));
  return NextResponse.json({
    ok: true,
    received: body,
    time: new Date().toISOString(),
  });
}
