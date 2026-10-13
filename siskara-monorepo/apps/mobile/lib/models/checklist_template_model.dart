/// Checklist template and item models for dynamic form rendering.

class ChecklistTemplateModel {
  final String id;
  final String modaTransportasi;
  final String namaTemplate;
  final int versi;
  final bool isActive;

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
  final String id;
  final String templateId;
  final String kategori;
  final String label;
  final String tipeInput; // binary | three_level | multi_choice | numeric | text
  final dynamic nilaiGagal; // String or List<String>
  final bool autoRejectOnFail;
  final bool requiresMediaOnFail;
  final int order;

  const ChecklistTemplateItemModel({
    required this.id,
    required this.templateId,
    required this.kategori,
    required this.label,
    required this.tipeInput,
    required this.nilaiGagal,
    required this.autoRejectOnFail,
    required this.requiresMediaOnFail,
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
      nilaiGagal: map['nilai_gagal'],
      autoRejectOnFail: map['auto_reject_on_fail'] ?? false,
      requiresMediaOnFail: map['requires_media_on_fail'] ?? false,
      order: map['order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'template_id': templateId,
      'kategori': kategori,
      'label': label,
      'tipe_input': tipeInput,
      'nilai_gagal': nilaiGagal,
      'auto_reject_on_fail': autoRejectOnFail,
      'requires_media_on_fail': requiresMediaOnFail,
      'order': order,
    };
  }

  /// Check if a given answer value counts as a failure.
  bool isFailValue(String answerValue) {
    if (nilaiGagal is String) {
      return answerValue == nilaiGagal;
    }
    if (nilaiGagal is List) {
      return (nilaiGagal as List).contains(answerValue);
    }
    return false;
  }
}
