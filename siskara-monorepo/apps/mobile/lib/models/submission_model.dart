/// Submission model matching the Firestore `submissions` collection schema.
class SubmissionModel {
  final String id;
  final String modaTransportasi;
  final String templateId;
  final Map<String, dynamic> dataUmum;
  final String pengisiId;
  final String? verifikatorId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubmissionModel({
    required this.id,
    required this.modaTransportasi,
    required this.templateId,
    required this.dataUmum,
    required this.pengisiId,
    this.verifikatorId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubmissionModel.fromMap(Map<String, dynamic> map, String docId) {
    return SubmissionModel(
      id: docId,
      modaTransportasi: map['moda_transportasi'] ?? '',
      templateId: map['template_id'] ?? '',
      dataUmum: Map<String, dynamic>.from(map['data_umum'] ?? {}),
      pengisiId: map['pengisi_id'] ?? '',
      verifikatorId: map['verifikator_id'],
      status: map['status'] ?? 'draft',
      createdAt: (map['created_at'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'moda_transportasi': modaTransportasi,
      'template_id': templateId,
      'data_umum': dataUmum,
      'pengisi_id': pengisiId,
      'verifikator_id': verifikatorId,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  bool get isDraft => status == 'draft';
  bool get isAutoRejected => status == 'ditolak_otomatis';
  bool get isPendingReview => status == 'menunggu_verifikasi_staf';
  bool get isRejectedByStaf => status == 'ditolak_staf';
  bool get isFinal => status == 'final';
  bool get isKapal => modaTransportasi == 'kapal';
  bool get isPesawat => modaTransportasi == 'pesawat';

  String get documentType => isKapal ? 'phqc' : 'berkas_verifikasi';

  SubmissionModel copyWith({
    Map<String, dynamic>? dataUmum,
    String? verifikatorId,
    String? status,
    DateTime? updatedAt,
  }) {
    return SubmissionModel(
      id: id,
      modaTransportasi: modaTransportasi,
      templateId: templateId,
      dataUmum: dataUmum ?? this.dataUmum,
      pengisiId: pengisiId,
      verifikatorId: verifikatorId ?? this.verifikatorId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Answer for a single checklist item within a submission.
class SubmissionAnswerModel {
  final String id;
  final String submissionId;
  final String templateItemId;
  final String nilaiJawaban;
  final String? alasan;
  final bool statusGagal;

  const SubmissionAnswerModel({
    required this.id,
    required this.submissionId,
    required this.templateItemId,
    required this.nilaiJawaban,
    this.alasan,
    required this.statusGagal,
  });

  factory SubmissionAnswerModel.fromMap(Map<String, dynamic> map, String docId) {
    return SubmissionAnswerModel(
      id: docId,
      submissionId: map['submission_id'] ?? '',
      templateItemId: map['template_item_id'] ?? '',
      nilaiJawaban: map['nilai_jawaban'] ?? '',
      alasan: map['alasan'],
      statusGagal: map['status_gagal'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'submission_id': submissionId,
      'template_item_id': templateItemId,
      'nilai_jawaban': nilaiJawaban,
      'alasan': alasan,
      'status_gagal': statusGagal,
    };
  }
}

/// Media evidence attached to a submission answer.
class SubmissionAnswerMediaModel {
  final String id;
  final String answerId;
  final String tipe; // 'foto' | 'video'
  final String fileUrl;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;

  const SubmissionAnswerMediaModel({
    required this.id,
    required this.answerId,
    required this.tipe,
    required this.fileUrl,
    this.latitude,
    this.longitude,
    required this.timestamp,
  });

  factory SubmissionAnswerMediaModel.fromMap(
      Map<String, dynamic> map, String docId) {
    return SubmissionAnswerMediaModel(
      id: docId,
      answerId: map['answer_id'] ?? '',
      tipe: map['tipe'] ?? 'foto',
      fileUrl: map['file_url'] ?? '',
      latitude: map['gps']?.latitude,
      longitude: map['gps']?.longitude,
      timestamp: (map['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'answer_id': answerId,
      'tipe': tipe,
      'file_url': fileUrl,
      'gps': (latitude != null && longitude != null)
          ? {'latitude': latitude, 'longitude': longitude}
          : null,
      'timestamp': timestamp,
    };
  }
}
