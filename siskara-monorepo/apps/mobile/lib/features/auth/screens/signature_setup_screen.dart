import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
  Uint8List? _uploadedSignature;
  String? _uploadedSignatureName;
  String? _uploadedSignatureContentType;
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
    if (needsSignature &&
        _uploadedSignature == null &&
        _signatureController.points.isEmpty) {
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
        final bytes =
            _uploadedSignature ?? await _signatureController.toPngBytes();
        if (bytes == null || bytes.isEmpty) {
          throw StateError('Tanda tangan tidak dapat diproses. Coba gambar ulang.');
        }
        final signatureUrl = await storageService.uploadSignatureBytes(
          user.id,
          bytes,
          contentType: _uploadedSignatureContentType ?? 'image/png',
        );
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

  Future<void> _pickSignature() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'svg'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showMessage('File tidak dapat dibaca. Silakan pilih file lain.');
        return;
      }
      if (bytes.length > 512 * 1024) {
        _showMessage('Ukuran tanda tangan maksimal 512 KB.');
        return;
      }

      final extension = file.extension?.toLowerCase();
      final contentType = switch (extension) {
        'png' when _hasPngSignature(bytes) => 'image/png',
        'svg' when _looksLikeSvg(bytes) => 'image/svg+xml',
        _ => null,
      };
      if (contentType == null) {
        _showMessage('Isi file tidak sesuai dengan format PNG atau SVG.');
        return;
      }

      setState(() {
        _uploadedSignature = bytes;
        _uploadedSignatureName = file.name;
        _uploadedSignatureContentType = contentType;
      });
    } on PlatformException catch (error) {
      _showMessage('Tidak dapat membuka pemilih file: ${error.message}');
    } catch (error) {
      _showMessage('Tidak dapat memilih tanda tangan: $error');
    }
  }

  static bool _hasPngSignature(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;

  static bool _looksLikeSvg(Uint8List bytes) {
    final text = String.fromCharCodes(bytes).trimLeft();
    final withoutDeclaration = text.replaceFirst(
      RegExp(r'^<\?xml[^>]*>\s*', caseSensitive: false),
      '',
    );
    return RegExp(r'^<svg(?:\s|>)', caseSensitive: false)
            .hasMatch(withoutDeclaration) &&
        RegExp(r'</svg>\s*$', caseSensitive: false)
            .hasMatch(withoutDeclaration) &&
        !RegExp(
          r'<script\b|<foreignObject\b|\bon[a-z]+\s*=|javascript:|<!DOCTYPE',
          caseSensitive: false,
        ).hasMatch(withoutDeclaration);
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
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
          TextButton.icon(
            onPressed: _isSaving ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
          const SizedBox(width: 8),
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
                    if (_uploadedSignature != null) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.verified_outlined),
                        title: Text(_uploadedSignatureName ?? 'Tanda tangan'),
                        subtitle: Text(
                          _uploadedSignatureContentType == 'image/svg+xml'
                              ? 'SVG siap diunggah'
                              : 'PNG siap diunggah',
                        ),
                        trailing: IconButton(
                          tooltip: 'Hapus file pilihan',
                          onPressed: () => setState(() {
                            _uploadedSignature = null;
                            _uploadedSignatureName = null;
                            _uploadedSignatureContentType = null;
                          }),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _uploadedSignature == null
                            ? _signatureController.clear
                            : null,
                        icon: const Icon(Icons.refresh, size: 17),
                        label: const Text('Ulangi'),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : _pickSignature,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Pilih file PNG atau SVG'),
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
