import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/signature_setup_screen.dart';
import '../features/submission/screens/submission_form_screen.dart';
import '../features/review/screens/review_queue_screen.dart';
import '../features/review/screens/review_detail_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/auth/screens/unsupported_role_screen.dart';
import '../features/auth/screens/auth_error_screen.dart';
import 'widgets/route_error_screen.dart';
import '../state/auth_state.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    errorBuilder: (context, state) => RouteErrorScreen(
      error: state.error ?? Exception('Route error'),
    ),
    redirect: (context, state) {
      final profile = authState.valueOrNull;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (authState.hasError) {
        return state.matchedLocation == '/account-error'
            ? null
            : '/account-error';
      }
      if (profile == null) return isAuthRoute ? null : '/login';
      if (profile.isAdmin || (!profile.isKepala && !profile.isStaf)) {
        return '/unsupported';
      }
      final isSignatureUpdate = state.uri.queryParameters['update'] == 'true';
      if ((!profile.hasSignature || !profile.hasPin) && !isSignatureUpdate) {
        return state.matchedLocation == '/signature-setup'
            ? null
            : '/signature-setup';
      }
      if (isAuthRoute) return '/dashboard';
      if (state.matchedLocation == '/signature-setup' &&
          profile.hasSignature &&
          profile.hasPin &&
          !isSignatureUpdate) {
        return '/dashboard';
      }
      if (profile.isKepala &&
          ![
            '/dashboard',
            '/submission',
            '/history',
            '/profile',
            '/signature-setup',
            '/unsupported',
          ].contains(state.matchedLocation) &&
          !state.matchedLocation.startsWith('/history/')) {
        return '/submission';
      }
      if (profile.isStaf &&
          ![
            '/dashboard',
            '/review',
            '/history',
            '/profile',
            '/signature-setup',
            '/unsupported',
          ].contains(state.matchedLocation) &&
          !state.matchedLocation.startsWith('/review/') &&
          !state.matchedLocation.startsWith('/history/')) {
        return '/review';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/account-error',
        builder: (context, state) => const AuthErrorScreen(),
      ),
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
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),

      // ─── Kepala (Ship/Aircraft) Routes ───────────────
      GoRoute(
        path: '/submission',
        builder: (context, state) => SubmissionFormScreen(
          key: ValueKey(state.uri.toString()),
          draftId: state.uri.queryParameters['draftId'],
        ),
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
      GoRoute(
        path: '/history/:submissionId',
        builder: (context, state) => ReviewDetailScreen(
          submissionId: state.pathParameters['submissionId']!,
          readOnly: true,
        ),
      ),

      // ─── Shared Routes ──────────────────────────────
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
