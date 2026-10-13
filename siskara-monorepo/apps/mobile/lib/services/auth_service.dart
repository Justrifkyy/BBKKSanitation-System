import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/user_model.dart';

/// Handles all Firebase Authentication operations.
class AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Current Firebase user stream.
  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();

  /// Current Firebase user.
  fb.User? get currentUser => _auth.currentUser;

  /// Login with email/phone and password.
  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Register a new user (self-registration for kepala roles).
  Future<fb.UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String nama,
    required String phone,
    required String role,
    String? idNumber,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create Firestore user document
    await _firestore.collection(AppConstants.colUsers).doc(credential.user!.uid).set({
      'nama': nama,
      'role': role,
      'phone': phone,
      'id_number': idNumber,
      'signature_url': null,
      'pin_hash': null,
      'dibuat_oleh': null,
      'created_at': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  /// Fetch user profile from Firestore.
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection(AppConstants.colUsers).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  /// Get user role from ID token claims.
  Future<String?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final tokenResult = await user.getIdTokenResult(true);
    final role = tokenResult.claims?['role'] as String?;

    // Fallback: read from Firestore if claim not set yet
    if (role == null) {
      final profile = await getUserProfile(user.uid);
      return profile?.role;
    }

    return role;
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
