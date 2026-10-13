import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';

import '../../../core/theme.dart';
import '../../../services/storage_service.dart';
import '../../../state/auth_state.dart';

class SignatureSetupScreen extends ConsumerStatefulWidget {
  const SignatureSetupScreen({super.key});

  @override
  ConsumerState<SignatureSetupScreen> createState() =>
      _SignatureSetupScreenState();
}

class _SignatureSetupScreenState extends ConsumerState<SignatureSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _signatureController = SignatureController(
    penStrokeWidth: 2.5,
    penColor: SiskaraTheme.textPrimary,
    exportBackgroundColor: Colors.white,
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      _showMessage('Sesi pengguna tidak ditemukan. Silakan masuk kembali.');
      return;
    }

    final needsSignature = !user.hasSignature;
    final needsPin = !user.hasPin;
    if (needsSignature && _signatureController.points.isEmpty) {
      _showMessage('Buat tanda tangan pada area yang tersedia.');
      return;
    }
    if (needsPin) {
      if (!RegExp(r'^\d{6}$').hasMatch(_pinController.text)) {
        _showMessage('PIN harus terdiri dari 6 angka.');
        return;
      }
      if (_pinController.text != _confirmPinController.text) {
        _showMessage('Konfirmasi PIN tidak sesuai.');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final storageService = StorageService();
      final authService = ref.read(authServiceProvider);

      if (needsSignature) {
        final bytes = await _signatureController.toPngBytes();
        if (bytes == null || bytes.isEmpty) {
          throw StateError('Tanda tangan tidak dapat diproses. Coba gambar ulang.');
        }
        final signatureUrl =
            await storageService.uploadSignatureBytes(user.id, bytes);
        await authService.updateSignature(user.id, signatureUrl);
      }

      if (needsPin) await authService.setPin(_pinController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil keamanan berhasil disimpan.')),
      );
      context.go(user.isStaf ? '/review' : '/submission');
    } catch (error) {
      if (mounted) _showMessage('Tidak dapat menyimpan pengaturan: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SiskaraTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final needsSignature = user?.hasSignature != true;
    final needsPin = user?.hasPin != true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keamanan akun'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: () => ref.read(authServiceProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: user == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  const _SetupProgress(),
                  const SizedBox(height: 22),
                  Text(
                    'Siapkan tanda tangan digital',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Tanda tangan dan PIN digunakan untuk mengesahkan deklarasi '
                    'serta keputusan verifikasi.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SiskaraTheme.textSecondary,
                          height: 1.5,
                        ),
                  ),
                  if (needsSignature) ...[
                    const SizedBox(height: 22),
                    const _SectionHeading(
                      number: '01',
                      title: 'Tanda tangan Anda',
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 190,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: SiskaraTheme.divider),
                        borderRadius:
                            BorderRadius.circular(SiskaraTheme.radiusMd),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _signatureController.clear,
                        icon: const Icon(Icons.refresh, size: 17),
                        label: const Text('Ulangi'),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 18),
                    const _InfoBanner(
                      icon: Icons.verified_user_outlined,
                      message: 'Tanda tangan digital sudah tersimpan.',
                    ),
                  ],
                  if (needsPin) ...[
                    const SizedBox(height: 9),
                    _SectionHeading(
                      number: needsSignature ? '02' : '01',
                      title: 'Buat PIN konfirmasi',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PIN 6 angka akan diminta setiap kali tanda tangan digunakan. '
                      'PIN disimpan sebagai hash dan diverifikasi oleh server.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SiskaraTheme.textSecondary,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'PIN 6 angka',
                        prefixIcon: Icon(Icons.pin_outlined),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPinController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Ulangi PIN',
                        prefixIcon: Icon(Icons.lock_outline),
                        counterText: '',
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    const _InfoBanner(
                      icon: Icons.lock_outline,
                      message: 'PIN konfirmasi sudah diatur.',
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan dan lanjutkan'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SetupProgress extends StatelessWidget {
  const _SetupProgress();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 4, color: SiskaraTheme.accentTeal)),
        const SizedBox(width: 5),
        Expanded(child: Container(height: 4, color: SiskaraTheme.accentTeal)),
        const SizedBox(width: 5),
        Expanded(child: Container(height: 4, color: SiskaraTheme.divider)),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {

  const _SectionHeading({required this.number, required this.title});
  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: SiskaraTheme.accentTeal.withOpacity(0.12),
          child: Text(
            number,
            style: const TextStyle(
              color: SiskaraTheme.accentTeal,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {

  const _InfoBanner({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: SiskaraTheme.success.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: SiskaraTheme.success),
          const SizedBox(width: 9),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
