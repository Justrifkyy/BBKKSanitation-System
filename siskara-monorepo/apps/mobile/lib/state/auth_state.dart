import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Provides the AuthService instance.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Watches Firebase auth state and loads the corresponding UserModel.
final authStateProvider = StreamProvider<UserModel?>((ref) {
  final authService = ref.read(authServiceProvider);

  return authService.authStateChanges.asyncExpand((fbUser) {
    if (fbUser == null) return Stream.value(null);
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: AppConstants.firebaseDatabaseId,
    )
        .collection('users')
        .doc(fbUser.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      if (!snapshot.exists) {
        throw StateError('Profil pengguna tidak ditemukan.');
      }
      final role = await authService.getUserRole();
      if (role == null || role != snapshot.data()?['role']) {
        throw StateError('Role akun tidak valid. Hubungi administrator.');
      }
      return UserModel.fromMap(snapshot.data()!, snapshot.id);
    });
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
