import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../error_message.dart';
import '../theme.dart';

class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({required this.error, super.key});

  final Exception error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 44,
                  color: SiskaraTheme.error,
                ),
                const SizedBox(height: 10),
                Text(
                  'Halaman tidak dapat dibuka',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  ErrorMessage.from(
                    error,
                    fallback:
                        'Terjadi kendala saat membuka halaman. Kembali ke beranda lalu coba lagi.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: SiskaraTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 15),
                FilledButton.icon(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.home_outlined, size: 17),
                  label: const Text('Kembali ke beranda'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
