import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/constants.dart';
import '../models/submission_model.dart';
import '../models/checklist_template_model.dart';

/// Handles Firestore operations for submissions and checklist data.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: AppConstants.firebaseDatabaseId,
  );

  // ─── Checklist Templates ────────────────────────────────

  /// Get the active template for a given transport mode.
  Future<ChecklistTemplateModel?> getActiveTemplate(
      String modaTransportasi) async {
    final snapshot = await _firestore
        .collection(AppConstants.colChecklistTemplates)
        .where('moda_transportasi', isEqualTo: modaTransportasi)
        .where('is_active', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return ChecklistTemplateModel.fromMap(doc.data(), doc.id);
  }

  /// Get a template by ID, including templates that are no longer active.
  Future<ChecklistTemplateModel?> getTemplate(String templateId) async {
    final doc = await _firestore
        .collection(AppConstants.colChecklistTemplates)
        .doc(templateId)
        .get();
    if (!doc.exists) return null;
    return ChecklistTemplateModel.fromMap(doc.data()!, doc.id);
  }

  /// Get all items for a template.
  Future<List<ChecklistTemplateItemModel>> getTemplateItems(
      String templateId) async {
    final snapshot = await _firestore
        .collection(AppConstants.colChecklistTemplates)
        .doc(templateId)
        .collection(AppConstants.colChecklistTemplateItems)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((doc) => ChecklistTemplateItemModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ─── Submissions ────────────────────────────────────────

  /// Create a new submission.
  Future<String> createSubmission(SubmissionModel submission) async {
    final docRef = await _firestore
        .collection(AppConstants.colSubmissions)
        .add(submission.toMap());
    return docRef.id;
  }

  Future<void> createSubmissionWithId(
    String submissionId,
    SubmissionModel submission, {
    bool isNew = true,
  }) async {
    final submissionRef =
        _firestore.collection(AppConstants.colSubmissions).doc(submissionId);
    if (isNew) {
      await submissionRef.set(submission.toMap());
    } else {
      await submissionRef.update({
        'data_umum': submission.dataUmum,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  String newSubmissionId() =>
      _firestore.collection(AppConstants.colSubmissions).doc().id;

  Future<void> saveAnswerForItem({
    required String submissionId,
    required String itemId,
    required Map<String, dynamic> answer,
  }) async {
    await _firestore
        .collection(AppConstants.colSubmissions)
        .doc(submissionId)
        .collection(AppConstants.colSubmissionAnswers)
        .doc(itemId)
        .set(answer, SetOptions(merge: true));
  }

  /// Update a submission.
  Future<void> updateSubmission(
      String submissionId, Map<String, dynamic> data) async {
    data['updated_at'] = FieldValue.serverTimestamp();
    await _firestore
        .collection(AppConstants.colSubmissions)
        .doc(submissionId)
        .update(data);
  }

  /// Get a single submission.
  Future<SubmissionModel?> getSubmission(String submissionId) async {
    final doc = await _firestore
        .collection(AppConstants.colSubmissions)
        .doc(submissionId)
        .get();

    if (!doc.exists) return null;
    return SubmissionModel.fromMap(doc.data()!, doc.id);
  }

  /// Stream submissions for a specific user (kepala roles).
  Stream<List<SubmissionModel>> streamUserSubmissions(
    String userId, {
    bool reviewedByUser = false,
  }) {
    return _firestore
        .collection(AppConstants.colSubmissions)
        .where(
          reviewedByUser ? 'verifikator_id' : 'pengisi_id',
          isEqualTo: userId,
        )
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SubmissionModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream submissions pending review (for staf_bbkk).
  Stream<List<SubmissionModel>> streamPendingSubmissions() {
    return _firestore
        .collection(AppConstants.colSubmissions)
        .where('status', isEqualTo: AppConstants.statusMenungguVerifikasi)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SubmissionModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── Submission Answers ─────────────────────────────────

  /// Save a batch of answers for a submission.
  Future<void> saveAnswers(
    String submissionId,
    List<SubmissionAnswerModel> answers,
  ) async {
    final batch = _firestore.batch();
    final answersRef = _firestore
        .collection(AppConstants.colSubmissions)
        .doc(submissionId)
        .collection(AppConstants.colSubmissionAnswers);

    for (final answer in answers) {
      final docRef = answersRef.doc();
      batch.set(docRef, answer.toMap());
    }

    await batch.commit();
  }

  /// Get all answers for a submission.
  Future<List<SubmissionAnswerModel>> getSubmissionAnswers(
      String submissionId) async {
    final snapshot = await _firestore
        .collection(AppConstants.colSubmissions)
        .doc(submissionId)
        .collection(AppConstants.colSubmissionAnswers)
        .get();

    return snapshot.docs
        .map((doc) => SubmissionAnswerModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ─── Media ──────────────────────────────────────────────

  /// Get all media for an answer.
  Future<List<SubmissionAnswerMediaModel>> getAnswerMedia(
    String submissionId,
    String answerId,
  ) async {
    final snapshot = await _firestore
        .collection(AppConstants.colSubmissions)
        .doc(submissionId)
        .collection(AppConstants.colSubmissionAnswers)
        .doc(answerId)
        .collection(AppConstants.colSubmissionAnswerMedia)
        .get();

    return snapshot.docs
        .map((doc) => SubmissionAnswerMediaModel.fromMap(doc.data(), doc.id))
        .toList();
  }
}
