import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/error_message.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../state/auth_state.dart';
import '../../../state/submission_state.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final user = profile.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Profil tidak dapat dimuat: ${ErrorMessage.from(error)}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Sesi pengguna berakhir.'));
          }

          final authUser = ref.read(authServiceProvider).currentUser;
          return ListView(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      SiskaraTheme.primaryDark,
                      SiskaraTheme.accentTeal,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 31,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      child: Text(
                        user.nama.trim().isEmpty
                            ? '?'
                            : user.nama.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      user.nama,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _roleName(user.role),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              Text(
                'Informasi akun',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 7),
              _ProfileCard(
                children: [
                  _ProfileRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: authUser?.email ?? '-',
                  ),
                  const Divider(height: 20),
                  _ProfileRow(
                    icon: Icons.phone_outlined,
                    label: 'Nomor telepon',
                    value: user.phone.isEmpty ? '-' : user.phone,
                  ),
                  if ((user.idNumber ?? '').isNotEmpty) ...[
                    const Divider(height: 20),
                    _ProfileRow(
                      icon: Icons.badge_outlined,
                      label: 'Nomor identitas',
                      value: user.idNumber!,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Keamanan akun',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 7),
              _ProfileCard(
                children: [
                  _SecurityRow(
                    label: 'Tanda tangan digital',
                    isComplete: user.hasSignature,
                  ),
                  const Divider(height: 20),
                  _SecurityRow(
                    label: 'PIN konfirmasi',
                    isComplete: user.hasPin,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/signature-setup?update=true'),
                  icon: const Icon(Icons.draw_outlined, size: 18),
                  label: const Text('Perbarui tanda tangan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context, ref),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Keluar dari akun', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SiskaraTheme.error,
                    side: const BorderSide(color: SiskaraTheme.error),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar:
          user == null ? null : AppBottomNav(user: user, location: location),
    );
  }

  static String _roleName(String role) => switch (role) {
        'kepala_kapal' => 'Nahkoda / Kepala kapal',
        'kepala_penerbangan' => 'Pilot / Kepala penerbangan',
        'staf_bbkk' => 'Petugas BBKK',
        'validator_admin' => 'Administrator',
        _ => role,
      };

  static Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      if (context.mounted) context.go('/login');
      await ref.read(authServiceProvider).signOut();
      ref.invalidate(authStateProvider);
      ref.invalidate(userSubmissionsProvider);
    } catch (_) {
      if (context.mounted) context.go('/login');
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SiskaraTheme.divider.withValues(alpha: 0.75)),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: SiskaraTheme.primaryBlue, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: SiskaraTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: SiskaraTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({required this.label, required this.isComplete});

  final String label;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final color = isComplete ? SiskaraTheme.success : SiskaraTheme.warning;
    return Row(
      children: [
        Icon(
          isComplete ? Icons.verified_outlined : Icons.pending_outlined,
          color: color,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isComplete ? 'Aktif' : 'Belum diatur',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
