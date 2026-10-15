/// Application-wide constants for ARJUNA.
class AppConstants {
  AppConstants._();

  // ─── App Info ───────────────────────────────────────────
  static const String appName = 'ARJUNA';
  static const String appFullName =
      'Aplikasi Skrining dan Pemeriksaan Sanitasi Transportasi';
  static const String clientName =
      'Balai Besar Kekarantinaan Kesehatan (BBKK) Makassar';
  static const String ministry = 'Kementerian Kesehatan RI';
  static const String firebaseDatabaseId = String.fromEnvironment(
    'FIREBASE_DATABASE_ID',
    defaultValue: 'bbkkmakassar',
  );

  // ─── Firebase Collections ──────────────────────────────
  static const String colUsers = 'users';
  static const String colChecklistTemplates = 'checklist_templates';
  static const String colChecklistTemplateItems = 'items'; // subcollection
  static const String colSubmissions = 'submissions';
  static const String colSubmissionAnswers = 'answers'; // subcollection
  static const String colSubmissionAnswerMedia = 'media'; // subcollection
  static const String colDocumentSignatures = 'document_signatures';
  static const String colDokumenHasil = 'dokumen_hasil';
  static const String colAuditLog = 'audit_log';

  // ─── Roles ─────────────────────────────────────────────
  static const String roleKepalaKapal = 'kepala_kapal';
  static const String roleKepalaPenerbangan = 'kepala_penerbangan';
  static const String roleStafBbkk = 'staf_bbkk';
  static const String roleValidatorAdmin = 'validator_admin';

  // ─── Transport Modes ───────────────────────────────────
  static const String modaKapal = 'kapal';
  static const String modaPesawat = 'pesawat';

  // ─── Submission Statuses ───────────────────────────────
  static const String statusDraft = 'draft';
  static const String statusDitolakOtomatis = 'ditolak_otomatis';
  static const String statusMenungguVerifikasi = 'menunggu_verifikasi_staf';
  static const String statusDitolakStaf = 'ditolak_staf';
  static const String statusFinal = 'final';

  // ─── Document Types ────────────────────────────────────
  static const String docPhqc = 'phqc';
  static const String docBerkasVerifikasi = 'berkas_verifikasi';

  // ─── Media Constraints ─────────────────────────────────
  static const int maxPhotoSizeKb = 2048; // 2 MB after compression
  static const int maxVideoSizeMb = 50;
  static const int maxVideoDurationSeconds = 60;
  static const double photoCompressionQuality = 0.7;

  // ─── API Base URL ──────────────────────────────────────
  static const String apiBaseUrl = String.fromEnvironment(
    'ARJUNA_API_BASE_URL',
    defaultValue: String.fromEnvironment(
      'SISKARA_API_BASE_URL',
      defaultValue: 'https://lycabyte.store/api',
    ),
  );
}
