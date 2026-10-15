import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SubmissionDraftData {
  SubmissionDraftData({
    this.draftId,
    required this.userId,
    required this.transportMode,
    required this.generalData,
    required this.answers,
    required this.reasons,
    required this.evidencePaths,
    required this.evidenceGps,
    required this.evidenceTimes,
    this.confirmsAccuracy = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory SubmissionDraftData.fromJson(Map<String, dynamic> json) {
    return SubmissionDraftData(
      draftId: json['draft_id'] as String?,
      userId: (json['user_id'] as String?) ?? '',
      transportMode: (json['transport_mode'] as String?) ?? 'kapal',
      generalData: Map<String, dynamic>.from(json['general_data'] ?? {}),
      answers: Map<String, String>.from(json['answers'] ?? {}),
      reasons: Map<String, String>.from(json['reasons'] ?? {}),
      evidencePaths: Map<String, String>.from(json['evidence_paths'] ?? {}),
      evidenceGps: (json['evidence_gps'] as Map?)?.map(
            (k, v) => MapEntry(
              k.toString(),
              Map<String, double>.from(
                (v as Map).map((k2, v2) => MapEntry(k2.toString(), (v2 as num).toDouble())),
              ),
            ),
          ) ??
          {},
      evidenceTimes: Map<String, String>.from(json['evidence_times'] ?? {}),
      confirmsAccuracy: json['confirms_accuracy'] == true,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  final String? draftId;
  final String userId;
  final String transportMode;
  final Map<String, dynamic> generalData;
  final Map<String, String> answers;
  final Map<String, String> reasons;
  final Map<String, String> evidencePaths;
  final Map<String, Map<String, double>> evidenceGps;
  final Map<String, String> evidenceTimes;
  final bool confirmsAccuracy;
  final DateTime updatedAt;

  bool get isEmpty =>
      generalData.values.every((v) => v == null || v.toString().trim().isEmpty) &&
      answers.isEmpty;

  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toJson() => {
        'draft_id': draftId,
        'user_id': userId,
        'transport_mode': transportMode,
        'general_data': generalData,
        'answers': answers,
        'reasons': reasons,
        'evidence_paths': evidencePaths,
        'evidence_gps': evidenceGps,
        'evidence_times': evidenceTimes,
        'confirms_accuracy': confirmsAccuracy,
        'updated_at': updatedAt.toIso8601String(),
      };
}

class SubmissionDraftStorage {
  static Future<File> _getFile(String userId) async {
    final dir = await getApplicationDocumentsDirectory();
    final cleanId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File('${dir.path}/arjuna_draft_$cleanId.json');
  }

  static Future<void> save(SubmissionDraftData draft) async {
    try {
      final file = await _getFile(draft.userId);
      await file.writeAsString(jsonEncode(draft.toJson()), flush: true);
    } catch (e) {
      // Ignore background write errors to avoid crashing UI
    }
  }

  static Future<SubmissionDraftData?> load(String userId) async {
    try {
      final file = await _getFile(userId);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final json = jsonDecode(content);
      if (json is Map<String, dynamic>) {
        final draft = SubmissionDraftData.fromJson(json);
        if (draft.userId == userId && draft.isNotEmpty) {
          return draft;
        }
      }
    } catch (_) {
      // Ignore corrupt file
    }
    return null;
  }

  static Future<void> clear(String userId) async {
    try {
      final file = await _getFile(userId);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore delete failure
    }
  }
}
