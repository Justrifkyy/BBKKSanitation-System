import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Provides the AuthService instance.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Watches Firebase auth state and loads the corresponding UserModel.
final authStateProvider = StreamProvider<UserModel?>((ref) {
  final authService = ref.read(authServiceProvider);

  return authService.authStateChanges.asyncMap((fbUser) async {
    if (fbUser == null) return null;
    return await authService.getUserProfile(fbUser.uid);
  });
});

/// Provides the current user's role (reactive).
final userRoleProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.role;
});

/// Provides the current user's transport mode (for kepala roles).
final transportModeProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.transportMode;
});
