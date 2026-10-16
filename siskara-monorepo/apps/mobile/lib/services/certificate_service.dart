import 'dart:io';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/checklist_template_model.dart';
import '../models/submission_model.dart';

class CertificateService {
  factory CertificateService() => _instance;
  CertificateService._internal();
  static final CertificateService _instance = CertificateService._internal();

  /// Generates the official A4 Certificate PDF and returns the file bytes.
  Future<Uint8List> generateCertificatePdf({
    required SubmissionModel submission,
    required List<SubmissionAnswerModel> answers,
    required Map<String, ChecklistTemplateItemModel> items,
    String? pengisiNama,
    String? verifikatorNama,
    DateTime? verifiedAt,
  }) async {
    final pdf = pw.Document();

    // Load BBKK Logo from assets
    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load('assets/images/logo_bbkk.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {
      // Fallback if asset cannot be loaded
    }

    final isKapal = submission.isKapal;
    final now = verifiedAt ?? submission.updatedAt;
    const bulanIndo = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final tanggalStr = '${now.day} ${bulanIndo[now.month]} ${now.year}';
    final waktuStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final docNumber = isKapal
        ? 'BBKK.MKS/PHQC/${submission.id.length >= 8 ? submission.id.substring(0, 8).toUpperCase() : submission.id.toUpperCase()}/${now.year}'
        : 'BBKK.MKS/ASIC/${submission.id.length >= 8 ? submission.id.substring(0, 8).toUpperCase() : submission.id.toUpperCase()}/${now.year}';

    final dataUmum = submission.dataUmum;
    final namaSarana = isKapal
        ? (dataUmum['nama_kapal']?.toString() ?? 'KAPAL LAUT')
        : (dataUmum['nomor_penerbangan']?.toString() ?? 'PESAWAT UDARA');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        footer: (context) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Dokumen sah diterbitkan secara elektronik oleh Balai Besar Kekarantinaan Kesehatan Makassar (ARJUNA System)',
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Hal. ${context.pageNumber} dari ${context.pagesCount} (Format A4)',
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
        build: (context) => [
          // ─── KOP SURAT RESMI BBKK ──────────────────────────────
          pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoBytes != null)
                    pw.Container(
                      width: 58,
                      height: 58,
                      margin: const pw.EdgeInsets.only(right: 14),
                      child: pw.Image(pw.MemoryImage(logoBytes)),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'KEMENTERIAN KESEHATAN REPUBLIK INDONESIA',
                          style: const pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Text(
                          'DIREKTORAT JENDERAL PENCEGAHAN DAN PENGENDALIAN PENYAKIT',
                          style: const pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          'BALAI BESAR KEKARANTINAAN KESEHATAN MAKASSAR',
                          style: const pw.TextStyle(
                            fontSize: 12.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor(0, 0.33, 0.33),
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          'Wilayah Kerja Pelabuhan Laut & Bandar Udara Internasional',
                          style: const pw.TextStyle(fontSize: 8.5),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Text(
                          'Jl. Nusantara No. 45, Makassar 90173 | Telp: (0411) 3624231 | Email: bbkk.makassar@kemkes.go.id',
                          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.5, color: PdfColors.black),
              pw.SizedBox(height: 1),
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              pw.SizedBox(height: 10),

              // ─── JUDUL DAN NOMOR SURAT ─────────────────────────────
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      isKapal
                          ? 'SURAT KETERANGAN KELAYAKAN SANITASI KAPAL'
                          : 'SURAT KETERANGAN PENGAWASAN SANITASI PESAWAT UDARA',
                      style: const pw.TextStyle(
                        fontSize: 12.5,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.2,
                        decoration: pw.TextDecoration.underline,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      isKapal
                          ? 'SHIP SANITATION HEALTH CLEARANCE CERTIFICATE'
                          : 'AIRCRAFT SANITATION AND HEALTH INSPECTION CLEARANCE',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey800,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Nomor: $docNumber',
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // ─── PERNYATAAN PEMBUKA ─────────────────────────────────
              pw.Text(
                'Menerangkan bahwa sarana transportasi di bawah ini telah dilakukan verifikasi dan pemeriksaan sanitasi kekarantinaan kesehatan secara visual dan teknis melalui Sistem Informasi ARJUNA Balai Besar Kekarantinaan Kesehatan Makassar:',
                style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.2),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 8),

              // ─── TABEL IDENTITAS TRANSPORTASI ───────────────────────
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(4.5),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(4.5),
                },
                children: [
                  if (isKapal) ...[
                    _buildTableRow(
                      'Nama Kapal',
                      namaSarana,
                      'Jenis Kapal',
                      dataUmum['jenis_kapal']?.toString() ?? '-',
                    ),
                    _buildTableRow(
                      'Nomor IMO',
                      dataUmum['nomor_imo']?.toString() ??
                          dataUmum['tanda_panggilan']?.toString() ??
                          '-',
                      'Bendera Kebangsaan',
                      dataUmum['bendera']?.toString() ??
                          dataUmum['kebangsaan_bendera']?.toString() ??
                          '-',
                    ),
                    _buildTableRow(
                      'Tonase Kotor (GRT)',
                      dataUmum['besar_kapal_grt'] != null
                          ? '${dataUmum['besar_kapal_grt']} GRT'
                          : '-',
                      'Pelabuhan Asal',
                      dataUmum['pelabuhan_asal']?.toString() ?? '-',
                    ),
                    _buildTableRow(
                      'Pelabuhan Tujuan',
                      dataUmum['tujuan_pelabuhan_berikutnya']?.toString() ??
                          dataUmum['pelabuhan_tujuan']?.toString() ??
                          '-',
                      'Lokasi Sandar / Labuh',
                      dataUmum['lokasi_sandar']?.toString() ?? '-',
                    ),
                    _buildTableRow(
                      'Waktu Kedatangan',
                      dataUmum['tanggal_jam_tiba']?.toString() ?? '-',
                      'Waktu Keberangkatan',
                      dataUmum['tanggal_jam_berangkat']?.toString() ?? '-',
                    ),
                    _buildTableRow(
                      'Waktu Pemeriksaan',
                      dataUmum['diperiksa_tanggal_jam']?.toString() ?? '-',
                      'Jumlah Awak / Penumpang',
                      '${dataUmum['jumlah_awak_kapal'] ?? dataUmum['jumlah_abk'] ?? '-'} Awak / ${dataUmum['jumlah_penumpang'] ?? '0'} Pnp',
                    ),
                    _buildTableRow(
                      'Pemilik / Agen Kapal',
                      dataUmum['nama_pemilik_agen']?.toString() ?? '-',
                      'Nahkoda / Pemohon',
                      pengisiNama ?? 'Deklaran Terdaftar',
                    ),
                  ] else ...[
                    _buildTableRow(
                      'Nomor Penerbangan',
                      namaSarana,
                      'Penyelenggara / Maskapai',
                      dataUmum['pemilik_atau_penyelenggara']?.toString() ??
                          dataUmum['maskapai']?.toString() ??
                          '-',
                    ),
                    _buildTableRow(
                      'Tanda Kebangsaan & Reg',
                      dataUmum['tanda_kebangsaan_dan_pendaftaran']?.toString() ??
                          dataUmum['tanda_registrasi']?.toString() ??
                          '-',
                      'Rute Penerbangan',
                      '${dataUmum['berangkat_dari'] ?? dataUmum['bandara_asal'] ?? '-'} -> ${dataUmum['tujuan'] ?? dataUmum['bandara_tujuan'] ?? '-'}',
                    ),
                    _buildTableRow(
                      'Waktu Penerbangan',
                      dataUmum['tanggal_jam']?.toString() ??
                          dataUmum['waktu_kedatangan']?.toString() ??
                          '-',
                      'Pilot In Command',
                      pengisiNama ?? 'Deklaran Terdaftar',
                    ),
                    _buildTableRow(
                      'Petugas Validasi BBKK',
                      verifikatorNama ?? 'Staf Sanitasi BBKK',
                      'Status Dokumen',
                      'DITERBITKAN RESMI',
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 10),

              // ─── TABEL EVALUASI AREA SANITASI ──────────────────────
              pw.Text(
                'HASIL EVALUASI PEMERIKSAAN AREA SANITASI:',
                style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(22),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(2.5),
                  3: const pw.FlexColumnWidth(2.2),
                  4: const pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor(0.92, 0.96, 0.96)),
                    children: [
                      _buildHeaderCell('No'),
                      _buildHeaderCell('Area Pemeriksaan'),
                      _buildHeaderCell('Kategori'),
                      _buildHeaderCell('Status Evaluasi'),
                      _buildHeaderCell('Keterangan'),
                    ],
                  ),
                  for (var i = 0; i < answers.length; i++)
                    _buildAnswerRow(
                      index: i + 1,
                      answer: answers[i],
                      item: items[answers[i].templateItemId],
                    ),
                ],
              ),
              pw.SizedBox(height: 9),

              // ─── KESIMPULAN REKOMENDASI ────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: const PdfColor(0.93, 0.98, 0.94),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: const PdfColor(0.2, 0.6, 0.3), width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'KESIMPULAN & REKOMENDASI KARANTINA KESEHATAN:',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor(0.1, 0.45, 0.2),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Berdasarkan hasil pengawasan dokumen foto dan evaluasi checklist karantina kesehatan, sarana transportasi dinyatakan TELAH MEMENUHI PERSYARATAN KELAYAKAN SANITASI (LAIK OPERASIONAL) serta diberikan izin keberangkatan/operasional sesuai standar peraturan perundang-undangan.',
                            style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // ─── PENGESAHAN DUA PIHAK & QR CODE ────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Sisi Deklaran (Nahkoda / Pilot)
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          isKapal ? 'Nahkoda / Pemohon Deklarasi,' : 'Pilot in Command / Pemohon,',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                '[TERVERIFIKASI SISTEM ARJUNA]',
                                style: const pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor(0, 0.4, 0.4)),
                              ),
                              pw.Text(
                                'Ditandatangani secara digital via PIN',
                                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          pengisiNama ?? 'Deklaran Pemohon',
                          style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Text(
                          isKapal ? 'Nahkoda Kapal' : 'Pilot in Command',
                          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),

                  // Sisi Verifikator BBKK Makassar dengan QR Code
                  pw.Container(
                    width: 230,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'Makassar, $tanggalStr $waktuStr WITA',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.Text(
                          'Petugas Karantina Kesehatan BBKK Makassar,',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.SizedBox(height: 6),
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: 'https://www.arjuna-bbkk.site/verify/${submission.id}',
                          width: 52,
                          height: 52,
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          verifikatorNama ?? 'Petugas Validasi Sanitasi BBKK',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Text(
                          'Balai Besar Kekarantinaan Kesehatan Makassar',
                          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

    return pdf.save();
  }

  /// Saves the certificate PDF directly to the device Download folder and opens it.
  Future<File> downloadAndOpenCertificate({
    required SubmissionModel submission,
    required List<SubmissionAnswerModel> answers,
    required Map<String, ChecklistTemplateItemModel> items,
    String? pengisiNama,
    String? verifikatorNama,
    DateTime? verifiedAt,
  }) async {
    final pdfBytes = await generateCertificatePdf(
      submission: submission,
      answers: answers,
      items: items,
      pengisiNama: pengisiNama,
      verifikatorNama: verifikatorNama,
      verifiedAt: verifiedAt,
    );

    Directory? saveDir;
    if (Platform.isAndroid) {
      try {
        final dirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (dirs != null && dirs.isNotEmpty) {
          saveDir = dirs.first;
        }
      } catch (_) {}
      saveDir ??= await getExternalStorageDirectory();
    }
    saveDir ??= await getApplicationDocumentsDirectory();

    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final idShort = submission.id.length >= 8
        ? submission.id.substring(0, 8).toUpperCase()
        : submission.id.toUpperCase();
    final fileName = submission.isKapal
        ? 'SURAT_SANITASI_KAPAL_BBKK_$idShort.pdf'
        : 'SURAT_SANITASI_PESAWAT_BBKK_$idShort.pdf';

    final file = File('${saveDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes, flush: true);

    // Try also copying to public Download directory if accessible on device
    if (Platform.isAndroid) {
      try {
        final publicDownloadDir = Directory('/storage/emulated/0/Download');
        if (await publicDownloadDir.exists()) {
          final publicFile = File('${publicDownloadDir.path}/$fileName');
          await publicFile.writeAsBytes(pdfBytes, flush: true);
        }
      } catch (_) {
        // Scoped storage may restrict direct write, file in saveDir is safe
      }
    }

    // Automatically open with device PDF viewer
    try {
      await OpenFilex.open(file.path);
    } catch (_) {
      // If no default viewer, file is still saved successfully
    }

    return file;
  }

  // ─── HELPER WIDGETS ────────────────────────────────────────────────

  static pw.TableRow _buildTableRow(String label1, String value1, String label2, String value2) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: pw.Text(label1, style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: pw.Text(value1, style: const pw.TextStyle(fontSize: 8)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: pw.Text(label2, style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: pw.Text(value2, style: const pw.TextStyle(fontSize: 8)),
        ),
      ],
    );
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.TableRow _buildAnswerRow({
    required int index,
    required SubmissionAnswerModel answer,
    ChecklistTemplateItemModel? item,
  }) {
    final isLayak = answer.nilaiJawaban == 'layak' || !answer.statusGagal;
    final statusText = isLayak ? 'MEMENUHI SYARAT' : 'TIDAK MEMENUHI SYARAT';
    final statusColor = isLayak ? const PdfColor(0.1, 0.5, 0.2) : PdfColors.red800;

    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text('$index', style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(item?.label ?? answer.templateItemId, style: const pw.TextStyle(fontSize: 7.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(item?.kategori ?? '-', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(
            statusText,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: statusColor),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(answer.alasan ?? 'Kondisi sanitasi terpelihara baik', style: const pw.TextStyle(fontSize: 7)),
        ),
      ],
    );
  }
}
