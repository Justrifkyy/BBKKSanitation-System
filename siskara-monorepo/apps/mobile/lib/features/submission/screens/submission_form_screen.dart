import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/checklist_template_model.dart';
import '../../../models/submission_model.dart';
import '../../../models/user_model.dart';
import '../../../services/storage_service.dart';
import '../../../state/auth_state.dart';
import '../../../state/submission_state.dart';

class SubmissionFormScreen extends ConsumerStatefulWidget {
  const SubmissionFormScreen({super.key});

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
  String? _draftId;
  bool _isSubmitting = false;

  static const _shipFields = <_GeneralField>[
    _GeneralField('nama_kapal', 'Nama kapal'),
    _GeneralField('jenis_kapal', 'Jenis kapal'),
    _GeneralField('besar_kapal_grt', 'Besar kapal (GRT)', numeric: true),
    _GeneralField('bendera', 'Bendera'),
    _GeneralField('nomor_imo', 'Nomor IMO'),
    _GeneralField('pelabuhan_asal', 'Pelabuhan asal'),
    _GeneralField('nama_pemilik_agen', 'Nama pemilik / agen'),
    _GeneralField(
      'tujuan_pelabuhan_berikutnya',
      'Tujuan pelabuhan berikutnya',
      required: false,
    ),
    _GeneralField(
      'tanggal_jam_tiba',
      'Tanggal dan jam tiba',
      hint: 'Contoh: 13-10-2026 08:30',
    ),
    _GeneralField(
      'tanggal_jam_berangkat',
      'Tanggal dan jam berangkat',
      required: false,
      hint: 'Contoh: 13-10-2026 10:30',
    ),
    _GeneralField(
      'diperiksa_tanggal_jam',
      'Tanggal dan jam diperiksa',
      hint: 'Contoh: 13-10-2026 09:00',
    ),
    _GeneralField('lokasi_sandar', 'Lokasi sandar'),
    _GeneralField('jumlah_awak_kapal', 'Jumlah awak kapal', numeric: true),
    _GeneralField(
      'jumlah_penumpang',
      'Jumlah penumpang',
      required: false,
      numeric: true,
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
    ),
    _GeneralField('berangkat_dari', 'Berangkat dari'),
    _GeneralField('tujuan', 'Tujuan'),
  ];

  TextEditingController _controller(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<_GeneralField> _fieldsFor(String role) =>
      role == AppConstants.roleKepalaKapal ? _shipFields : _aircraftFields;

  String _labelValue(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  List<String> _optionsFor(ChecklistTemplateItemModel item) {
    if (item.opsiJawaban.isNotEmpty) return item.opsiJawaban;
    switch (item.tipeInput) {
      case 'binary':
        return const ['memenuhi_syarat', 'tidak_memenuhi_syarat'];
      case 'three_level':
        return const ['baik', 'cukup', 'kurang'];
      default:
        return const [];
    }
  }

  String _optionLabel(String value) {
    const labels = {
      'memenuhi_syarat': 'Memenuhi syarat',
      'tidak_memenuhi_syarat': 'Tidak memenuhi',
      'tidak_tampak_tanda': 'Tidak tampak tanda',
      'tampak_tanda': 'Tampak tanda',
      'baik': 'Baik',
      'cukup': 'Cukup',
      'kurang': 'Kurang',
    };
    return labels[value] ?? _labelValue(value);
  }

  String _answerFor(ChecklistTemplateItemModel item) =>
      _answers[item.id] ?? _controllers['answer_${item.id}']?.text.trim() ?? '';

  Map<String, String> _currentAnswers(List<ChecklistTemplateItemModel> items) {
    return {
      for (final item in items)
        if (_answerFor(item).isNotEmpty) item.id: _answerFor(item),
    };
  }

  Future<void> _captureEvidence(
    ChecklistTemplateItemModel item, {
    required bool video,
  }) async {
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

      final media = video
          ? await _picker.pickVideo(
              source: ImageSource.camera,
              maxDuration: const Duration(seconds: 60),
            )
          : await _picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 75,
              maxWidth: 1920,
              maxHeight: 1920,
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bukti tidak dapat diambil: $error'),
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
      if (field.numeric && value.isNotEmpty && num.tryParse(value) == null) {
        _showError('${field.label} harus berupa angka.');
        return;
      }
    }

    final currentAnswers = _currentAnswers(items);
    for (final item in items) {
      final value = currentAnswers[item.id] ?? '';
      if (value.isEmpty) {
        if (!item.isRequiredFor(currentAnswers)) continue;
        _showError('Jawaban wajib diisi untuk: ${item.label}.');
        return;
      }
      if (item.tipeInput == 'numeric' && num.tryParse(value) == null) {
        _showError('Jawaban harus berupa angka untuk: ${item.label}.');
        return;
      }
      if (item.requiresReasonFor(value) &&
          (_controllers['reason_${item.id}']?.text.trim().isEmpty ?? true)) {
        _showError('Alasan wajib diisi untuk: ${item.label}.');
        return;
      }
      if (item.requiresMediaFor(value) && _evidence[item.id] == null) {
        _showError('Ambil foto atau video bukti untuk: ${item.label}.');
        return;
      }
    }

    if (!_formKey.currentState!.validate()) return;

    final pin = await _requestPin();
    if (pin == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final firestore = ref.read(firestoreServiceProvider);
      final storage = StorageService();
      final submissionId = _draftId ?? firestore.newSubmissionId();
      _draftId = submissionId;
      final now = DateTime.now();
      final dataUmum = <String, dynamic>{
        for (final field in _fieldsFor(user.role))
          if (_controller(field.name).text.trim().isNotEmpty)
            field.name: field.numeric
                ? num.tryParse(_controller(field.name).text.trim()) ??
                    _controller(field.name).text.trim()
                : _controller(field.name).text.trim(),
      };

      final submission = SubmissionModel(
        id: submissionId,
        modaTransportasi: template.modaTransportasi,
        templateId: template.id,
        dataUmum: dataUmum,
        pengisiId: user.id,
        status: AppConstants.statusDraft,
        createdAt: now,
        updatedAt: now,
      );
      await firestore.createSubmissionWithId(submissionId, submission);

      for (final item in items) {
        final value = currentAnswers[item.id];
        if (value == null || value.isEmpty) continue;
        final failed = item.isFailValue(value);
        await firestore.saveAnswerForItem(
          submissionId: submissionId,
          itemId: item.id,
          answer: {
            'submission_id': submissionId,
            'template_item_id': item.id,
            'kategori': item.kategori,
            'label': item.label,
            'nilai_jawaban': value,
            'alasan': item.requiresReasonFor(value)
                ? _controller('reason_${item.id}').text.trim()
                : null,
            'status_gagal': failed && item.autoRejectOnFail,
          },
        );

        final evidence = _evidence[item.id];
        final position = _positions[item.id];
        if (item.requiresMediaFor(value) &&
            evidence != null &&
            position != null) {
          final extension = evidence.path.split('.').last.toLowerCase();
          final isVideo = ['mp4', 'mov', 'm4v'].contains(extension);
          final fileLength = await File(evidence.path).length();
          final maxSize = isVideo
              ? AppConstants.maxVideoSizeMb * 1024 * 1024
              : AppConstants.maxPhotoSizeKb * 1024;
          if (fileLength > maxSize) {
            throw StateError(
              isVideo
                  ? 'Ukuran video maksimal ${AppConstants.maxVideoSizeMb} MB.'
                  : 'Ukuran foto maksimal ${AppConstants.maxPhotoSizeKb} KB.',
            );
          }
          final mediaType = isVideo
              ? extension == 'mov'
                  ? 'video/quicktime'
                  : 'video/mp4'
              : extension == 'jpg' || extension == 'jpeg'
                  ? 'image/jpeg'
                  : 'image/$extension';
          final fileUrl = await storage.uploadEvidenceMedia(
            submissionId: submissionId,
            answerId: item.id,
            file: File(evidence.path),
            contentType: mediaType,
          );
          await storage.completeEvidenceUpload(
            storagePath: fileUrl,
            type: isVideo ? 'video' : 'foto',
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: _captureTimes[item.id] ?? now,
          );
        }
      }

      final status = await ref.read(authServiceProvider).signSubmission(
            submissionId: submissionId,
            pin: pin,
          );
      ref.invalidate(userSubmissionsProvider);

      if (!mounted) return;
      final label = status == AppConstants.statusDitolakOtomatis
          ? 'Pengajuan ditolak otomatis karena ada temuan yang harus diperbaiki.'
          : 'Deklarasi terkirim dan menunggu verifikasi petugas BBKK.';
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
          content: Text(label),
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
        _showError('Deklarasi belum dapat dikirim: $error');
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final template = ref.watch(activeTemplateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.isKepala == true
            ? user!.role == AppConstants.roleKepalaKapal
                ? 'Pemeriksaan Kapal'
                : 'Pemeriksaan Pesawat'
            : 'Deklarasi Sanitasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat pengajuan',
            onPressed: () => context.go('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: template.when(
        data: (activeTemplate) {
          if (activeTemplate == null) {
            return _EmptyState(
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
                      'Template aktif belum memiliki butir pemeriksaan. Hubungi administrator.',
                );
              }
              return _buildForm(context, activeTemplate, items, user);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: 'Checklist tidak dapat dimuat: $error',
              onRetry: () => ref.invalidate(templateItemsProvider),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Template tidak dapat dimuat: $error',
          onRetry: () => ref.invalidate(activeTemplateProvider),
        ),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _WelcomeCard(
                  name: user.nama,
                  isKapal: template.modaTransportasi == AppConstants.modaKapal,
                  templateName: template.namaTemplate,
                  version: template.versi,
                ),
                const SizedBox(height: 18),
                const _FormSectionTitle(
                  number: '01',
                  title: 'Data umum',
                  subtitle: 'Lengkapi identitas perjalanan.',
                ),
                const SizedBox(height: 10),
                _SurfaceCard(
                  child: Column(
                    children: [
                      for (var index = 0; index < fields.length; index++) ...[
                        _buildGeneralField(fields[index]),
                        if (index != fields.length - 1)
                          const SizedBox(height: 13),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _FormSectionTitle(
                  number: '02',
                  title: 'Checklist sanitasi',
                  subtitle:
                      'Pilih kondisi pada setiap butir. Temuan wajib diberi alasan dan bukti.',
                ),
                const SizedBox(height: 10),
                for (final entry in categories.entries) ...[
                  _CategoryHeader(title: entry.key),
                  const SizedBox(height: 8),
                  for (final item in entry.value) ...[
                    _buildChecklistItem(item),
                    const SizedBox(height: 9),
                  ],
                  const SizedBox(height: 8),
                ],
                const _DeclarationNotice(),
                const SizedBox(height: 17),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _submit(template: template, items: items),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.draw_outlined),
                    label: Text(
                      _isSubmitting
                          ? 'Mengirim deklarasi...'
                          : 'Tanda tangani & kirim',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Deklarasi akan ditandatangani dengan PIN. Temuan tertentu dapat ditolak otomatis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SiskaraTheme.textSecondary,
                    fontSize: 11,
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
      keyboardType: field.numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint,
        suffixText: field.required ? '*' : 'Opsional',
      ),
      validator: (value) {
        if (field.required && (value == null || value.trim().isEmpty)) {
          return '${field.label} wajib diisi.';
        }
        if (field.numeric &&
            value != null &&
            value.trim().isNotEmpty &&
            num.tryParse(value.trim()) == null) {
          return 'Masukkan angka yang valid.';
        }
        return null;
      },
    );
  }

  Widget _buildChecklistItem(ChecklistTemplateItemModel item) {
    final selected = _answers[item.id];
    final answer = _answerFor(item);
    final requiresReason = answer.isNotEmpty && item.requiresReasonFor(answer);
    final requiresMedia = answer.isNotEmpty && item.requiresMediaFor(answer);
    final options = _optionsFor(item);
    final evidence = _evidence[item.id];
    final position = _positions[item.id];

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SiskaraTheme.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  size: 16,
                  color: SiskaraTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (item.autoRejectOnFail)
                const Tooltip(
                  message: 'Temuan dapat ditolak otomatis',
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: SiskaraTheme.warning,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          if (options.isNotEmpty)
            FormField<String>(
              initialValue: selected,
              validator: (value) => value == null || value.isEmpty
                  ? item.isRequiredFor(_answers)
                      ? 'Pilih kondisi untuk butir ini.'
                      : null
                  : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      for (final option in options)
                        ChoiceChip(
                          label: Text(_optionLabel(option)),
                          selected: field.value == option,
                          onSelected: _isSubmitting
                              ? null
                              : (_) {
                                  field.didChange(option);
                                  setState(() => _answers[item.id] = option);
                                },
                        ),
                    ],
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 5, left: 3),
                      child: Text(
                        field.errorText!,
                        style: const TextStyle(
                          color: SiskaraTheme.error,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            TextFormField(
              controller: _controller('answer_${item.id}'),
              keyboardType: item.tipeInput == 'numeric'
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Jawaban',
                hintText: 'Masukkan hasil pemeriksaan',
              ),
              onChanged: (value) => setState(() => _answers[item.id] = value),
              validator: (value) {
                if ((value == null || value.trim().isEmpty) &&
                    item.isRequiredFor(_answers)) {
                  return 'Jawaban wajib diisi.';
                }
                if (item.tipeInput == 'numeric' &&
                    value != null &&
                    value.trim().isNotEmpty &&
                    num.tryParse(value.trim()) == null) {
                  return 'Masukkan angka yang valid.';
                }
                return null;
              },
            ),
          if (requiresReason) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller('reason_${item.id}'),
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Alasan / temuan',
                hintText: 'Jelaskan kondisi yang ditemukan',
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  requiresReason && (value == null || value.trim().isEmpty)
                      ? 'Alasan wajib diisi untuk temuan.'
                      : null,
            ),
          ],
          if (requiresMedia) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _captureEvidence(item, video: false),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label:
                        Text(evidence == null ? 'Ambil foto' : 'Ulangi foto'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _captureEvidence(item, video: true),
                    icon: const Icon(Icons.videocam_outlined, size: 18),
                    label: const Text('Rekam video'),
                  ),
                ),
              ],
            ),
            if (evidence != null && position != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    evidence.path.toLowerCase().endsWith('.mp4')
                        ? Icons.video_file_outlined
                        : Icons.image_outlined,
                    size: 16,
                    color: SiskaraTheme.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${evidence.name} • GPS ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SiskaraTheme.success,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 2),
                child: Text(
                  'Bukti wajib memuat lokasi GPS dan waktu pengambilan.',
                  style: TextStyle(
                    color: SiskaraTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _GeneralField {
  const _GeneralField(
    this.name,
    this.label, {
    this.required = true,
    this.numeric = false,
    this.hint,
  });
  final String name;
  final String label;
  final bool required;
  final bool numeric;
  final String? hint;
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.82)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isKapal ? Icons.directions_boat_outlined : Icons.flight_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
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
                const SizedBox(height: 5),
                Text(
                  '$templateName • v$version',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.83),
                    fontSize: 11,
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
  });
  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SiskaraTheme.primaryBlue.withOpacity(0.09),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: SiskaraTheme.primaryBlue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SiskaraTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: SiskaraTheme.divider.withOpacity(0.65)),
        borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.only(top: 4, bottom: 1),
      child: Text(
        title.isEmpty ? 'Pemeriksaan' : title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: SiskaraTheme.primaryDark,
              fontWeight: FontWeight.w700,
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFF9A6B1D), size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Pastikan informasi dan bukti pemeriksaan benar. Deklarasi ditandatangani oleh pemilik akun dan menjadi bagian dari catatan pemeriksaan.',
              style: TextStyle(
                color: Color(0xFF71582E),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ),
        ],
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
                size: 58, color: SiskaraTheme.primaryBlue.withOpacity(0.55)),
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
