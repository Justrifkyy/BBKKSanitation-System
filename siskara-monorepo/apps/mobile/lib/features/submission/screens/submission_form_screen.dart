import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../state/auth_state.dart';
import '../../../state/submission_state.dart';

/// Main submission form screen for kepala_kapal / kepala_penerbangan.
/// Dynamically renders the form based on the active checklist template.
class SubmissionFormScreen extends ConsumerWidget {
  const SubmissionFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final template = ref.watch(activeTemplateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user?.role == 'kepala_kapal'
              ? 'Pemeriksaan Kapal'
              : 'Pemeriksaan Pesawat',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat',
            onPressed: () {
              // TODO: Navigate to history
            },
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
      body: template.when(
        data: (tmpl) {
          if (tmpl == null) {
            return const Center(
              child: Text('Tidak ada template aktif.\nHubungi administrator.'),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(SiskaraTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Template info card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(SiskaraTheme.spacingMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tmpl.namaTemplate,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: SiskaraTheme.spacingXs),
                        Text(
                          'Versi ${tmpl.versi} • ${tmpl.modaTransportasi.toUpperCase()}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: SiskaraTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: SiskaraTheme.spacingMd),

                // Data Umum Section
                Text(
                  'Data Umum',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: SiskaraTheme.spacingSm),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(SiskaraTheme.spacingMd),
                    child: Text(
                      'Data Umum fields akan di-render secara dinamis dari template.\n'
                      '(Implementation will follow)',
                      style: TextStyle(color: SiskaraTheme.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: SiskaraTheme.spacingLg),

                // Checklist Section
                Text(
                  'Checklist Pemeriksaan',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: SiskaraTheme.spacingSm),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(SiskaraTheme.spacingMd),
                    child: Text(
                      'Checklist items akan di-render secara dinamis dari template items.\n'
                      '(Implementation will follow)',
                      style: TextStyle(color: SiskaraTheme.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: SiskaraTheme.spacingLg),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Validate, sign, and submit
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Submit Deklarasi'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
