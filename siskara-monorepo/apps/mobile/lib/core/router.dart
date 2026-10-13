import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/signature_setup_screen.dart';
import '../features/submission/screens/submission_form_screen.dart';
import '../features/review/screens/review_queue_screen.dart';
import '../features/review/screens/review_detail_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/auth/screens/unsupported_role_screen.dart';
import '../state/auth_state.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final profile = authState.valueOrNull;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (profile == null) return isAuthRoute ? null : '/login';
      if (profile.isAdmin || (!profile.isKepala && !profile.isStaf)) {
        return '/unsupported';
      }
      if (!profile.hasSignature || !profile.hasPin) {
        return state.matchedLocation == '/signature-setup'
            ? null
            : '/signature-setup';
      }
      if (isAuthRoute) return profile.isStaf ? '/review' : '/submission';
      if (
          state.matchedLocation == '/signature-setup' &&
          profile.hasSignature &&
          profile.hasPin) {
        return profile.isStaf ? '/review' : '/submission';
      }
      if (profile.isKepala &&
          ![
            '/submission',
            '/history',
            '/signature-setup',
            '/unsupported',
          ].contains(state.matchedLocation)) {
        return '/submission';
      }
      if (profile.isStaf &&
          ![
            '/review',
            '/history',
            '/signature-setup',
            '/unsupported',
          ].contains(state.matchedLocation) &&
          !state.matchedLocation.startsWith('/review/')) {
        return '/review';
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
      GoRoute(
        path: '/unsupported',
        builder: (context, state) => const UnsupportedRoleScreen(),
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
