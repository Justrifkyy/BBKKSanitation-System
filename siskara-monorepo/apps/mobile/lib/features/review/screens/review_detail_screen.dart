import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../models/checklist_template_model.dart';
import '../../../models/submission_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../state/submission_state.dart';

class ReviewDetailScreen extends ConsumerStatefulWidget {

  const ReviewDetailScreen({super.key, required this.submissionId});
  final String submissionId;

  @override
  ConsumerState<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends ConsumerState<ReviewDetailScreen> {
  late Future<_ReviewData?> _reviewFuture;
  bool _isSavingDecision = false;

  @override
  void initState() {
    super.initState();
    _reviewFuture =
        ref.read(firestoreServiceProvider).loadReviewData(widget.submissionId);
  }

  Future<void> _decide(String decision) async {
    final result = await showDialog<_ReviewDecision>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReviewDecisionDialog(decision: decision),
    );
    if (result == null || !mounted) return;

    setState(() => _isSavingDecision = true);
    try {
      await ref.read(authServiceProvider).verifySubmission(
            submissionId: widget.submissionId,
            decision: decision,
            pin: result.pin,
            note: result.note,
          );
      ref.invalidate(pendingSubmissionsProvider);
      ref.invalidate(userSubmissionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'approve'
                ? 'Pengajuan disetujui. Dokumen resmi sedang disiapkan.'
                : 'Pengajuan ditolak dan catatan telah disimpan.',
          ),
          backgroundColor: SiskaraTheme.success,
        ),
      );
      context.go('/review');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Keputusan tidak dapat disimpan: $error'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Detail pemeriksaan')),
      body: FutureBuilder<_ReviewData?>(
        future: _reviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ReviewError(
              message: 'Detail pengajuan tidak dapat dimuat: ${snapshot.error}',
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              _SubmissionHeader(submission: review.submission),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Data umum',
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
                title: 'Hasil checklist',
                icon: Icons.fact_check_outlined,
                child: review.answers.isEmpty
                    ? const Text('Belum ada jawaban checklist.')
                    : Column(
                        children: [
                          for (var index = 0;
                              index < review.answers.length;
                              index++) ...[
                            if (index > 0) const Divider(height: 20),
                            _AnswerDetail(
                              answer: review.answers[index],
                              item: review.items[review.answers[index].templateItemId],
                              media: review.media[review.answers[index].id] ?? const [],
                            ),
                          ],
                        ],
                      ),
              ),
              if (review.submission.status == 'ditolak_otomatis') ...[
                const SizedBox(height: 14),
                const _NoticeCard(
                  icon: Icons.warning_amber_rounded,
                  color: SiskaraTheme.error,
                  title: 'Temuan otomatis',
                  message:
                      'Checklist menemukan kondisi yang memenuhi kriteria penolakan otomatis.',
                ),
              ],
              if (review.submission.status !=
                  'menunggu_verifikasi_staf') ...[
                const SizedBox(height: 14),
                const _NoticeCard(
                  icon: Icons.visibility_outlined,
                  color: SiskaraTheme.textSecondary,
                  title: 'Mode baca saja',
                  message:
                      'Keputusan akhir hanya dapat diberikan pada pengajuan yang menunggu verifikasi.',
                ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<_ReviewData?>(
        future: _reviewFuture,
        builder: (context, snapshot) {
          if (snapshot.data?.submission.status !=
              'menunggu_verifikasi_staf') {
            return const SizedBox.shrink();
          }
          return SafeArea(
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
                      onPressed:
                          _isSavingDecision ? null : () => _decide('reject'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Tolak / revisi'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SiskaraTheme.error,
                        side: const BorderSide(color: SiskaraTheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          _isSavingDecision ? null : () => _decide('approve'),
                      icon: _isSavingDecision
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Setujui'),
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
    return _ReviewData(
      submission: submission,
      answers: answers,
      items: {for (final item in items) item.id: item},
      media: Map.fromEntries(mediaEntries),
    );
  }
}

class _ReviewData {

  const _ReviewData({
    required this.submission,
    required this.answers,
    required this.items,
    required this.media,
  });
  final SubmissionModel submission;
  final List<SubmissionAnswerModel> answers;
  final Map<String, ChecklistTemplateItemModel> items;
  final Map<String, List<SubmissionAnswerMediaModel>> media;
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
        _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final approving = widget.decision == 'approve';
    return AlertDialog(
      title: Text(approving ? 'Setujui pengajuan?' : 'Tolak / minta revisi?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approving
                  ? 'Keputusan ini bersifat final dan dokumen resmi akan dibuat.'
                  : 'Tuliskan temuan yang harus diperbaiki. Keputusan ini bersifat final.',
            ),
            if (!approving) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Catatan / alasan penolakan',
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
                labelText: 'PIN konfirmasi',
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
          style: approving
              ? FilledButton.styleFrom(backgroundColor: SiskaraTheme.success)
              : FilledButton.styleFrom(backgroundColor: SiskaraTheme.error),
          child: Text(approving ? 'Konfirmasi setujui' : 'Konfirmasi tolak'),
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
    final title = submission.dataUmum['nama_kapal'] ??
        submission.dataUmum['nomor_penerbangan'] ??
        'Pengajuan sanitasi';
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: SiskaraTheme.primaryBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                submission.isKapal
                    ? Icons.directions_boat_outlined
                    : Icons.flight_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '$title',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '${submission.isKapal ? 'Kapal' : 'Pesawat'} • ${submission.createdAt.toLocal()}',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
          ),
          const SizedBox(height: 10),
          _StatusChip(status: submission.status),
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
      padding: const EdgeInsets.all(15),
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
              Icon(icon, color: SiskaraTheme.primaryBlue, size: 19),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 13),
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                color: SiskaraTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
  });
  final SubmissionAnswerModel answer;
  final ChecklistTemplateItemModel? item;
  final List<SubmissionAnswerMediaModel> media;

  @override
  Widget build(BuildContext context) {
    final failed = item?.isFailValue(answer.nilaiJawaban) ?? answer.statusGagal;
    final resultStatus = !failed
        ? 'final'
        : item?.autoRejectOnFail == true
            ? 'ditolak_otomatis'
            : 'menunggu_verifikasi_staf';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item?.label ?? answer.templateItemId,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(
              status: resultStatus,
              customLabel: _answerLabel(answer.nilaiJawaban),
            ),
          ],
        ),
        if (answer.alasan != null && answer.alasan!.trim().isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            'Alasan: ${answer.alasan}',
            style: const TextStyle(
              color: SiskaraTheme.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
        for (final evidence in media) ...[
          const SizedBox(height: 10),
          if (evidence.tipe == 'foto')
            _EvidenceImage(
              storagePath: evidence.fileUrl,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
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
                            content: Text('Bukti tidak dapat dibuka: $error'),
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
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Lokasi ${evidence.latitude!.toStringAsFixed(5)}, ${evidence.longitude!.toStringAsFixed(5)} • ${evidence.timestamp.toLocal()}',
                style: const TextStyle(
                  color: SiskaraTheme.textSecondary,
                  fontSize: 9,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _EvidenceImage extends StatefulWidget {

  const _EvidenceImage({required this.storagePath});
  final String storagePath;

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
        if (snapshot.hasError) return const _MediaError();
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            snapshot.data!,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const _MediaError(),
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
    final isPending = status == 'menunggu_verifikasi_staf';
    final isRejected =
        status == 'ditolak_otomatis' || status == 'ditolak_staf';
    final background = isRejected
        ? SiskaraTheme.error.withOpacity(0.12)
        : isPending
            ? SiskaraTheme.warning.withOpacity(0.15)
            : SiskaraTheme.success.withOpacity(0.12);
    final foreground = isRejected
        ? SiskaraTheme.error
        : isPending
            ? SiskaraTheme.warning
            : SiskaraTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        customLabel ?? SiskaraTheme.statusLabel(status),
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 11, height: 1.4)),
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
            const Icon(Icons.cloud_off_outlined, size: 48, color: SiskaraTheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaError extends StatelessWidget {
  const _MediaError();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      color: SiskaraTheme.backgroundLight,
      child: const Text('Bukti media tidak dapat dimuat.'),
    );
  }
}

String _displayLabel(String value) => value
    .split('_')
    .map((part) => part.isEmpty
        ? part
        : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _displayValue(dynamic value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Ya' : 'Tidak';
  if (value is String && value.trim().isEmpty) return '—';
  return value.toString();
}

String _answerLabel(String value) {
  const labels = {
    'memenuhi_syarat': 'Memenuhi syarat',
    'tidak_memenuhi_syarat': 'Tidak memenuhi',
    'tidak_tampak_tanda': 'Tidak tampak tanda',
    'tampak_tanda': 'Tampak tanda',
    'baik': 'Baik',
    'cukup': 'Cukup',
    'kurang': 'Kurang',
  };
  return labels[value] ?? _displayLabel(value);
}
