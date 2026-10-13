import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';

/// Screen for capturing the user's digital signature (drawn or uploaded).
/// This is shown once during account setup.
class SignatureSetupScreen extends ConsumerWidget {
  const SignatureSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanda Tangan Digital'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(SiskaraTheme.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.draw_outlined,
                size: 80,
                color: SiskaraTheme.primaryBlue,
              ),
              const SizedBox(height: SiskaraTheme.spacingMd),
              Text(
                'Buat Tanda Tangan Anda',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: SiskaraTheme.spacingSm),
              Text(
                'Tanda tangan ini akan digunakan pada dokumen resmi. '
                'Gambar tanda tangan Anda di area di bawah ini.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SiskaraTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: SiskaraTheme.spacingLg),

              // Signature pad placeholder
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: SiskaraTheme.divider, width: 2),
                  borderRadius: BorderRadius.circular(SiskaraTheme.radiusMd),
                  color: Colors.white,
                ),
                child: const Center(
                  child: Text(
                    'Area Tanda Tangan\n(Signature pad will be integrated here)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SiskaraTheme.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: SiskaraTheme.spacingLg),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Clear signature
                      },
                      child: const Text('Hapus'),
                    ),
                  ),
                  const SizedBox(width: SiskaraTheme.spacingMd),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Save signature and navigate
                      },
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
