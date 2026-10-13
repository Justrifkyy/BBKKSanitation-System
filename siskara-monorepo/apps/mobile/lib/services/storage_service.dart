import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/constants.dart';

/// Handles Firebase Storage operations for media uploads.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a signature image for a user.
  Future<String> uploadSignature(String userId, File file) async {
    final ref = _storage
        .ref()
        .child(AppConstants.storageSignatures)
        .child(userId)
        .child('signature.png');

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// Upload evidence media (photo/video) for a submission answer.
  Future<String> uploadEvidenceMedia({
    required String submissionId,
    required String answerId,
    required String fileName,
    required File file,
  }) async {
    final ref = _storage
        .ref()
        .child(AppConstants.storageSubmissions)
        .child(submissionId)
        .child('answers')
        .child(answerId)
        .child(fileName);

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// Get the download URL for a generated document.
  Future<String?> getDocumentUrl(String submissionId) async {
    try {
      final ref = _storage
          .ref()
          .child(AppConstants.storageDocuments)
          .child(submissionId)
          .child('result.pdf');
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}
