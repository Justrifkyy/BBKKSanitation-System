import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';

class SiskaraApp extends ConsumerWidget {
  const SiskaraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SISKARA',
      debugShowCheckedModeBanner: false,
      theme: SiskaraTheme.lightTheme,
      darkTheme: SiskaraTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
