import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../state/auth_state.dart';
import '../../../state/submission_state.dart';

/// Submission history screen showing past submissions for all mobile roles.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissions = ref.watch(userSubmissionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Submission'),
      ),
      body: submissions.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: SiskaraTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: SiskaraTheme.spacingMd),
                  Text(
                    'Belum ada riwayat submission',
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
            itemCount: list.length,
            itemBuilder: (context, index) {
              final sub = list[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: SiskaraTheme.statusColor(sub.status),
                    child: Icon(
                      sub.isKapal ? Icons.directions_boat : Icons.flight,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    sub.dataUmum['nama_kapal'] ??
                        sub.dataUmum['nomor_penerbangan'] ??
                        'Submission',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(sub.createdAt.toString().substring(0, 16)),
                  trailing: Chip(
                    label: Text(
                      SiskaraTheme.statusLabel(sub.status),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: SiskaraTheme.statusColor(sub.status),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
