import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/error_message.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../models/submission_model.dart';
import '../../../models/user_model.dart';
import '../../../state/auth_state.dart';
import '../../../state/submission_state.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final submissions = ref.watch(userSubmissionsProvider);
    final pending =
        user?.isStaf == true ? ref.watch(pendingSubmissionsProvider) : null;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SISKARA'),
        actions: [
          IconButton(
            tooltip: 'Profil',
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userSubmissionsProvider);
          ref.invalidate(pendingSubmissionsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            _WelcomePanel(user: user),
            const SizedBox(height: 16),
            const _SectionTitle(
              title: 'Ringkasan',
              trailing: 'Perbarui dengan tarik layar',
            ),
            const SizedBox(height: 9),
            submissions.when(
              data: (items) => _Statistics(
                submissions: items,
                pendingCount: pending?.valueOrNull?.length,
                isStaff: user.isStaf,
              ),
              loading: () => const _StatisticsLoading(),
              error: (error, _) => _InlineError(
                message:
                    'Statistik tidak dapat dimuat: ${ErrorMessage.from(error)}',
              ),
            ),
            if (pending != null)
              pending.when(
                data: (items) => Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: _StaffQueueSummary(count: items.length),
                ),
                loading: () => const SizedBox.shrink(),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _InlineError(
                    message:
                        'Jumlah antrian tidak dapat dimuat: ${ErrorMessage.from(error)}',
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const _SectionTitle(title: 'Menu utama'),
            const SizedBox(height: 9),
            _MenuGrid(user: user),
            const SizedBox(height: 17),
            const _SectionTitle(title: 'Keamanan akun'),
            const SizedBox(height: 9),
            _SignatureCard(user: user),
            const SizedBox(height: 5),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        user: user,
        location: GoRouterState.of(context).matchedLocation,
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF092F39), SiskaraTheme.primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -48,
            child: Container(
              width: 162,
              height: 162,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 25,
                ),
              ),
            ),
          ),
          Positioned(
            right: 22,
            bottom: 29,
            child: Icon(
              user.isStaf
                  ? Icons.health_and_safety_rounded
                  : user.role == AppConstants.roleKepalaKapal
                      ? Icons.directions_boat_filled_rounded
                      : Icons.flight_rounded,
              size: 70,
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.health_and_safety_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SISKARA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'SANITASI TRANSPORTASI',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 8,
                            letterSpacing: 0.65,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF8DE0B4),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'AKTIF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _greeting(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 11,
                  ),
                ),
                Text(
                  user.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  user.isStaf
                      ? 'Petugas pemeriksaan BBKK'
                      : user.role == AppConstants.roleKepalaKapal
                          ? 'Nahkoda • Pemeriksaan kapal'
                          : 'Pilot • Pemeriksaan pesawat',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      child: InkWell(
                        onTap: () =>
                            context.go(user.isStaf ? '/review' : '/submission'),
                        borderRadius: BorderRadius.circular(11),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.isStaf ? 'Buka antrian' : 'Mulai skrining',
                                style: const TextStyle(
                                  color: SiskaraTheme.primaryDark,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: SiskaraTheme.primaryDark,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi,';
    if (hour < 15) return 'Selamat siang,';
    if (hour < 19) return 'Selamat sore,';
    return 'Selamat malam,';
  }
}

class _Statistics extends StatelessWidget {
  const _Statistics({
    required this.submissions,
    required this.pendingCount,
    required this.isStaff,
  });

  final List<SubmissionModel> submissions;
  final int? pendingCount;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    final complete = submissions
        .where((submission) => submission.status == AppConstants.statusFinal)
        .length;
    final waiting = submissions
        .where((submission) =>
            submission.status == AppConstants.statusMenungguVerifikasi)
        .length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: isStaff ? 'Ditinjau' : 'Total skrining',
            value: submissions.length.toString(),
            icon: Icons.assignment_outlined,
            color: SiskaraTheme.primaryBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: isStaff ? 'Antrian' : 'Menunggu',
            value: isStaff
                ? (pendingCount?.toString() ?? '…')
                : waiting.toString(),
            icon: Icons.hourglass_bottom_rounded,
            color: SiskaraTheme.warning,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'Selesai',
            value: complete.toString(),
            icon: Icons.check_circle_outline,
            color: SiskaraTheme.success,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 21,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: SiskaraTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsLoading extends StatelessWidget {
  const _StatisticsLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 83,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

class _StaffQueueSummary extends StatelessWidget {
  const _StaffQueueSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SiskaraTheme.warning.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: SiskaraTheme.warning,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              count == 0
                  ? 'Tidak ada pengajuan menunggu.'
                  : '$count pengajuan menunggu pemeriksaan.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.chevron_right, size: 19),
        ],
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final menus = user.isStaf
        ? const [
            _MenuItem(
              'Antrian pemeriksaan',
              'Tinjau pengajuan masuk',
              Icons.fact_check_outlined,
              SiskaraTheme.primaryBlue,
              '/review',
            ),
            _MenuItem(
              'Riwayat',
              'Lihat keputusan terdahulu',
              Icons.history_rounded,
              SiskaraTheme.accentTeal,
              '/history',
            ),
          ]
        : const [
            _MenuItem(
              'Isi skrining',
              'Mulai deklarasi sanitasi',
              Icons.add_task_rounded,
              SiskaraTheme.primaryBlue,
              '/submission',
            ),
            _MenuItem(
              'Riwayat',
              'Pantau status pengajuan',
              Icons.history_rounded,
              SiskaraTheme.accentTeal,
              '/history',
            ),
          ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: menus.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 9,
        crossAxisSpacing: 9,
        mainAxisExtent: 112,
      ),
      itemBuilder: (context, index) => _MenuTile(item: menus[index]),
    );
  }
}

class _MenuItem {
  const _MenuItem(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.path,
  );

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String path;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item});

  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: SiskaraTheme.divider.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.color, size: 17),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: item.color.withValues(alpha: 0.8),
                    size: 17,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  height: 1.2,
                  color: SiskaraTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignatureCard extends StatelessWidget {
  const _SignatureCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final isReady = user.hasSignature && user.hasPin;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: () => context.go('/signature-setup?update=true'),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: SiskaraTheme.divider.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (isReady ? SiskaraTheme.success : SiskaraTheme.warning)
                      .withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.draw_outlined,
                  color: isReady ? SiskaraTheme.success : SiskaraTheme.warning,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tanda tangan digital',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isReady
                          ? 'Aktif • ketuk untuk memperbarui'
                          : 'Perlu dilengkapi sebelum digunakan',
                      style: const TextStyle(
                        fontSize: 10,
                        color: SiskaraTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 9,
              color: SiskaraTheme.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: SiskaraTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 11, color: SiskaraTheme.error),
      ),
    );
  }
}
