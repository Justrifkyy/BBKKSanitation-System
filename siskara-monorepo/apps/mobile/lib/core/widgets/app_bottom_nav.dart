import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_model.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.user,
    required this.location,
    super.key,
  });

  final UserModel user;
  final String location;

  @override
  Widget build(BuildContext context) {
    final destinations = user.isStaf
        ? const [
            _Destination('/dashboard', 'Beranda', Icons.grid_view_rounded),
            _Destination('/review', 'Antrian', Icons.fact_check_outlined),
            _Destination('/history', 'Riwayat', Icons.history_outlined),
            _Destination('/profile', 'Profil', Icons.person_outline),
          ]
        : const [
            _Destination('/dashboard', 'Beranda', Icons.grid_view_rounded),
            _Destination(
              '/submission',
              'Skrining',
              Icons.assignment_turned_in_outlined,
            ),
            _Destination('/history', 'Riwayat', Icons.history_outlined),
            _Destination('/profile', 'Profil', Icons.person_outline),
          ];
    final selectedIndex = destinations.indexWhere(
      (destination) =>
          location == destination.path ||
          location.startsWith('${destination.path}/'),
    );

    return NavigationBar(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) {
        final path = destinations[index].path;
        if (location != path) context.go(path);
      },
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.icon, fill: 1),
            label: destination.label,
          ),
      ],
    );
  }
}

class _Destination {
  const _Destination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}
