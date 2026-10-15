import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_message.dart';
import '../../../core/theme.dart';
import '../../../state/auth_state.dart';

class AuthErrorScreen extends ConsumerWidget {
  const AuthErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);
    if (authService.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final authState = ref.watch(authStateProvider);
    final error = authState.error;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 46,
                  color: SiskaraTheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Akun belum dapat dimuat',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 7),
                Text(
                  ErrorMessage.from(
                    error ?? StateError('Profil akun tidak tersedia.'),
                    fallback: 'Profil akun tidak dapat dimuat.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: SiskaraTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 17),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(authStateProvider),
                  icon: const Icon(Icons.refresh, size: 17),
                  label: const Text('Coba lagi'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await ref.read(authServiceProvider).signOut();
                      if (context.mounted) context.go('/login');
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tidak dapat keluar: ${ErrorMessage.from(error)}',
                          ),
                          backgroundColor: SiskaraTheme.error,
                        ),
                      );
                    }
                  },
                  child: const Text('Keluar dan masuk kembali'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
