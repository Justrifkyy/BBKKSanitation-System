import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../core/error_message.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/interactive_photo_viewer.dart';
import '../../../models/checklist_template_model.dart';
import '../../../models/submission_model.dart';
import '../../../models/user_model.dart';
import '../../../services/storage_service.dart';
import '../../../state/auth_state.dart';
import '../../../state/submission_state.dart';
import '../services/submission_draft_storage.dart';

class SubmissionFormScreen extends ConsumerStatefulWidget {
  const SubmissionFormScreen({super.key, this.draftId});

  final String? draftId;

  @override
  ConsumerState<SubmissionFormScreen> createState() =>
      _SubmissionFormScreenState();
}

class _SubmissionFormScreenState extends ConsumerState<SubmissionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _answers = {};
  final Map<String, XFile> _evidence = {};
  final Map<String, Position> _positions = {};
  final Map<String, DateTime> _captureTimes = {};
  final Map<String, SubmissionAnswerMediaModel> _savedEvidence = {};
  String? _draftId;
  Future<_DraftFormData>? _draftFuture;
  bool _isSubmitting = false;
  String _submittingStatus = '';
  bool _confirmsAccuracy = false;
  Timer? _autoSaveDebounce;
  bool _hasRestoredLocalDraft = false;
  String? _restoredDraftTime;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    if (widget.draftId != null) {
      _draftFuture = _loadDraft(widget.draftId!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreLocalDraft();
      });
    }
  }

  @override
  void didUpdateWidget(SubmissionFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draftId != oldWidget.draftId) {
      _draftId = widget.draftId;
      if (widget.draftId != null) {
        setState(() {
          _draftFuture = _loadDraft(widget.draftId!);
        });
      } else {
        _restoreLocalDraft();
      }
    }
  }

  static const _shipFields = <_GeneralField>[
    _GeneralField('nama_kapal', 'Nama kapal'),
    _GeneralField('jenis_kapal', 'Jenis kapal'),
    _GeneralField('besar_kapal_grt', 'Besar kapal (GRT)', numeric: true),
    _GeneralField('bendera', 'Bendera'),
    _GeneralField('nomor_imo', 'Nomor IMO', fullWidth: true),
    _GeneralField('pelabuhan_asal', 'Pelabuhan asal', fullWidth: true),
    _GeneralField(
      'nama_pemilik_agen',
      'Nama pemilik / agen',
      fullWidth: false,
    ),
    _GeneralField(
      'tujuan_pelabuhan_berikutnya',
      'Tujuan pelabuhan berikutnya',
      required: false,
      fullWidth: false,
    ),
    _GeneralField(
      'tanggal_jam_tiba',
      'Tanggal dan jam tiba',
      hint: 'Kedatangan',
      dateTime: true,
      fullWidth: false,
    ),
    _GeneralField(
      'tanggal_jam_berangkat',
      'Tanggal dan jam berangkat',
      required: false,
      hint: 'Keberangkatan',
      dateTime: true,
      fullWidth: false,
    ),
    _GeneralField(
      'diperiksa_tanggal_jam',
      'Tanggal dan jam diperiksa',
      hint: 'Waktu diperiksa',
      dateTime: true,
      fullWidth: false,
    ),
    _GeneralField('lokasi_sandar', 'Lokasi sandar', fullWidth: false),
    _GeneralField(
      'jumlah_awak_kapal',
      'Jumlah awak kapal',
      numeric: true,
      wholeNumber: true,
    ),
    _GeneralField(
      'jumlah_penumpang',
      'Jumlah penumpang',
      required: false,
      numeric: true,
      wholeNumber: true,
    ),
  ];

  static const _aircraftFields = <_GeneralField>[
    _GeneralField('pemilik_atau_penyelenggara', 'Pemilik / penyelenggara'),
    _GeneralField('nomor_penerbangan', 'Nomor penerbangan'),
    _GeneralField(
      'tanda_kebangsaan_dan_pendaftaran',
      'Tanda kebangsaan dan pendaftaran',
    ),
    _GeneralField(
      'tanggal_jam',
      'Tanggal dan jam penerbangan',
      hint: 'Contoh: 13-10-2026 08:30',
      dateTime: true,
    ),
    _GeneralField('berangkat_dari', 'Berangkat dari'),
    _GeneralField('tujuan', 'Tujuan'),
  ];

  TextEditingController _controller(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  Future<_DraftFormData> _loadDraft(String draftId) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) throw StateError('Sesi pengguna berakhir.');

    final firestore = ref.read(firestoreServiceProvider);
    final submission = await firestore.getSubmission(draftId);
    if (submission == null ||
        submission.pengisiId != user.id ||
        !submission.isDraft) {
      throw StateError('Draft tidak ditemukan atau tidak dapat dilanjutkan.');
    }
    final expectedMode = user.role == AppConstants.roleKepalaKapal
        ? AppConstants.modaKapal
        : AppConstants.modaPesawat;
    if (submission.modaTransportasi != expectedMode) {
      throw StateError('Draft ini tidak sesuai dengan jenis akun Anda.');
    }

    final template = await firestore.getTemplate(submission.templateId);
    if (template == null) {
      throw StateError('Template untuk draft ini tidak lagi tersedia.');
    }
    final items = await firestore.getTemplateItems(template.id);
    List<SubmissionAnswerModel> answers = [];
    try {
      answers = await firestore.getSubmissionAnswers(draftId);
    } catch (_) {}

    final mediaEntries = <MapEntry<String, SubmissionAnswerMediaModel>>[];
    for (final answer in answers) {
      try {
        final mediaList =
            await firestore.getAnswerMedia(draftId, answer.templateItemId);
        if (mediaList.isNotEmpty) {
          mediaList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          mediaEntries.add(MapEntry(answer.templateItemId, mediaList.first));
        }
      } catch (_) {}
    }

    for (final field in _fieldsFor(user.role)) {
      final value = submission.dataUmum[field.name];
      if (value != null) _controller(field.name).text = value.toString();
    }
    for (final answer in answers) {
      if (answer.nilaiJawaban.isNotEmpty) {
        _answers[answer.templateItemId] = answer.nilaiJawaban;
        _controller('answer_${answer.templateItemId}').text =
            answer.nilaiJawaban;
      }
      final reason = answer.alasan;
      if (reason != null && reason.isNotEmpty) {
        _controller('reason_${answer.templateItemId}').text = reason;
      }
    }
    _savedEvidence.addEntries(mediaEntries);

    // Merge any local edits or photos
    try {
      final localDraft = await SubmissionDraftStorage.load(user.id);
      if (localDraft != null &&
          (localDraft.draftId == draftId || localDraft.draftId == null)) {
        for (final entry in localDraft.generalData.entries) {
          if (entry.value != null && entry.value.toString().isNotEmpty) {
            _controller(entry.key).text = entry.value.toString();
          }
        }
        for (final entry in localDraft.answers.entries) {
          if (entry.value.isNotEmpty) {
            _answers[entry.key] = entry.value;
            _controller('answer_${entry.key}').text = entry.value;
          }
        }
        for (final entry in localDraft.reasons.entries) {
          if (entry.value.isNotEmpty) {
            _controller('reason_${entry.key}').text = entry.value;
          }
        }
        if (localDraft.confirmsAccuracy) {
          _confirmsAccuracy = true;
        }
        for (final entry in localDraft.evidencePaths.entries) {
          final file = File(entry.value);
          if (file.existsSync() && !_evidence.containsKey(entry.key)) {
            _evidence[entry.key] = XFile(entry.value);
            final gps = localDraft.evidenceGps[entry.key];
            if (gps != null && gps['lat'] != null && gps['lng'] != null) {
              _positions[entry.key] = Position(
                latitude: gps['lat']!,
                longitude: gps['lng']!,
                timestamp: DateTime.now(),
                accuracy: 5.0,
                altitude: 0.0,
                altitudeAccuracy: 0.0,
                heading: 0.0,
                headingAccuracy: 0.0,
                speed: 0.0,
                speedAccuracy: 0.0,
              );
            }
            final timeStr = localDraft.evidenceTimes[entry.key];
            if (timeStr != null) {
              _captureTimes[entry.key] =
                  DateTime.tryParse(timeStr) ?? DateTime.now();
            }
          }
        }
      }
    } catch (_) {}

    _draftId = draftId;
    _hasRestoredLocalDraft = true;
    _restoredDraftTime = DateFormat('dd/MM/yyyy HH:mm')
        .format(submission.updatedAt);
    _scheduleAutoSave();
    return _DraftFormData(template: template, items: items);
  }

  Future<void> _restoreLocalDraft() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || !mounted || _hasRestoredLocalDraft) return;

    final draft = await SubmissionDraftStorage.load(user.id);
    if (draft == null || !mounted || draft.isEmpty) return;

    setState(() {
      _hasRestoredLocalDraft = true;
      _draftId = draft.draftId;
      _confirmsAccuracy = draft.confirmsAccuracy;
      _restoredDraftTime =
          DateFormat('dd/MM/yyyy HH:mm').format(draft.updatedAt);

      for (final entry in draft.generalData.entries) {
        if (entry.value != null && entry.value.toString().isNotEmpty) {
          _controller(entry.key).text = entry.value.toString();
        }
      }

      for (final entry in draft.answers.entries) {
        if (entry.value.isNotEmpty) {
          _answers[entry.key] = entry.value;
          _controller('answer_${entry.key}').text = entry.value;
        }
      }

      for (final entry in draft.reasons.entries) {
        if (entry.value.isNotEmpty) {
          _controller('reason_${entry.key}').text = entry.value;
        }
      }

      for (final entry in draft.evidencePaths.entries) {
        final file = File(entry.value);
        if (file.existsSync()) {
          _evidence[entry.key] = XFile(entry.value);
          final gps = draft.evidenceGps[entry.key];
          if (gps != null && gps['lat'] != null && gps['lng'] != null) {
            _positions[entry.key] = Position(
              latitude: gps['lat']!,
              longitude: gps['lng']!,
              timestamp: DateTime.now(),
              accuracy: 5.0,
              altitude: 0.0,
              altitudeAccuracy: 0.0,
              heading: 0.0,
              headingAccuracy: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
            );
          }
          final timeStr = draft.evidenceTimes[entry.key];
          if (timeStr != null) {
            _captureTimes[entry.key] =
                DateTime.tryParse(timeStr) ?? DateTime.now();
          }
        }
      }
    });
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 500), () {
      _persistLocalDraft();
    });
  }

  Future<void> _persistLocalDraft() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final generalData = _collectGeneralData(user.role);
    final reasons = <String, String>{};
    for (final key in _controllers.keys) {
      if (key.startsWith('reason_')) {
        final itemId = key.substring(7);
        final text = _controllers[key]?.text.trim() ?? '';
        if (text.isNotEmpty) reasons[itemId] = text;
      }
    }

    final evidencePaths = <String, String>{};
    final evidenceGps = <String, Map<String, double>>{};
    final evidenceTimes = <String, String>{};

    for (final entry in _evidence.entries) {
      evidencePaths[entry.key] = entry.value.path;
      final pos = _positions[entry.key];
      if (pos != null) {
        evidenceGps[entry.key] = {'lat': pos.latitude, 'lng': pos.longitude};
      }
      final time = _captureTimes[entry.key];
      if (time != null) {
        evidenceTimes[entry.key] = time.toIso8601String();
      }
    }

    final draft = SubmissionDraftData(
      draftId: _draftId,
      userId: user.id,
      transportMode: user.role == AppConstants.roleKepalaKapal
          ? AppConstants.modaKapal
          : AppConstants.modaPesawat,
      generalData: generalData,
      answers: Map<String, String>.from(_answers),
      reasons: reasons,
      evidencePaths: evidencePaths,
      evidenceGps: evidenceGps,
      evidenceTimes: evidenceTimes,
      confirmsAccuracy: _confirmsAccuracy,
      updatedAt: DateTime.now(),
    );

    if (draft.isNotEmpty) {
      await SubmissionDraftStorage.save(draft);
    }
  }

  Future<void> _resetAndStartFresh() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mulai Pengajuan Baru?'),
        content: const Text(
          'Draf pengisian saat ini yang belum terkirim akan dikosongkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: SiskaraTheme.error,
            ),
            child: const Text('Mulai Baru'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user != null) {
        await SubmissionDraftStorage.clear(user.id);
      }
      if (!mounted) return;
      setState(() {
        _draftId = null;
        _hasRestoredLocalDraft = false;
        _restoredDraftTime = null;
        _confirmsAccuracy = false;
        for (final controller in _controllers.values) {
          controller.clear();
        }
        _answers.clear();
        _evidence.clear();
        _positions.clear();
        _captureTimes.clear();
        _savedEvidence.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formulir berhasil dikosongkan.')),
      );
      if (widget.draftId != null && mounted) {
        context.go('/submission');
      }
    }
  }

  Widget _buildRestoredDraftBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3D39).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2DD4BF).withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            size: 20,
            color: Color(0xFF0D9488),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Melanjutkan Draf Pengisian',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F3D39),
                  ),
                ),
                Text(
                  _restoredDraftTime != null
                      ? 'Tersimpan otomatis • $_restoredDraftTime'
                      : 'Data yang Anda isi sebelumnya telah dipulihkan.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SiskaraTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _resetAndStartFresh,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Mulai Baru',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB93838),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _persistLocalDraft();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<_GeneralField> _fieldsFor(String role) =>
      role == AppConstants.roleKepalaKapal ? _shipFields : _aircraftFields;

  Future<void> _captureEvidence(ChecklistTemplateItemModel item) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw StateError('Aktifkan layanan lokasi untuk mengambil bukti.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Izin lokasi diperlukan untuk mencatat bukti.');
      }

      final media = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (media == null) return;

      final captureTime = DateTime.now();
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _evidence[item.id] = media;
        _positions[item.id] = position;
        _captureTimes[item.id] = captureTime;
      });
      _scheduleAutoSave();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bukti foto tidak dapat diambil: ${ErrorMessage.from(error)}',
          ),
          backgroundColor: SiskaraTheme.error,
        ),
      );
    }
  }

  Future<String?> _requestPin() async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi tanda tangan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan PIN 6 angka untuk mengesahkan deklarasi.'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'PIN',
                counterText: '',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (RegExp(r'^\d{6}$').hasMatch(controller.text)) {
                Navigator.pop(dialogContext, controller.text);
              }
            },
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
    controller.dispose();
    return pin;
  }

  Future<void> _saveDraft({
    required ChecklistTemplateModel template,
    required List<ChecklistTemplateItemModel> items,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      _showError('Sesi pengguna berakhir. Silakan masuk kembali.');
      return;
    }

    setState(() => _isSubmitting = true);
    var stage = 'menyimpan draft';
    try {
      final firestore = ref.read(firestoreServiceProvider);
      final storage = StorageService();
      final isNew = _draftId == null;
      final submissionId = _draftId ?? firestore.newSubmissionId();
      _draftId = submissionId;
      final now = DateTime.now();
      final submission = SubmissionModel(
        id: submissionId,
        modaTransportasi: template.modaTransportasi,
        templateId: template.id,
        dataUmum: _collectGeneralData(user.role),
        pengisiId: user.id,
        status: AppConstants.statusDraft,
        createdAt: now,
        updatedAt: now,
      );
      await firestore.createSubmissionWithId(
        submissionId,
        submission,
        isNew: isNew,
      );

      stage = 'menyimpan dokumentasi checklist';
      if (mounted) setState(() => _submittingStatus = 'Menyimpan draft checklist...');
      await Future.wait(
        items.map((item) {
          final reason = _controller('reason_${item.id}').text.trim();
          return firestore.saveAnswerForItem(
            submissionId: submissionId,
            itemId: item.id,
            answer: {
              'submission_id': submissionId,
              'template_item_id': item.id,
              'kategori': item.kategori,
              'label': item.label,
              'nilai_jawaban': 'dilaporkan',
              'alasan': reason.isEmpty ? null : reason,
              'status_gagal': false,
            },
          );
        }),
      );

      final draftUploads = <Future<void>>[];
      for (final item in items) {
        final evidence = _evidence[item.id];
        final position = _positions[item.id];
        if (evidence != null && position != null) {
          draftUploads.add(
            _uploadEvidenceDirect(
              submissionId: submissionId,
              item: item,
              evidence: evidence,
              position: position,
              timestamp: _captureTimes[item.id] ?? now,
              storage: storage,
            ),
          );
        }
      }
      if (draftUploads.isNotEmpty) {
        stage = 'mengunggah foto bukti';
        if (mounted) {
          setState(
            () => _submittingStatus = 'Mengunggah ${draftUploads.length} foto bukti...',
          );
        }
        await Future.wait(draftUploads);
      }
      await _persistLocalDraft();
      ref.invalidate(userSubmissionsProvider);
      if (!mounted) return;
      context.go('/history');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft berhasil disimpan.')),
      );
    } catch (error) {
      if (mounted) {
        _showError(
          'Gagal saat $stage. ${ErrorMessage.from(error)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingStatus = '';
        });
      }
    }
  }

  Map<String, dynamic> _collectGeneralData(String role) => {
        for (final field in _fieldsFor(role))
          if (_controller(field.name).text.trim().isNotEmpty)
            field.name: field.numeric
                ? _parseNumber(_controller(field.name).text.trim()) ??
                    _controller(field.name).text.trim()
                : _controller(field.name).text.trim(),
      };

  Future<void> _uploadEvidenceDirect({
    required String submissionId,
    required ChecklistTemplateItemModel item,
    required XFile evidence,
    required Position position,
    required DateTime timestamp,
    required StorageService storage,
  }) async {
    final extension = evidence.path.split('.').last.toLowerCase();
    final fileLength = await File(evidence.path).length();
    const maxSize = AppConstants.maxPhotoSizeKb * 1024;
    if (fileLength > maxSize) {
      throw StateError(
        'Ukuran foto pada ${item.label} maksimal ${AppConstants.maxPhotoSizeKb} KB.',
      );
    }
    final mediaType = extension == 'jpg' || extension == 'jpeg'
        ? 'image/jpeg'
        : 'image/$extension';
    final storagePath = await storage.uploadEvidenceMedia(
      submissionId: submissionId,
      answerId: item.id,
      file: File(evidence.path),
      contentType: mediaType,
    );
    await storage.completeEvidenceUpload(
      storagePath: storagePath,
      type: 'foto',
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: timestamp,
    );
  }

  Future<void> _submit({
    required ChecklistTemplateModel template,
    required List<ChecklistTemplateItemModel> items,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      _showError('Sesi pengguna berakhir. Silakan masuk kembali.');
      return;
    }

    for (final field in _fieldsFor(user.role)) {
      final value = _controller(field.name).text.trim();
      if (field.required && value.isEmpty) {
        _showError('${field.label} wajib diisi.');
        return;
      }
      if (field.numeric && value.isNotEmpty) {
        final parsed = _parseNumber(value);
        if (parsed == null) {
          _showError('${field.label} ${_numericError(field)}');
          return;
        }
        if (parsed < 0) {
          _showError('${field.label} tidak boleh bernilai negatif.');
          return;
        }
        if (field.wholeNumber && parsed % 1 != 0) {
          _showError('${field.label} harus berupa bilangan bulat.');
          return;
        }
      }
      if (field.dateTime && value.isNotEmpty && !_isValidDateTime(value)) {
        _showError('${field.label} harus berupa tanggal dan waktu yang valid.');
        return;
      }
    }

    for (final item in items) {
      if (_evidence[item.id] == null && _savedEvidence[item.id] == null) {
        _showError('Wajib mengambil foto dokumentasi untuk: ${item.label}.');
        return;
      }
    }

    if (!_formKey.currentState!.validate()) return;

    if (!_confirmsAccuracy) {
      _showError(
        'Centang pernyataan kebenaran data sebelum mengirim deklarasi.',
      );
      return;
    }

    final pin = await _requestPin();
    if (pin == null || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _submittingStatus = 'Menyimpan data umum...';
    });
    var submissionStage = 'menyimpan data umum';
    try {
      final firestore = ref.read(firestoreServiceProvider);
      final storage = StorageService();
      final isNew = _draftId == null;
      final submissionId = _draftId ?? firestore.newSubmissionId();
      _draftId = submissionId;
      final now = DateTime.now();
      final submission = SubmissionModel(
        id: submissionId,
        modaTransportasi: template.modaTransportasi,
        templateId: template.id,
        dataUmum: _collectGeneralData(user.role),
        pengisiId: user.id,
        status: AppConstants.statusDraft,
        createdAt: now,
        updatedAt: now,
      );
      await firestore.createSubmissionWithId(
        submissionId,
        submission,
        isNew: isNew,
      );

      submissionStage = 'menyimpan data checklist';
      if (mounted) setState(() => _submittingStatus = 'Menyimpan jawaban checklist...');
      await Future.wait(
        items.map((item) {
          final note = _controller('reason_${item.id}').text.trim();
          return firestore.saveAnswerForItem(
            submissionId: submissionId,
            itemId: item.id,
            answer: {
              'submission_id': submissionId,
              'template_item_id': item.id,
              'kategori': item.kategori,
              'label': item.label,
              'nilai_jawaban': 'dilaporkan',
              'alasan': note.isNotEmpty ? note : null,
              'status_gagal': false,
            },
          );
        }),
      );

      final uploadFutures = <Future<void>>[];
      for (final item in items) {
        final evidence = _evidence[item.id];
        final position = _positions[item.id];
        if (evidence != null && position != null) {
          uploadFutures.add(
            _uploadEvidenceDirect(
              submissionId: submissionId,
              item: item,
              evidence: evidence,
              position: position,
              timestamp: _captureTimes[item.id] ?? now,
              storage: storage,
            ),
          );
        }
      }

      if (uploadFutures.isNotEmpty) {
        submissionStage = 'mengunggah ${uploadFutures.length} foto dokumentasi';
        if (mounted) {
          setState(
            () => _submittingStatus =
                'Mengunggah ${uploadFutures.length} foto bukti...',
          );
        }
        await Future.wait(uploadFutures);
      }

      submissionStage = 'mengesahkan deklarasi dengan PIN';
      if (mounted) {
        setState(() => _submittingStatus = 'Mengesahkan deklarasi dengan PIN...');
      }
      final status = await ref.read(authServiceProvider).signSubmission(
            submissionId: submissionId,
            pin: pin,
          );
      await SubmissionDraftStorage.clear(user.id);
      _draftId = null;
      _hasRestoredLocalDraft = false;
      _restoredDraftTime = null;
      ref.invalidate(userSubmissionsProvider);

      if (!mounted) return;
      const label =
          'Dokumentasi sanitasi berhasil dikirim dan menunggu verifikasi penilaian oleh Petugas BBKK.';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            status == AppConstants.statusDitolakOtomatis
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: status == AppConstants.statusDitolakOtomatis
                ? SiskaraTheme.warning
                : SiskaraTheme.success,
          ),
          title: const Text('Deklarasi selesai'),
          content: const Text(label),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.go('/history');
              },
              child: const Text('Lihat riwayat'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        _showError(
          'Gagal saat $submissionStage. '
          '${ErrorMessage.from(error, fallback: 'Periksa data lalu coba kembali.')}',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SiskaraTheme.error),
    );
  }

  Widget _buildDraftBody(BuildContext context, UserModel? user) {
    final future = _draftFuture;
    if (future == null) {
      return const _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Draft tidak dapat dibuka',
        message: 'Silakan kembali ke Riwayat dan coba lagi.',
      );
    }
    return FutureBuilder<_DraftFormData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(
            message: 'Draft tidak dapat dimuat: '
                '${ErrorMessage.from(snapshot.error!)}',
            onRetry: () => setState(() {
              _draftFuture = _loadDraft(widget.draftId!);
            }),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const _EmptyState(
            icon: Icons.description_outlined,
            title: 'Draft tidak ditemukan',
            message: 'Kembali ke Riwayat untuk memilih draft yang tersedia.',
          );
        }
        if (data.items.isEmpty) {
          return const _EmptyState(
            icon: Icons.checklist_outlined,
            title: 'Checklist tidak tersedia',
            message: 'Template draft ini belum memiliki bagian pemeriksaan.',
          );
        }
        return _buildForm(context, data.template, data.items, user);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final template = ref.watch(activeTemplateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.draftId != null
            ? 'Lanjutkan draft'
            : user?.isKepala == true
            ? user!.role == AppConstants.roleKepalaKapal
                ? 'Pemeriksaan Kapal'
                : 'Pemeriksaan Pesawat'
            : 'Deklarasi Sanitasi'),
      ),
      body: widget.draftId != null
          ? _buildDraftBody(context, user)
          : template.when(
        data: (activeTemplate) {
          if (activeTemplate == null) {
            return const _EmptyState(
              icon: Icons.assignment_outlined,
              title: 'Template belum tersedia',
              message:
                  'Belum ada checklist aktif untuk moda transportasi akun Anda. Hubungi administrator BBKK.',
            );
          }
          final itemList = ref.watch(templateItemsProvider);
          return itemList.when(
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyState(
                  icon: Icons.checklist_outlined,
                  title: 'Checklist masih kosong',
                  message:
                      'Template aktif belum memiliki bagian pemeriksaan. Hubungi administrator.',
                );
              }
              return _buildForm(context, activeTemplate, items, user);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message:
                  'Checklist tidak dapat dimuat: ${ErrorMessage.from(error)}',
              onRetry: () => ref.invalidate(templateItemsProvider),
                  ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Template tidak dapat dimuat: ${ErrorMessage.from(error)}',
          onRetry: () => ref.invalidate(activeTemplateProvider),
        ),
      ),
      bottomNavigationBar: user == null
          ? null
          : AppBottomNav(
              user: user,
              location: GoRouterState.of(context).matchedLocation,
            ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    ChecklistTemplateModel template,
    List<ChecklistTemplateItemModel> items,
    UserModel? user,
  ) {
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final fields = _fieldsFor(user.role);
    final categories = <String, List<ChecklistTemplateItemModel>>{};
    for (final item in items) {
      categories.putIfAbsent(item.kategori, () => []).add(item);
    }

    return Form(
      key: _formKey,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_hasRestoredLocalDraft) _buildRestoredDraftBanner(),
                _WelcomeCard(
                  name: user.nama,
                  isKapal: template.modaTransportasi == AppConstants.modaKapal,
                  templateName: template.namaTemplate,
                  version: template.versi,
                ),
                const SizedBox(height: 12),
                _FormSectionTitle(
                  number: '01',
                  title: 'Data umum',
                  subtitle: 'Informasi kapal/pesawat dan jadwal perjalanan.',
                  trailing: '${fields.length} kolom',
                ),
                const SizedBox(height: 8),
                for (final group in _fieldGroupsFor(user.role)) ...[
                  _GeneralFieldGroupCard(
                    group: group,
                    fields: fields
                        .where((field) => group.fieldNames.contains(field.name))
                        .toList(),
                    buildField: _buildGeneralField,
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 14),
                const _FormSectionTitle(
                  number: '02',
                  title: 'Checklist sanitasi',
                  subtitle:
                      'Lengkapi jawaban dan sertakan foto pada setiap bagian.',
                ),
                const SizedBox(height: 8),
                for (final entry in categories.entries) ...[
                  _CategoryHeader(title: entry.key),
                  const SizedBox(height: 8),
                  for (final item in entry.value) ...[
                    _buildChecklistItem(item),
                    const SizedBox(height: 9),
                  ],
                  const SizedBox(height: 8),
                ],
                CheckboxListTile(
                  value: _confirmsAccuracy,
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(
                            () => _confirmsAccuracy = value ?? false,
                          );
                          _scheduleAutoSave();
                        },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    'Saya menyatakan seluruh data sesuai kondisi sebenarnya di lokasi pemeriksaan dan foto bukti diambil pada bagian yang diperiksa.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ),
                const _DeclarationNotice(),
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _saveDraft(template: template, items: items),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Simpan draft', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _submit(template: template, items: items),
                    child: _isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _submittingStatus.isNotEmpty
                                      ? _submittingStatus
                                      : 'Memproses...',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          )
                        : const Text('Tanda tangani & kirim', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Deklarasi akan ditandatangani dengan PIN. Temuan tertentu dapat ditolak otomatis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SiskaraTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralField(_GeneralField field) {
    return TextFormField(
      controller: _controller(field.name),
      onChanged: (_) => _scheduleAutoSave(),
      keyboardType: field.numeric
          ? TextInputType.numberWithOptions(
              decimal: !field.wholeNumber,
              signed: false,
            )
          : TextInputType.text,
      style: const TextStyle(fontSize: 14),
      textCapitalization: TextCapitalization.sentences,
      readOnly: field.dateTime,
      inputFormatters: field.numeric
          ? [
              FilteringTextInputFormatter.allow(
                field.wholeNumber ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]'),
              ),
            ]
          : null,
      onTap: field.dateTime ? () => _selectDateTime(field) : null,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        labelText: '${field.label}${field.required ? ' *' : ''}',
        hintText: field.hint,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(fontSize: 13, color: SiskaraTheme.textSecondary),
        suffixIcon: field.dateTime
            ? const Icon(Icons.calendar_month_outlined, size: 18)
            : null,
      ),
      validator: (value) {
        if (field.required && (value == null || value.trim().isEmpty)) {
          return '${field.label} wajib diisi.';
        }
        if (field.dateTime &&
            value != null &&
            value.trim().isNotEmpty &&
            !_isValidDateTime(value.trim())) {
          return 'Pilih tanggal dan waktu yang valid.';
        }
        if (field.numeric &&
            value != null &&
            value.trim().isNotEmpty &&
            _parseNumber(value.trim()) == null) {
          return _numericError(field);
        }
        if (field.numeric &&
            value != null &&
            value.trim().isNotEmpty &&
            _parseNumber(value.trim())! < 0) {
          return 'Nilai tidak boleh negatif.';
        }
        if (field.wholeNumber &&
            value != null &&
            value.trim().isNotEmpty &&
            _parseNumber(value.trim())! % 1 != 0) {
          return 'Masukkan jumlah dalam bilangan bulat.';
        }
        return null;
      },
    );
  }

  Future<void> _selectDateTime(_GeneralField field) async {
    final now = DateTime.now();
    final initial = _parseDateTime(_controller(field.name).text) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal',
      cancelText: 'Batal',
      confirmText: 'Lanjut',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Pilih waktu',
      cancelText: 'Batal',
      confirmText: 'Simpan',
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _controller(field.name).text = DateFormat('dd-MM-yyyy HH:mm').format(
        selected,
      );
    });
    _scheduleAutoSave();
  }

  List<_GeneralFieldGroup> _fieldGroupsFor(String role) =>
      role == AppConstants.roleKepalaKapal
          ? const [
              _GeneralFieldGroup(
                title: 'Identitas kapal',
                fieldNames: [
                  'nama_kapal',
                  'jenis_kapal',
                  'besar_kapal_grt',
                  'bendera',
                  'nomor_imo',
                ],
              ),
              _GeneralFieldGroup(
                title: 'Rute & pemeriksaan',
                fieldNames: [
                  'pelabuhan_asal',
                  'tujuan_pelabuhan_berikutnya',
                  'lokasi_sandar',
                  'nama_pemilik_agen',
                  'tanggal_jam_tiba',
                  'tanggal_jam_berangkat',
                  'diperiksa_tanggal_jam',
                ],
              ),
              _GeneralFieldGroup(
                title: 'Jumlah orang',
                fieldNames: ['jumlah_awak_kapal', 'jumlah_penumpang'],
              ),
            ]
          : const [
              _GeneralFieldGroup(
                title: 'Identitas penerbangan',
                fieldNames: [
                  'pemilik_atau_penyelenggara',
                  'nomor_penerbangan',
                  'tanda_kebangsaan_dan_pendaftaran',
                ],
              ),
              _GeneralFieldGroup(
                title: 'Rute & jadwal',
                fieldNames: ['berangkat_dari', 'tujuan', 'tanggal_jam'],
              ),
            ];

  static num? _parseNumber(String value) => num.tryParse(
        value.trim().replaceAll(',', '.'),
      );

  static String _numericError(_GeneralField field) => field.wholeNumber
      ? 'masukkan jumlah dalam bilangan bulat yang valid.'
      : 'masukkan angka yang valid.';

  static bool _isValidDateTime(String value) => _parseDateTime(value) != null;

  static DateTime? _parseDateTime(String value) {
    try {
      return DateFormat('dd-MM-yyyy HH:mm').parseStrict(value);
    } on FormatException {
      return null;
    }
  }

  Widget _buildChecklistItem(ChecklistTemplateItemModel item) {
    final evidence = _evidence[item.id];
    final position = _positions[item.id];
    final savedEvidence = _savedEvidence[item.id];
    final hasEvidence = evidence != null || savedEvidence != null;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.kategori,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SiskaraTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                decoration: BoxDecoration(
                  color: hasEvidence
                      ? SiskaraTheme.success.withValues(alpha: 0.12)
                      : SiskaraTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  hasEvidence ? 'Foto Siap' : 'Wajib Foto',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        hasEvidence ? SiskaraTheme.success : SiskaraTheme.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Text(
            'Ambil foto kondisi sanitasi area ini. Penilaian kelayakan akan diisi oleh Petugas BBKK.',
            style: TextStyle(
              fontSize: 13,
              color: SiskaraTheme.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 11),
          TextFormField(
            controller: _controller('reason_${item.id}'),
            onChanged: (_) => _scheduleAutoSave(),
            minLines: 1,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Catatan kondisi pengisi (opsional)',
              hintText: 'Keterangan tambahan jika diperlukan',
              labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              hintStyle: TextStyle(fontSize: 13, color: SiskaraTheme.textSecondary),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SiskaraTheme.primaryBlue.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SiskaraTheme.primaryBlue.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Foto bukti kondisi',
                        style: TextStyle(
                          color: SiskaraTheme.primaryDark,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (hasEvidence)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: SiskaraTheme.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Tersimpan',
                          style: TextStyle(
                            fontSize: 11,
                            color: SiskaraTheme.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Lokasi GPS dan waktu foto otomatis tercatat.',
                  style: TextStyle(
                    color: SiskaraTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed:
                        _isSubmitting ? null : () => _captureEvidence(item),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size(0, 40),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(
                      hasEvidence ? 'Ulangi pengambilan foto' : 'Ambil foto bukti',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasEvidence) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: evidence != null
                  ? Image.file(
                      File(evidence.path),
                      height: 132,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _unavailableEvidencePreview(),
                    )
                  : _StoredEvidencePreview(
                      storagePath: savedEvidence!.fileUrl,
                    ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    position != null && _captureTimes[item.id] != null
                        ? '${position.latitude.toStringAsFixed(4)}, '
                            '${position.longitude.toStringAsFixed(4)} • '
                            '${_captureTimes[item.id]!.toLocal().toString().substring(0, 16)}'
                        : '${savedEvidence?.latitude?.toStringAsFixed(4) ?? '-'}, '
                            '${savedEvidence?.longitude?.toStringAsFixed(4) ?? '-'} • '
                            '${savedEvidence?.timestamp.toLocal().toString().substring(0, 16) ?? ''}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SiskaraTheme.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                if (evidence != null)
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _evidence.remove(item.id);
                              _positions.remove(item.id);
                              _captureTimes.remove(item.id);
                            });
                            _scheduleAutoSave();
                          },
                    child: const Text('Hapus foto baru', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _unavailableEvidencePreview() => Container(
        height: 92,
        color: SiskaraTheme.primaryDark.withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: const Text(
          'Pratinjau foto tidak tersedia',
          style: TextStyle(fontSize: 11),
        ),
      );

}

class _StoredEvidencePreview extends StatefulWidget {
  const _StoredEvidencePreview({required this.storagePath});

  final String storagePath;

  @override
  State<_StoredEvidencePreview> createState() => _StoredEvidencePreviewState();
}

class _StoredEvidencePreviewState extends State<_StoredEvidencePreview> {
  late Future<String> _downloadUrl;

  @override
  void initState() {
    super.initState();
    _downloadUrl = StorageService().getDownloadUrl(widget.storagePath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _downloadUrl,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            height: 92,
            color: SiskaraTheme.primaryDark.withValues(alpha: 0.08),
            alignment: Alignment.center,
            child: const Text(
              'Foto tersimpan, pratinjau tidak tersedia.',
              style: TextStyle(fontSize: 11),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 126,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final resolved = snapshot.data!;
        return GestureDetector(
          onTap: () {
            InteractivePhotoViewer.show(
              context,
              imageUrl: resolved,
              title: 'Foto Bukti Tersimpan',
            );
          },
          child: Stack(
            children: [
              Image.network(
                resolved,
                height: 126,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 92,
                  color: SiskaraTheme.primaryDark.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  child: const Text(
                    'Foto tersimpan, pratinjau tidak tersedia.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 12),
                      SizedBox(width: 3),
                      Text(
                        'Zoom & Unduh',
                        style: TextStyle(color: Colors.white, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DraftFormData {
  const _DraftFormData({required this.template, required this.items});

  final ChecklistTemplateModel template;
  final List<ChecklistTemplateItemModel> items;
}

class _GeneralField {
  const _GeneralField(
    this.name,
    this.label, {
    this.required = true,
    this.numeric = false,
    this.wholeNumber = false,
    this.dateTime = false,
    this.hint,
    this.fullWidth,
  });
  final String name;
  final String label;
  final bool required;
  final bool numeric;
  final bool wholeNumber;
  final bool dateTime;
  final String? hint;
  final bool? fullWidth;
}

class _GeneralFieldGroup {
  const _GeneralFieldGroup({
    required this.title,
    required this.fieldNames,
  });

  final String title;
  final List<String> fieldNames;
}

class _GeneralFieldGroupCard extends StatelessWidget {
  const _GeneralFieldGroupCard({
    required this.group,
    required this.fields,
    required this.buildField,
  });

  final _GeneralFieldGroup group;
  final List<_GeneralField> fields;
  final Widget Function(_GeneralField field) buildField;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SiskaraTheme.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${fields.length} kolom',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: SiskaraTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final compactWidth = (constraints.maxWidth - gap) / 2;
              final isWide = constraints.maxWidth > 580;
              return Wrap(
                spacing: gap,
                runSpacing: 10,
                children: [
                  for (final field in fields)
                    SizedBox(
                      width: isWide && !(field.fullWidth ?? false)
                          ? compactWidth
                          : constraints.maxWidth,
                      child: buildField(field),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.name,
    required this.isKapal,
    required this.templateName,
    required this.version,
  });
  final String name;
  final bool isKapal;
  final String templateName;
  final int version;

  @override
  Widget build(BuildContext context) {
    final color = isKapal ? const Color(0xFF246DA6) : SiskaraTheme.accentTeal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.82)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isKapal ? Icons.directions_boat_outlined : Icons.flight_outlined,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$templateName • v$version',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle({
    required this.number,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String number;
  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SiskaraTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: SiskaraTheme.primaryBlue,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: SiskaraTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: SiskaraTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 12,
              color: SiskaraTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: SiskaraTheme.divider.withValues(alpha: 0.75)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        title.isEmpty ? 'Pemeriksaan' : title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: SiskaraTheme.primaryDark,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _DeclarationNotice extends StatelessWidget {
  const _DeclarationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Deklarasi ditandatangani oleh pemilik akun dan menjadi bagian dari catatan pemeriksaan resmi.',
        style: TextStyle(
          color: Color(0xFF71582E),
          fontSize: 13,
          height: 1.45,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 58,
                color: SiskaraTheme.primaryBlue.withValues(alpha: 0.55)),
            const SizedBox(height: 15),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SiskaraTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: SiskaraTheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
