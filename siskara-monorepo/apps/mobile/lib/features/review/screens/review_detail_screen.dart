import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/error_message.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/interactive_photo_viewer.dart';
import '../../../models/checklist_template_model.dart';
import '../../../models/submission_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/certificate_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../state/auth_state.dart';
import '../../../state/submission_state.dart';

class ReviewDetailScreen extends ConsumerStatefulWidget {
  const ReviewDetailScreen({
    super.key,
    required this.submissionId,
    this.readOnly = false,
  });
  final String submissionId;
  final bool readOnly;

  @override
  ConsumerState<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends ConsumerState<ReviewDetailScreen> {
  late Future<_ReviewData?> _reviewFuture;
  bool _isSavingDecision = false;
  bool _isDownloadingCertificate = false;
  final Map<String, String> _evaluations = {}; // answerId -> 'layak' | 'tidak_layak'
  final Map<String, TextEditingController> _reasonControllers = {};
  bool _hasInitializedEvaluations = false;

  Future<void> _downloadCertificate(_ReviewData review) async {
    setState(() => _isDownloadingCertificate = true);
    try {
      final file = await CertificateService().downloadAndOpenCertificate(
        submission: review.submission,
        answers: review.answers,
        items: review.items,
        pengisiNama: review.pengisiNama,
        verifikatorNama: review.verifikatorNama,
        verifiedAt: review.submission.updatedAt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Surat resmi berhasil diunduh & dibuka:\n${file.path.split('/').last}',
          ),
          backgroundColor: SiskaraTheme.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (error, stack) {
      debugPrint('Certificate download error: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuat surat: ${error is Exception ? error.toString().replaceFirst("Exception: ", "") : ErrorMessage.from(error)}',
          ),
          backgroundColor: SiskaraTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloadingCertificate = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _reviewFuture =
        ref.read(firestoreServiceProvider).loadReviewData(widget.submissionId);
  }

  @override
  void dispose() {
    for (final controller in _reasonControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initEvaluations(_ReviewData review) {
    if (_hasInitializedEvaluations) return;
    _hasInitializedEvaluations = true;

    for (final answer in review.answers) {
      if (answer.nilaiJawaban == 'layak' || answer.nilaiJawaban == 'tidak_layak') {
        _evaluations[answer.id] = answer.nilaiJawaban;
      }
      _reasonControllers[answer.id] = TextEditingController(
        text: answer.alasan ?? '',
      );
    }
  }

  Future<void> _decide(String decision, _ReviewData review) async {
    // If approving, make sure staff has evaluated all checklist items
    if (decision == 'approve') {
      final unEvaluatedCount = review.answers
          .where((a) => !_evaluations.containsKey(a.id))
          .length;

      if (unEvaluatedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Harap nilai semua area pemeriksaan sebelum menyetujui. '
              '(${_evaluations.length}/${review.answers.length} selesai)',
            ),
            backgroundColor: SiskaraTheme.warning,
          ),
        );
        return;
      }

      final tidakLayakCount =
          _evaluations.values.where((v) => v == 'tidak_layak').length;
      if (tidakLayakCount > 0) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Terdapat Temuan Tidak Memenuhi Syarat'),
            content: Text(
              'Ada $tidakLayakCount area pemeriksaan yang Anda nilai "Tidak Memenuhi Syarat". '
              'Pengajuan dengan temuan ini sebaiknya ditolak atau diminta revisi untuk perbaikan oleh Nahkoda/Pilot. '
              'Apakah Anda ingin melanjutkan penetapan Tidak Memenuhi Syarat (Revisi)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: SiskaraTheme.error),
                child: const Text('Lanjutkan Revisi'),
              ),
            ],
          ),
        );
        if (proceed == true) {
          _decide('reject', review);
        }
        return;
      }
    }

    final result = await showDialog<_ReviewDecision>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReviewDecisionDialog(decision: decision),
    );
    if (result == null || !mounted) return;

    setState(() => _isSavingDecision = true);
    try {
      final firestore = ref.read(firestoreServiceProvider);

      // Save staff evaluations for each item to Firestore
      for (final answer in review.answers) {
        final eval = _evaluations[answer.id] ?? 'layak';
        final reason = _reasonControllers[answer.id]?.text.trim() ?? '';
        final templateItem = review.items[answer.templateItemId];
        await firestore.saveAnswerForItem(
          submissionId: widget.submissionId,
          itemId: answer.templateItemId,
          answer: {
            'submission_id': widget.submissionId,
            'template_item_id': answer.templateItemId,
            'kategori': templateItem?.kategori ?? '',
            'label': templateItem?.label ?? '',
            'nilai_jawaban': eval,
            'alasan': reason.isNotEmpty ? reason : null,
            'status_gagal': eval == 'tidak_layak',
          },
        );
      }

      // Verify and sign officially
      await ref.read(authServiceProvider).verifySubmission(
            submissionId: widget.submissionId,
            decision: decision,
            pin: result.pin,
            note: result.note,
          );
      ref.invalidate(pendingSubmissionsProvider);
      ref.invalidate(userSubmissionsProvider);
      if (!mounted) return;
      if (decision == 'approve') {
        setState(() {
          _reviewFuture = ref
              .read(firestoreServiceProvider)
              .loadReviewData(widget.submissionId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pengajuan disetujui (ACC)! Surat Kelayakan Sanitasi resmi telah terbit.',
            ),
            backgroundColor: SiskaraTheme.success,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan ditolak dan catatan telah disimpan.'),
            backgroundColor: SiskaraTheme.warning,
          ),
        );
        context.go('/review');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Keputusan tidak dapat disimpan: ${ErrorMessage.from(error)}',
            ),
            backgroundColor: SiskaraTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingDecision = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isStaff = user?.isStaf == true;
    final canEvaluate = isStaff && !widget.readOnly;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly ? 'Detail pengajuan' : 'Pemeriksaan Sanitasi'),
      ),
      body: FutureBuilder<_ReviewData?>(
        future: _reviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ReviewError(
              message:
                  'Detail pengajuan tidak dapat dimuat: '
                  '${ErrorMessage.from(snapshot.error!)}',
              onRetry: () => setState(() {
                _reviewFuture = ref
                    .read(firestoreServiceProvider)
                    .loadReviewData(widget.submissionId);
              }),
            );
          }
          final review = snapshot.data;
          if (review == null) {
            return const _ReviewError(
              message: 'Pengajuan tidak ditemukan atau tidak dapat diakses.',
            );
          }

          if (canEvaluate) {
            _initEvaluations(review);
          }

          final totalItems = review.answers.length;
          final evaluatedCount = _evaluations.length;
          final tidakLayakCount =
              _evaluations.values.where((v) => v == 'tidak_layak').length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              _SubmissionHeader(submission: review.submission),
              const SizedBox(height: 14),

              // Official Certificate Card when status is final
              if (review.submission.status == 'final') ...[
                _CertificateCard(
                  review: review,
                  onDownload: () => _downloadCertificate(review),
                  isDownloading: _isDownloadingCertificate,
                ),
                const SizedBox(height: 14),
              ],

              // Staff Evaluation Guidance Banner
              if (canEvaluate) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: evaluatedCount == totalItems
                        ? (tidakLayakCount == 0
                            ? SiskaraTheme.success.withValues(alpha: 0.1)
                            : SiskaraTheme.warning.withValues(alpha: 0.12))
                        : SiskaraTheme.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: evaluatedCount == totalItems
                          ? (tidakLayakCount == 0
                              ? SiskaraTheme.success
                              : SiskaraTheme.warning)
                          : SiskaraTheme.primaryBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        evaluatedCount == totalItems
                            ? (tidakLayakCount == 0
                                ? Icons.verified_rounded
                                : Icons.warning_amber_rounded)
                            : Icons.rate_review_outlined,
                        color: evaluatedCount == totalItems
                            ? (tidakLayakCount == 0
                                ? SiskaraTheme.success
                                : SiskaraTheme.warning)
                            : SiskaraTheme.primaryDark,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progres Penilaian: $evaluatedCount dari $totalItems area dinilai',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tidakLayakCount > 0
                                  ? '$tidakLayakCount area dinilai Tidak Layak'
                                  : evaluatedCount == totalItems
                                      ? 'Semua area dinilai Layak'
                                      : 'Periksa foto setiap area lalu tentukan status Layak / Tidak Layak.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: SiskaraTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              _SectionCard(
                title: 'Data umum transportasi',
                icon: Icons.directions_boat_outlined,
                child: Column(
                  children: [
                    for (final entry in review.submission.dataUmum.entries)
                      _DetailRow(
                        label: _displayLabel(entry.key),
                        value: _displayValue(entry.value),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              _SectionCard(
                title: 'Foto Bukti & Penilaian Sanitasi',
                icon: Icons.photo_library_outlined,
                child: review.answers.isEmpty
                    ? const Text('Belum ada data area pemeriksaan.')
                    : Column(
                        children: [
                          for (var index = 0;
                              index < review.answers.length;
                              index++) ...[
                            if (index > 0) const Divider(height: 24),
                            _AnswerDetail(
                              answer: review.answers[index],
                              item: review
                                  .items[review.answers[index].templateItemId],
                              media: review.media[review.answers[index].id] ??
                                  const [],
                              readOnly: !canEvaluate,
                              currentEvaluation:
                                  _evaluations[review.answers[index].id],
                              reasonController:
                                  _reasonControllers[review.answers[index].id],
                              onEvaluate: (status) {
                                setState(() {
                                  _evaluations[review.answers[index].id] =
                                      status;
                                });
                              },
                              onReasonChanged: (reason) {
                                // Controller maintains the text
                              },
                            ),
                          ],
                        ],
                      ),
              ),

              if (widget.readOnly ||
                  review.submission.status != 'menunggu_verifikasi_staf') ...[
                const SizedBox(height: 14),
                const _NoticeCard(
                  icon: Icons.assignment_turned_in_outlined,
                  color: Color(0xFF0D9488),
                  title: 'Wewenang Penilaian Sanitasi',
                  message:
                      'Penetapan Memenuhi Syarat atau Tidak Memenuhi Syarat sepenuhnya dilakukan oleh Staf BBKK berdasarkan evaluasi bukti kondisi di lapangan.',
                ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<_ReviewData?>(
            future: _reviewFuture,
            builder: (context, snapshot) {
              final review = snapshot.data;
              if (review == null) return const SizedBox.shrink();

              if (widget.readOnly || !isStaff) {
                return const SizedBox.shrink();
              }
              if (review.submission.status != 'menunggu_verifikasi_staf') {
                return const SizedBox.shrink();
              }
              return SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: const Border(
                      top: BorderSide(color: SiskaraTheme.divider),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSavingDecision
                              ? null
                              : () => _decide('reject', review),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Tidak Memenuhi Syarat'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SiskaraTheme.error,
                            side: const BorderSide(color: SiskaraTheme.error),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSavingDecision
                              ? null
                              : () => _decide('approve', review),
                          icon: _isSavingDecision
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check, size: 18),
                          label: const Text('Memenuhi Syarat & Terbitkan'),
                          style: FilledButton.styleFrom(
                            backgroundColor: SiskaraTheme.success,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (user != null)
            AppBottomNav(
              user: user,
              location: GoRouterState.of(context).matchedLocation,
            ),
        ],
      ),
    );
  }
}

extension on FirestoreService {
  Future<_ReviewData?> loadReviewData(String submissionId) async {
    final submission = await getSubmission(submissionId);
    if (submission == null) return null;

    final answers = await getSubmissionAnswers(submissionId);
    final items = await getTemplateItems(submission.templateId);
    final mediaEntries = await Future.wait(
      answers.map(
        (answer) async => MapEntry(
          answer.id,
          await getAnswerMedia(submissionId, answer.id),
        ),
      ),
    );

    String? pengisiNama;
    String? verifikatorNama;
    try {
      final auth = AuthService();
      if (submission.pengisiId.isNotEmpty) {
        final p = await auth.getUserProfile(submission.pengisiId);
        pengisiNama = p?.nama;
      }
      if (submission.verifikatorId != null &&
          submission.verifikatorId!.isNotEmpty) {
        final v = await auth.getUserProfile(submission.verifikatorId!);
        verifikatorNama = v?.nama;
      }
    } catch (_) {}

    return _ReviewData(
      submission: submission,
      answers: answers,
      items: {for (final item in items) item.id: item},
      media: Map.fromEntries(mediaEntries),
      pengisiNama: pengisiNama,
      verifikatorNama: verifikatorNama,
    );
  }
}

class _ReviewData {
  const _ReviewData({
    required this.submission,
    required this.answers,
    required this.items,
    required this.media,
    this.pengisiNama,
    this.verifikatorNama,
  });
  final SubmissionModel submission;
  final List<SubmissionAnswerModel> answers;
  final Map<String, ChecklistTemplateItemModel> items;
  final Map<String, List<SubmissionAnswerMediaModel>> media;
  final String? pengisiNama;
  final String? verifikatorNama;
}

class _ReviewDecision {
  const _ReviewDecision(this.pin, this.note);
  final String pin;
  final String? note;
}

class _ReviewDecisionDialog extends StatefulWidget {
  const _ReviewDecisionDialog({required this.decision});
  final String decision;

  @override
  State<_ReviewDecisionDialog> createState() => _ReviewDecisionDialogState();
}

class _ReviewDecisionDialogState extends State<_ReviewDecisionDialog> {
  final _pinController = TextEditingController();
  final _noteController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!RegExp(r'^\d{6}$').hasMatch(_pinController.text)) {
      setState(() => _error = 'PIN harus terdiri dari 6 angka.');
      return;
    }
    if (widget.decision == 'reject' && _noteController.text.trim().isEmpty) {
      setState(() => _error = 'Catatan alasan penolakan wajib diisi.');
      return;
    }
    Navigator.pop(
      context,
      _ReviewDecision(
        _pinController.text,
        _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final approving = widget.decision == 'approve';
    return AlertDialog(
      title: Text(approving
          ? 'Tetapkan Memenuhi Syarat?'
          : 'Tetapkan Tidak Memenuhi Syarat?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approving
                  ? 'Dengan ini Staf BBKK menetapkan sarana telah MEMENUHI SYARAT KELAYAKAN SANITASI. Dokumen resmi akan langsung diterbitkan.'
                  : 'Tuliskan rincian temuan sanitasi yang TIDAK MEMENUHI SYARAT untuk diperbaiki oleh Nahkoda/Pilot.',
            ),
            if (!approving) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Catatan / alasan penolakan *',
                  alignLabelWithHint: true,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _pinController,
              autofocus: approving,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'PIN konfirmasi staf',
                prefixIcon: Icon(Icons.pin_outlined),
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: SiskaraTheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _confirm,
          style: FilledButton.styleFrom(
            backgroundColor: approving ? SiskaraTheme.success : SiskaraTheme.error,
          ),
          child: Text(approving ? 'Konfirmasi & Terbitkan' : 'Simpan Tidak Memenuhi'),
        ),
      ],
    );
  }
}

class _SubmissionHeader extends StatelessWidget {
  const _SubmissionHeader({required this.submission});
  final SubmissionModel submission;

  @override
  Widget build(BuildContext context) {
    final data = submission.dataUmum;
    final title = submission.isKapal
        ? (data['nama_kapal']?.toString() ?? 'Kapal')
        : (data['nomor_penerbangan']?.toString() ?? 'Penerbangan');
    final subtitle = submission.isKapal
        ? 'Bendera: ${data['bendera'] ?? '-'} • Tiba: ${data['tanggal_jam_tiba'] ?? '-'}'
        : 'Rute: ${data['rute'] ?? '-'} • Tiba: ${data['tanggal_jam_tiba'] ?? '-'}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SiskaraTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: SiskaraTheme.primaryDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  submission.isKapal ? 'MODA LAUT' : 'MODA UDARA',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: SiskaraTheme.primaryDark,
                  ),
                ),
              ),
              const Spacer(),
              _StatusChip(status: submission.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: SiskaraTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SiskaraTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: SiskaraTheme.primaryDark),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: SiskaraTheme.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                color: SiskaraTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerDetail extends StatelessWidget {
  const _AnswerDetail({
    required this.answer,
    required this.item,
    required this.media,
    required this.readOnly,
    this.currentEvaluation,
    this.reasonController,
    this.onEvaluate,
    this.onReasonChanged,
  });

  final SubmissionAnswerModel answer;
  final ChecklistTemplateItemModel? item;
  final List<SubmissionAnswerMediaModel> media;
  final bool readOnly;
  final String? currentEvaluation;
  final TextEditingController? reasonController;
  final ValueChanged<String>? onEvaluate;
  final ValueChanged<String>? onReasonChanged;

  @override
  Widget build(BuildContext context) {
    final itemTitle = item?.label ?? answer.templateItemId;
    final itemCategory = item?.kategori ?? 'Pemeriksaan';
    final eval = currentEvaluation ?? answer.nilaiJawaban;
    final isLayak = eval == 'layak';
    final isTidakLayak = eval == 'tidak_layak';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Category
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    itemCategory,
                    style: const TextStyle(color: SiskaraTheme.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(
              status: isLayak
                  ? 'final'
                  : isTidakLayak
                      ? 'ditolak_staf'
                      : 'menunggu_verifikasi_staf',
              customLabel: _answerLabel(eval),
            ),
          ],
        ),

        // Catatan dari Nahkoda/Pilot (jika ada)
        if (answer.alasan != null && answer.alasan!.trim().isNotEmpty && !isTidakLayak) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: SiskaraTheme.backgroundLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Catatan Nahkoda/Pilot: ${answer.alasan}',
              style: const TextStyle(
                color: SiskaraTheme.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ),
        ],

        // Foto Bukti (Bisa Ditekan, Zoom, & Download)
        for (final evidence in media) ...[
          const SizedBox(height: 10),
          if (evidence.tipe == 'foto')
            _EvidenceImage(
              storagePath: evidence.fileUrl,
              title: itemTitle,
              subtitle: itemCategory,
              latitude: evidence.latitude,
              longitude: evidence.longitude,
              timestamp: evidence.timestamp,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SiskaraTheme.backgroundLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Bukti video')),
                  IconButton(
                    tooltip: 'Tampilkan tautan video',
                    onPressed: () async {
                      try {
                        final url = evidence.fileUrl.startsWith('r2://')
                            ? await StorageService()
                                .getDownloadUrl(evidence.fileUrl)
                            : evidence.fileUrl;
                        if (!context.mounted) return;
                        await showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Tautan bukti video'),
                            content: SelectableText(url),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Tutup'),
                              ),
                            ],
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Bukti tidak dapat dibuka: ${ErrorMessage.from(error)}',
                            ),
                            backgroundColor: SiskaraTheme.error,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                  ),
                ],
              ),
            ),
          if (evidence.latitude != null && evidence.longitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Text(
                'GPS: ${evidence.latitude!.toStringAsFixed(5)}, ${evidence.longitude!.toStringAsFixed(5)} • ${evidence.timestamp.toLocal()}',
                style: const TextStyle(
                  color: SiskaraTheme.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ),
        ],

        // Staf BBKK Evaluation Section (Input Layak / Tidak Layak)
        if (!readOnly && onEvaluate != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLayak
                  ? SiskaraTheme.success.withValues(alpha: 0.05)
                  : isTidakLayak
                      ? SiskaraTheme.error.withValues(alpha: 0.05)
                      : SiskaraTheme.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isLayak
                    ? SiskaraTheme.success
                    : isTidakLayak
                        ? SiskaraTheme.error
                        : SiskaraTheme.divider,
                width: isLayak || isTidakLayak ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Penilaian Staf BBKK: *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (currentEvaluation != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isLayak
                              ? SiskaraTheme.success
                              : SiskaraTheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isLayak ? 'MEMENUHI SYARAT' : 'TIDAK MEMENUHI SYARAT',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onEvaluate!('layak'),
                        icon: Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: isLayak ? Colors.white : SiskaraTheme.success,
                        ),
                        label: const Text('Memenuhi Syarat'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              isLayak ? SiskaraTheme.success : null,
                          foregroundColor:
                              isLayak ? Colors.white : SiskaraTheme.success,
                          side: const BorderSide(color: SiskaraTheme.success),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onEvaluate!('tidak_layak'),
                        icon: Icon(
                          Icons.cancel_outlined,
                          size: 16,
                          color: isTidakLayak ? Colors.white : SiskaraTheme.error,
                        ),
                        label: const Text('Tidak Memenuhi Syarat'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              isTidakLayak ? SiskaraTheme.error : null,
                          foregroundColor:
                              isTidakLayak ? Colors.white : SiskaraTheme.error,
                          side: const BorderSide(color: SiskaraTheme.error),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isTidakLayak) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    onChanged: onReasonChanged,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Temuan Tidak Memenuhi Syarat *',
                      hintText: 'Jelaskan temuan kondisi sanitasi pada area ini',
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ],
              ],
            ),
          ),
        ] else if (isTidakLayak && answer.alasan != null && answer.alasan!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SiskaraTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SiskaraTheme.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: SiskaraTheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Temuan Staf BBKK: ${answer.alasan}',
                    style: const TextStyle(
                      color: SiskaraTheme.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EvidenceImage extends StatefulWidget {
  const _EvidenceImage({
    required this.storagePath,
    this.title = 'Foto Bukti',
    this.subtitle,
    this.latitude,
    this.longitude,
    this.timestamp,
  });

  final String storagePath;
  final String title;
  final String? subtitle;
  final double? latitude;
  final double? longitude;
  final DateTime? timestamp;

  @override
  State<_EvidenceImage> createState() => _EvidenceImageState();
}

class _EvidenceImageState extends State<_EvidenceImage> {
  late Future<String> _imageUrl;

  @override
  void initState() {
    super.initState();
    _imageUrl = _resolveUrl(widget.storagePath);
  }

  @override
  void didUpdateWidget(covariant _EvidenceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath) {
      _imageUrl = _resolveUrl(widget.storagePath);
    }
  }

  Future<String> _resolveUrl(String path) => path.startsWith('r2://')
      ? StorageService().getDownloadUrl(path)
      : Future.value(path);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _imageUrl,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MediaError(
            message: ErrorMessage.from(
              snapshot.error!,
              fallback: 'Bukti foto tidak dapat dimuat.',
            ),
            onRetry: () => setState(() {
              _imageUrl = _resolveUrl(widget.storagePath);
            }),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final resolvedUrl = snapshot.data!;

        return GestureDetector(
          onTap: () {
            InteractivePhotoViewer.show(
              context,
              imageUrl: resolvedUrl,
              title: widget.title,
              subtitle: widget.subtitle,
              latitude: widget.latitude,
              longitude: widget.longitude,
              timestamp: widget.timestamp,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Image.network(
                  resolvedUrl,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _MediaError(
                    message: ErrorMessage.from(
                      error,
                      fallback: 'Bukti foto tidak dapat dimuat. Periksa koneksi.',
                    ),
                    onRetry: () => setState(() {
                      _imageUrl = _resolveUrl(widget.storagePath);
                    }),
                  ),
                ),
                // Overlay hint badge for interactive tap, zoom, and download
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Tekan untuk Zoom & Unduh',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.customLabel});
  final String status;
  final String? customLabel;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case 'final':
        bg = SiskaraTheme.success.withValues(alpha: 0.12);
        fg = SiskaraTheme.success;
        text = customLabel ?? 'Disetujui';
        break;
      case 'ditolak_otomatis':
      case 'ditolak_staf':
        bg = SiskaraTheme.error.withValues(alpha: 0.12);
        fg = SiskaraTheme.error;
        text = customLabel ?? 'Ditolak';
        break;
      case 'menunggu_verifikasi_staf':
      default:
        bg = SiskaraTheme.warning.withValues(alpha: 0.14);
        fg = SiskaraTheme.warning;
        text = customLabel ?? 'Menunggu review';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: SiskaraTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewError extends StatelessWidget {
  const _ReviewError({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 44, color: SiskaraTheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaError extends StatelessWidget {
  const _MediaError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: SiskaraTheme.backgroundLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined,
              size: 28, color: SiskaraTheme.textSecondary),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: SiskaraTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

String _displayLabel(String value) => value
    .split('_')
    .map((part) =>
        part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _displayValue(dynamic value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Ya' : 'Tidak';
  if (value is String && value.trim().isEmpty) return '—';
  return value.toString();
}

String _answerLabel(String value) {
  const labels = {
    'layak': 'Memenuhi Syarat',
    'memenuhi_syarat': 'Memenuhi Syarat',
    'tidak_layak': 'Tidak Memenuhi Syarat',
    'tidak_memenuhi_syarat': 'Tidak Memenuhi Syarat',
    'dilaporkan': 'Foto Dilaporkan',
    'foto_diambil': 'Foto Dilaporkan',
    'menunggu_penilaian': 'Menunggu Penilaian Staf BBKK',
    'tidak_tampak_tanda': 'Tidak tampak tanda',
    'tampak_tanda': 'Tampak tanda',
    'baik': 'Baik',
    'cukup': 'Cukup',
    'kurang': 'Kurang',
  };
  return labels[value] ?? _displayLabel(value);
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({
    required this.review,
    required this.onDownload,
    required this.isDownloading,
  });

  final _ReviewData review;
  final VoidCallback onDownload;
  final bool isDownloading;

  @override
  Widget build(BuildContext context) {
    final isKapal = review.submission.isKapal;
    final idShort = review.submission.id.length >= 8
        ? review.submission.id.substring(0, 8).toUpperCase()
        : review.submission.id.toUpperCase();
    final docNumber = isKapal
        ? 'BBKK.MKS/PHQC/$idShort/${DateTime.now().year}'
        : 'BBKK.MKS/ASIC/$idShort/${DateTime.now().year}';
    final namaSarana = isKapal
        ? (review.submission.dataUmum['nama_kapal']?.toString() ?? 'KAPAL LAUT')
        : (review.submission.dataUmum['nomor_penerbangan']?.toString() ??
            'PESAWAT UDARA');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF16A34A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'SURAT RESMI TERBIT • FORMAT A4',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isKapal
                          ? 'Sertifikat Karantina Kesehatan Kapal (PHQC)'
                          : 'Surat Sanitasi Pesawat Udara (ASIC)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14532D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFBBF7D0)),
          const SizedBox(height: 12),
          _buildInfoRow('Nomor Dokumen', docNumber),
          const SizedBox(height: 6),
          _buildInfoRow('Sarana Transportasi', namaSarana),
          const SizedBox(height: 6),
          _buildInfoRow(
            isKapal ? 'Nahkoda / Pemohon' : 'Pilot in Command',
            review.pengisiNama ?? 'Deklaran Pemohon',
          ),
          const SizedBox(height: 6),
          _buildInfoRow(
            'Validator BBKK',
            review.verifikatorNama ?? 'Petugas Validasi BBKK Makassar',
          ),
          const SizedBox(height: 6),
          _buildInfoRow(
            'Hasil Penilaian',
            'MEMENUHI PERSYARATAN (LAIK OPERASIONAL)',
            isHighlight: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isDownloading ? null : onDownload,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 20),
              label: Text(
                isDownloading
                    ? 'Menyiapkan & Mengunduh PDF...'
                    : 'Unduh Surat Kelayakan Sanitasi (A4 PDF)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Dokumen A4 tersimpan di folder Download & dapat langsung dibuka/dicetak.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF166534),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? const Color(0xFF15803D) : const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}

