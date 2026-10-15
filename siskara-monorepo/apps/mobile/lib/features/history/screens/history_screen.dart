import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/error_message.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../models/submission_model.dart';
import '../../../state/auth_state.dart';
import '../../../state/submission_state.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissions = ref.watch(userSubmissionsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final isStaff = user?.isStaf == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(isStaff ? 'Riwayat verifikasi' : 'Riwayat pengajuan'),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: submissions.when(
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(userSubmissionsProvider),
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 110),
                    _HistoryEmpty(
                      isStaff: isStaff,
                      onAction: () =>
                          context.go(isStaff ? '/review' : '/submission'),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
                  children: [
                    _HistorySummary(
                      total: list.length,
                      isStaff: isStaff,
                    ),
                    const SizedBox(height: 19),
                    Text(
                      isStaff ? 'Pengajuan yang pernah ditinjau' : 'Aktivitas Anda',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 9),
                    for (final submission in list)
                      _HistoryCard(
                        submission: submission,
                        onTap: () {
                          if (isStaff) {
                            context.go('/review/${submission.id}');
                          } else if (submission.isDraft) {
                            context.go(
                              '/submission?draftId=${submission.id}',
                            );
                          } else {
                            context.go('/history/${submission.id}');
                          }
                        },
                      ),
                  ],
                ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 45,
                  color: SiskaraTheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Riwayat tidak dapat dimuat: ${ErrorMessage.from(error)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(userSubmissionsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: user == null
          ? null
          : AppBottomNav(
              user: user,
              location: GoRouterState.of(context).matchedLocation,
            ),
    );
  }
}

class _HistorySummary extends StatelessWidget {

  const _HistorySummary({required this.total, required this.isStaff});
  final int total;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163D5C), Color(0xFF187C76)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: Colors.white, size: 27),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total catatan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isStaff
                      ? 'Keputusan verifikasi yang telah Anda berikan'
                      : 'Status deklarasi sanitasi Anda',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11,
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

class _HistoryCard extends StatelessWidget {

  const _HistoryCard({required this.submission, this.onTap});
  final SubmissionModel submission;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isKapal = submission.isKapal;
    final name = submission.dataUmum['nama_kapal'] ??
        submission.dataUmum['nomor_penerbangan'] ??
        (isKapal ? 'Pengajuan kapal' : 'Pengajuan pesawat');
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    SiskaraTheme.statusColor(submission.status).withValues(alpha: 0.12),
                child: Icon(
                  isKapal
                      ? Icons.directions_boat_outlined
                      : Icons.flight_outlined,
                  size: 20,
                  color: SiskaraTheme.statusColor(submission.status),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${isKapal ? 'Kapal' : 'Pesawat'} • ${_formatDate(submission.createdAt)}',
                      style: const TextStyle(
                        color: SiskaraTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (submission.isDraft)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 14,
                              color: Color(0xFF0D9488),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Draf • Ketuk untuk lanjutkan',
                              style: TextStyle(
                                color: Color(0xFF0D9488),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (submission.status == 'final')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Disetujui (ACC)',
                              style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF0F766E).withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 11,
                                  color: Color(0xFF0F766E),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Surat A4 Terbit',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SiskaraTheme.statusColor(submission.status)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          SiskaraTheme.statusLabel(submission.status),
                          style: TextStyle(
                            color: SiskaraTheme.statusColor(submission.status),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  submission.isDraft
                      ? Icons.edit_outlined
                      : Icons.chevron_right,
                  color: submission.isDraft
                      ? const Color(0xFF0D9488)
                      : SiskaraTheme.textSecondary,
                  size: submission.isDraft ? 20 : 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {

  const _HistoryEmpty({required this.isStaff, required this.onAction});
  final bool isStaff;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 66,
            color: SiskaraTheme.textSecondary.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 15),
          Text(
            isStaff ? 'Belum ada verifikasi' : 'Belum ada pengajuan',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 7),
          Text(
            isStaff
                ? 'Pengajuan yang sudah Anda tinjau akan muncul di sini.'
                : 'Deklarasi yang Anda kirim akan tercatat dan dapat dipantau di sini.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SiskaraTheme.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: onAction,
            child: Text(isStaff ? 'Kembali ke antrian' : 'Buat pengajuan'),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final date = value.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}
