import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../state/auth_state.dart';
import '../../../state/submission_state.dart';

/// Review queue screen for staf_bbkk.
/// Lists submissions with status `menunggu_verifikasi_staf`.
class ReviewQueueScreen extends ConsumerWidget {
  const ReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingSubmissions = ref.watch(pendingSubmissionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrian Verifikasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat Review',
            onPressed: () => context.go('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
            },
          ),
        ],
      ),
      body: pendingSubmissions.when(
        data: (submissions) {
          if (submissions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: SiskaraTheme.success.withOpacity(0.5),
                  ),
                  const SizedBox(height: SiskaraTheme.spacingMd),
                  Text(
                    'Tidak ada submission\nyang perlu diverifikasi',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: SiskaraTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(SiskaraTheme.spacingMd),
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final sub = submissions[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: sub.isKapal
                        ? SiskaraTheme.primaryBlue
                        : SiskaraTheme.accentTeal,
                    child: Icon(
                      sub.isKapal ? Icons.directions_boat : Icons.flight,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    sub.dataUmum['nama_kapal'] ??
                        sub.dataUmum['nomor_penerbangan'] ??
                        'Submission',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${sub.modaTransportasi.toUpperCase()} • ${sub.createdAt.toString().substring(0, 16)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/review/${sub.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
