import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/error_message.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/arjuna_loading.dart';
import '../../../models/submission_model.dart';
import '../../../state/auth_state.dart';
import '../../../state/submission_state.dart';

class ReviewQueueScreen extends ConsumerWidget {
  const ReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(pendingSubmissionsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrian verifikasi'),
        actions: [
          IconButton(
            tooltip: 'Buat akun Nahkoda/Pilot',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => _openCreateAccount(context, ref),
          ),
        ],
      ),
      body: queue.when(
        data: (submissions) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(pendingSubmissionsProvider),
          child: submissions.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(22),
                  children: [
                    _QueueWelcome(name: user?.nama ?? 'Petugas'),
                    const SizedBox(height: 75),
                    const _QueueEmpty(),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    _QueueWelcome(name: user?.nama ?? 'Petugas'),
                    const SizedBox(height: 21),
                    Row(
                      children: [
                        Text(
                          'Perlu ditinjau',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: SiskaraTheme.warning.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${submissions.length}',
                            style: const TextStyle(
                              color: SiskaraTheme.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final submission in submissions)
                      _SubmissionCard(submission: submission),
                    const SizedBox(height: 6),
                    const _ReadOnlyNote(),
                  ],
                ),
        ),
        loading: () => const Center(child: ArjunaLoadingWidget()),
        error: (error, _) => _QueueFailure(
          message: 'Antrian tidak dapat dimuat: ${ErrorMessage.from(error)}',
          onRetry: () => ref.invalidate(pendingSubmissionsProvider),
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

  Future<void> _openCreateAccount(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const _CreateHeadAccountDialog(),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun berhasil dibuat.')),
      );
    }
  }
}

class _CreateHeadAccountDialog extends ConsumerStatefulWidget {
  const _CreateHeadAccountDialog();

  @override
  ConsumerState<_CreateHeadAccountDialog> createState() =>
      _CreateHeadAccountDialogState();
}

class _CreateHeadAccountDialogState
    extends ConsumerState<_CreateHeadAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _idNumber = TextEditingController();
  final _password = TextEditingController();
  String _role = 'kepala_kapal';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _idNumber.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authServiceProvider).createHeadAccount(
            email: _email.text.trim(),
            password: _password.text,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            role: _role,
            idNumber:
                _idNumber.text.trim().isEmpty ? null : _idNumber.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Akun tidak dapat dibuat: ${ErrorMessage.from(error)}',
            ),
            backgroundColor: SiskaraTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buat akun kepala transportasi'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Peran'),
                  items: const [
                    DropdownMenuItem(
                      value: 'kepala_kapal',
                      child: Text('Nahkoda / Kepala kapal'),
                    ),
                    DropdownMenuItem(
                      value: 'kepala_penerbangan',
                      child: Text('Pilot / Kepala penerbangan'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _role = value);
                        },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nama lengkap'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Masukkan email yang valid.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Nomor telepon'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _idNumber,
                  decoration: const InputDecoration(
                    labelText: 'Nomor identitas (opsional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata sandi sementara',
                  ),
                  validator: (value) => value == null || value.length < 8
                      ? 'Minimal 8 karakter.'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Buat akun'),
        ),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Wajib diisi.' : null;
}

class _QueueWelcome extends StatelessWidget {
  const _QueueWelcome({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123D5B), Color(0xFF167A75)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat bertugas, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Tinjau deklarasi yang menunggu keputusan akhir.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11,
                    height: 1.35,
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

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.submission});
  final SubmissionModel submission;

  @override
  Widget build(BuildContext context) {
    final isKapal = submission.isKapal;
    final name = submission.dataUmum['nama_kapal'] ??
        submission.dataUmum['nomor_penerbangan'] ??
        'Pengajuan sanitasi';
    final origin = submission.dataUmum['pelabuhan_asal'] ??
        submission.dataUmum['berangkat_dari'] ??
        'Asal belum diisi';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/review/${submission.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: (isKapal
                          ? SiskaraTheme.primaryBlue
                          : SiskaraTheme.accentTeal)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isKapal
                      ? Icons.directions_boat_outlined
                      : Icons.flight_outlined,
                  color: isKapal
                      ? SiskaraTheme.primaryBlue
                      : SiskaraTheme.accentTeal,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isKapal ? 'Kapal' : 'Pesawat'} • $origin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SiskaraTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy • HH:mm')
                          .format(submission.createdAt.toLocal()),
                      style: const TextStyle(
                        color: SiskaraTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: SiskaraTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueEmpty extends StatelessWidget {
  const _QueueEmpty();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: SiskaraTheme.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.task_alt,
            size: 36,
            color: SiskaraTheme.success,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          'Semua sudah ditinjau',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Belum ada pengajuan yang menunggu verifikasi.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SiskaraTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: SiskaraTheme.textSecondary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Keputusan bersifat final. Tanda tangan digital dan PIN diperlukan untuk setiap keputusan.',
              style: TextStyle(
                color: SiskaraTheme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueFailure extends StatelessWidget {
  const _QueueFailure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 45, color: SiskaraTheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
