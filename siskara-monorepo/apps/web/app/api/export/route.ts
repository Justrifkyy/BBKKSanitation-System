import { NextRequest, NextResponse } from 'next/server';
import ExcelJS from 'exceljs';
import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';
import { verifyAuth } from '@/lib/auth';
import { adminDb } from '@/lib/firebase-admin';
import { COLLECTIONS } from '@/lib/constants';

function csvValue(value: unknown): string {
  let text = value === null || value === undefined ? '' : String(value);
  if (/^[\s]*[=+\-@]/.test(text)) text = `'${text}`;
  return `"${text.replaceAll('"', '""')}"`;
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (value && typeof value === 'object' && 'toDate' in value &&
    typeof value.toDate === 'function') return value.toDate();
  return null;
}

function displayName(submission: FirebaseFirestore.DocumentData) {
  const data = submission.data_umum ?? {};
  return submission.moda_transportasi === 'kapal'
    ? data.nama_kapal ?? ''
    : data.nomor_penerbangan ?? '';
}

function statusText(status: unknown) {
  const labels: Record<string, string> = {
    draft: 'Draft',
    ditolak_otomatis: 'Ditolak otomatis',
    menunggu_verifikasi_staf: 'Menunggu verifikasi staf',
    ditolak_staf: 'Ditolak staf',
    final: 'Final',
  };
  return typeof status === 'string' ? labels[status] ?? status : '';
}

export async function GET(request: NextRequest) {
  const authResult = await verifyAuth(request, ['validator_admin']);
  if ('error' in authResult) return authResult.error;
  const { searchParams } = new URL(request.url);
  const mode = searchParams.get('moda');
  const status = searchParams.get('status');
  const start = searchParams.get('dari');
  const end = searchParams.get('sampai');
  const format = searchParams.get('format') ?? 'xlsx';

  if (mode && !['kapal', 'pesawat'].includes(mode)) {
    return NextResponse.json({ error: 'Filter moda tidak valid.' }, { status: 400 });
  }
  if (status && !['draft', 'ditolak_otomatis', 'menunggu_verifikasi_staf', 'ditolak_staf', 'final'].includes(status)) {
    return NextResponse.json({ error: 'Filter status tidak valid.' }, { status: 400 });
  }
  const startDate = start ? new Date(`${start}T00:00:00.000Z`) : null;
  const endDate = end ? new Date(`${end}T23:59:59.999Z`) : null;
  if ((start && (!startDate || Number.isNaN(startDate.getTime()))) ||
    (end && (!endDate || Number.isNaN(endDate.getTime()))) ||
    (startDate && endDate && startDate > endDate)) {
    return NextResponse.json({ error: 'Rentang tanggal tidak valid.' }, { status: 400 });
  }
  if (!['xlsx', 'csv', 'pdf'].includes(format)) {
    return NextResponse.json({ error: 'Format ekspor tidak didukung.' }, { status: 400 });
  }

  const snapshot = await adminDb.collection(COLLECTIONS.SUBMISSIONS)
    .orderBy('created_at', 'desc')
    .limit(5000)
    .get();
  const rows = snapshot.docs.filter((doc) => {
    const item = doc.data();
    const created = dateValue(item.created_at);
    return (!mode || item.moda_transportasi === mode) &&
      (!status || item.status === status) &&
      (!startDate || (created !== null && created >= startDate)) &&
      (!endDate || (created !== null && created <= endDate));
  }).map((doc) => {
    const item = doc.data();
    const data = item.data_umum ?? {};
    const date = dateValue(item.created_at);
    return [
      doc.id,
      item.moda_transportasi === 'kapal' ? 'Kapal' : 'Pesawat',
      displayName(item),
      item.moda_transportasi === 'kapal' ? data.pelabuhan_asal ?? '' : data.berangkat_dari ?? '',
      date ? date.toISOString() : '',
      statusText(item.status),
    ];
  });
  const headers = ['ID Pengajuan', 'Moda', 'Nama kapal / No. penerbangan', 'Asal', 'Tanggal dibuat', 'Status'];
  const filename = `arjuna-pengajuan-${new Date().toISOString().slice(0, 10)}`;

  if (format === 'csv') {
    const content = `\uFEFF${[headers, ...rows].map((row) => row.map(csvValue).join(',')).join('\r\n')}`;
    return new NextResponse(content, {
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="${filename}.csv"`,
      },
    });
  }
  if (format === 'pdf') {
    const pdf = await PDFDocument.create();
    const font = await pdf.embedFont(StandardFonts.Helvetica);
    const bold = await pdf.embedFont(StandardFonts.HelveticaBold);
    let page = pdf.addPage([842, 595]);
    const margin = 36;
    const widths = [150, 55, 190, 125, 130, 90];
    const rowHeight = 24;
    const drawHeader = (y: number) => {
      page.drawText('Laporan Pengajuan ARJUNA', { x: margin, y: 555, size: 16, font: bold, color: rgb(0.08, 0.29, 0.31) });
      page.drawText(`Data: ${rows.length} pengajuan (maksimal 5.000 baris)`, { x: margin, y: 536, size: 9, font });
      let x = margin;
      headers.forEach((header, index) => {
        page.drawText(header.slice(0, 25), { x: x + 4, y: y - 15, size: 7, font: bold });
        x += widths[index];
      });
      page.drawLine({ start: { x: margin, y: y - 20 }, end: { x: 806, y: y - 20 }, thickness: 0.7, color: rgb(0.75, 0.81, 0.81) });
    };
    let y = 510;
    drawHeader(y);
    y -= 34;
    for (const row of rows) {
      if (y < 36) {
        page = pdf.addPage([842, 595]);
        y = 555;
        drawHeader(y);
        y -= 34;
      }
      let x = margin;
      row.forEach((cell, index) => {
        page.drawText(String(cell).replace(/[^\x20-\x7E]/g, ' ').slice(0, index === 2 ? 32 : 24), {
          x: x + 4,
          y,
          size: 7,
          font,
          maxWidth: widths[index] - 8,
        });
        x += widths[index];
      });
      page.drawLine({ start: { x: margin, y: y - 7 }, end: { x: 806, y: y - 7 }, thickness: 0.3, color: rgb(0.9, 0.92, 0.92) });
      y -= rowHeight;
    }
    const bytes = await pdf.save();
    return new NextResponse(Buffer.from(bytes), {
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': `attachment; filename="${filename}.pdf"`,
      },
    });
  }

  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Pengajuan');
  sheet.addRow(headers);
  rows.forEach((row) => sheet.addRow(row));
  sheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };
  sheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF137C78' } };
  sheet.columns = [
    { width: 30 }, { width: 14 }, { width: 34 }, { width: 25 }, { width: 25 }, { width: 28 },
  ];
  const bytes = await workbook.xlsx.writeBuffer();
  return new NextResponse(Buffer.from(bytes), {
    headers: {
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="${filename}.xlsx"`,
    },
  });
}
