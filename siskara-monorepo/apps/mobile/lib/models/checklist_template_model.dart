// ignore: dangling_library_doc_comments
/// Checklist template and item models for dynamic form rendering.

class ChecklistTemplateModel {

  const ChecklistTemplateModel({
    required this.id,
    required this.modaTransportasi,
    required this.namaTemplate,
    required this.versi,
    required this.isActive,
  });

  factory ChecklistTemplateModel.fromMap(
      Map<String, dynamic> map, String docId) {
    return ChecklistTemplateModel(
      id: docId,
      modaTransportasi: map['moda_transportasi'] ?? '',
      namaTemplate: map['nama_template'] ?? '',
      versi: map['versi'] ?? 1,
      isActive: map['is_active'] ?? false,
    );
  }
  final String id;
  final String modaTransportasi;
  final String namaTemplate;
  final int versi;
  final bool isActive;

  Map<String, dynamic> toMap() {
    return {
      'moda_transportasi': modaTransportasi,
      'nama_template': namaTemplate,
      'versi': versi,
      'is_active': isActive,
    };
  }
}

class ChecklistTemplateItemModel {

  const ChecklistTemplateItemModel({
    required this.id,
    required this.templateId,
    required this.kategori,
    required this.label,
    required this.tipeInput,
    this.opsiJawaban = const [],
    required this.nilaiGagal,
    this.nilaiPerluAlasan,
    this.nilaiPerluMedia,
    required this.autoRejectOnFail,
    required this.requiresMediaOnFail,
    this.wajibDiisi = true,
    this.wajibJika,
    required this.order,
  });

  factory ChecklistTemplateItemModel.fromMap(
      Map<String, dynamic> map, String docId) {
    return ChecklistTemplateItemModel(
      id: docId,
      templateId: map['template_id'] ?? '',
      kategori: map['kategori'] ?? '',
      label: map['label'] ?? '',
      tipeInput: map['tipe_input'] ?? 'binary',
      opsiJawaban: (map['opsi_jawaban'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          (map['condition_options'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      nilaiGagal: map['nilai_gagal'],
      nilaiPerluAlasan: map['nilai_perlu_alasan'],
      nilaiPerluMedia: map['nilai_perlu_media'],
      autoRejectOnFail: map['auto_reject_on_fail'] ?? false,
      requiresMediaOnFail: map['requires_media_on_fail'] ?? false,
      wajibDiisi: map['wajib_diisi'] ?? true,
      wajibJika: map['wajib_jika'] == null
          ? null
          : Map<String, dynamic>.from(map['wajib_jika'] as Map),
      order: map['order'] ?? 0,
    );
  }
  final String id;
  final String templateId;
  final String kategori;
  final String label;
  final String tipeInput; // binary | three_level | multi_choice | numeric | text
  final List<String> opsiJawaban;
  final dynamic nilaiGagal; // String or List<String>
  final dynamic nilaiPerluAlasan;
  final dynamic nilaiPerluMedia;
  final bool autoRejectOnFail;
  final bool requiresMediaOnFail;
  final bool wajibDiisi;
  final Map<String, dynamic>? wajibJika;
  final int order;

  Map<String, dynamic> toMap() {
    return {
      'template_id': templateId,
      'kategori': kategori,
      'label': label,
      'tipe_input': tipeInput,
      'opsi_jawaban': opsiJawaban,
      'nilai_gagal': nilaiGagal,
      'nilai_perlu_alasan': nilaiPerluAlasan,
      'nilai_perlu_media': nilaiPerluMedia,
      'auto_reject_on_fail': autoRejectOnFail,
      'requires_media_on_fail': requiresMediaOnFail,
      'wajib_diisi': wajibDiisi,
      'wajib_jika': wajibJika,
      'order': order,
    };
  }

  bool isRequiredFor(Map<String, String> answers) {
    if (wajibDiisi) return true;
    final condition = wajibJika;
    if (condition == null) return false;
    final anyConditions = condition['any'];
    if (anyConditions is List) {
      return anyConditions.any((entry) {
        if (entry is! Map) return false;
        return answers[entry['item_id']] == entry['nilai'];
      });
    }
    return answers[condition['item_id']] == condition['nilai'];
  }

  bool requiresReasonFor(String answerValue) =>
      _contains(nilaiPerluAlasan, answerValue) ||
      (nilaiPerluAlasan == null && isFailValue(answerValue));

  bool requiresMediaFor(String answerValue) =>
      _contains(nilaiPerluMedia, answerValue) ||
      ((nilaiPerluMedia == null || requiresMediaOnFail) &&
          isFailValue(answerValue));

  /// Check if a given answer value counts as a failure.
  bool isFailValue(String answerValue) {
    return _contains(nilaiGagal, answerValue);
  }

  bool _contains(dynamic values, String answerValue) {
    if (values is String) return answerValue == values;
    if (values is List) return values.contains(answerValue);
    return false;
  }
}
