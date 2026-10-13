/** Firestore collection names — single source of truth */
export const COLLECTIONS = {
  USERS: 'users',
  CHECKLIST_TEMPLATES: 'checklist_templates',
  CHECKLIST_TEMPLATE_ITEMS: 'items', // subcollection of checklist_templates
  SUBMISSIONS: 'submissions',
  SUBMISSION_ANSWERS: 'answers', // subcollection of submissions
  SUBMISSION_ANSWER_MEDIA: 'media', // subcollection of submission_answers
  DOCUMENT_SIGNATURES: 'document_signatures',
  DOKUMEN_HASIL: 'dokumen_hasil',
  AUDIT_LOG: 'audit_log',
} as const;

/** Submission status values */
export const SUBMISSION_STATUS = {
  DRAFT: 'draft',
  AUTO_REJECTED: 'ditolak_otomatis',
  PENDING_REVIEW: 'menunggu_verifikasi_staf',
  REJECTED_BY_STAFF: 'ditolak_staf',
  FINAL: 'final',
} as const;

/** Document type values */
export const DOCUMENT_TYPE = {
  PHQC: 'phqc',
  BERKAS_VERIFIKASI: 'berkas_verifikasi',
} as const;

/** Transport mode values */
export const TRANSPORT_MODE = {
  KAPAL: 'kapal',
  PESAWAT: 'pesawat',
} as const;

/** User role values */
export const ROLES = {
  KEPALA_KAPAL: 'kepala_kapal',
  KEPALA_PENERBANGAN: 'kepala_penerbangan',
  STAF_BBKK: 'staf_bbkk',
  VALIDATOR_ADMIN: 'validator_admin',
} as const;
