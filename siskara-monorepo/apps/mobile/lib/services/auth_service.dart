import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';

/// Handles all Firebase Authentication operations.
class AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: AppConstants.firebaseDatabaseId,
  );

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
    await ApiService().post(
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        'nama': nama,
        'phone': phone,
        'role': role,
        'id_number': idNumber,
      },
    );

    return signInWithEmailAndPassword(email: email, password: password);
  }

  /// Fetch user profile from Firestore.
  Future<UserModel?> getUserProfile(String uid) async {
    final doc =
        await _firestore.collection(AppConstants.colUsers).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Future<void> updateSignature(String uid, String storagePath) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) {
      throw StateError('Pengguna tidak dapat mengubah tanda tangan akun lain.');
    }
    await ApiService().post(
      '/auth/signature',
      body: {'signature_url': storagePath},
      idToken: await user.getIdToken(),
    );
  }

  /// Get user role from ID token claims.
  Future<String?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    var tokenResult = await user.getIdTokenResult();
    var role = tokenResult.claims?['role'] as String?;
    if (role == null) {
      tokenResult = await user.getIdTokenResult(true);
      role = tokenResult.claims?['role'] as String?;
    }
    return role;
  }

  Future<void> setPin(String pin) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Pengguna belum masuk.');
    await ApiService().post(
      '/auth/pin',
      body: {'pin': pin},
      idToken: await user.getIdToken(),
    );
  }

  Future<String> signSubmission({
    required String submissionId,
    required String pin,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Pengguna belum masuk.');
    final result = await ApiService().post(
      '/submissions/$submissionId/sign',
      body: {'pin': pin},
      idToken: await user.getIdToken(),
    );
    final status = result['status'];
    if (status is! String) {
      throw const ApiException('Server tidak mengembalikan status pengajuan.');
    }
    return status;
  }

  Future<void> verifySubmission({
    required String submissionId,
    required String decision,
    required String pin,
    String? note,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Pengguna belum masuk.');
    await ApiService().post(
      '/submissions/$submissionId/verify',
      body: {
        'decision': decision,
        'pin': pin,
        if (note != null && note.trim().isNotEmpty) 'catatan': note.trim(),
      },
      idToken: await user.getIdToken(),
    );
  }

  Future<void> createHeadAccount({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String? idNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Pengguna belum masuk.');
    await ApiService().post(
      '/users',
      idToken: await user.getIdToken(),
      body: {
        'email': email,
        'password': password,
        'nama': name,
        'phone': phone,
        'role': role,
        'id_number': idNumber,
      },
    );
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
