import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';

/// Detail view for staf_bbkk to review a single submission.
/// Shows general data, checklist answers, evidence media, and approve/reject buttons.
class ReviewDetailScreen extends ConsumerWidget {
  final String submissionId;

  const ReviewDetailScreen({
    super.key,
    required this.submissionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Verifikasi'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(SiskaraTheme.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 80,
                color: SiskaraTheme.primaryBlue,
              ),
              const SizedBox(height: SiskaraTheme.spacingMd),
              Text(
                'Submission Detail',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: SiskaraTheme.spacingSm),
              Text(
                'ID: $submissionId\n\n'
                'Detail view akan menampilkan:\n'
                '• Data Umum\n'
                '• Jawaban Checklist\n'
                '• Bukti Foto/Video\n'
                '• Tombol Setujui / Tolak',
                textAlign: TextAlign.center,
                style: TextStyle(color: SiskaraTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SiskaraTheme.spacingMd),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Reject with PIN confirmation
                  },
                  icon: const Icon(Icons.close, color: SiskaraTheme.error),
                  label: const Text('Tolak', style: TextStyle(color: SiskaraTheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SiskaraTheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: SiskaraTheme.spacingMd),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Approve with PIN confirmation + signature
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Setujui'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SiskaraTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
