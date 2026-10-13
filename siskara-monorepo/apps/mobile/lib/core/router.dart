import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/signature_setup_screen.dart';
import '../features/submission/screens/submission_form_screen.dart';
import '../features/review/screens/review_queue_screen.dart';
import '../features/review/screens/review_detail_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../state/auth_state.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) {
        // Route based on role
        final role = authState.valueOrNull?.role;
        switch (role) {
          case 'kepala_kapal':
          case 'kepala_penerbangan':
            return '/submission';
          case 'staf_bbkk':
            return '/review';
          default:
            return '/login';
        }
      }
      return null;
    },
    routes: [
      // ─── Auth Routes ─────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/signature-setup',
        builder: (context, state) => const SignatureSetupScreen(),
      ),

      // ─── Kepala (Ship/Aircraft) Routes ───────────────
      GoRoute(
        path: '/submission',
        builder: (context, state) => const SubmissionFormScreen(),
      ),

      // ─── Staf BBKK Routes ───────────────────────────
      GoRoute(
        path: '/review',
        builder: (context, state) => const ReviewQueueScreen(),
      ),
      GoRoute(
        path: '/review/:submissionId',
        builder: (context, state) => ReviewDetailScreen(
          submissionId: state.pathParameters['submissionId']!,
        ),
      ),

      // ─── Shared Routes ──────────────────────────────
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
    ],
  );
});
