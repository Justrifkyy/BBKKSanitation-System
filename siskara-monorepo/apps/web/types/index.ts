/** Type definitions for the SISKARA web application */

export type UserRole = 'kepala_kapal' | 'kepala_penerbangan' | 'staf_bbkk' | 'validator_admin';
export type TransportMode = 'kapal' | 'pesawat';
export type SubmissionStatus = 'draft' | 'ditolak_otomatis' | 'menunggu_verifikasi_staf' | 'ditolak_staf' | 'final';
export type DocumentType = 'phqc' | 'berkas_verifikasi';
export type MediaType = 'foto' | 'video';

export interface User {
  id: string;
  nama: string;
  role: UserRole;
  phone: string;
  id_number?: string;
  signature_url?: string;
  pin_hash?: string;
  dibuat_oleh?: string;
  created_at: Date;
}

export interface ChecklistTemplate {
  id: string;
  moda_transportasi: TransportMode;
  nama_template: string;
  versi: number;
  is_active: boolean;
}

export interface ChecklistTemplateItem {
  id: string;
  template_id: string;
  kategori: string;
  label: string;
  tipe_input: 'binary' | 'three_level' | 'multi_choice' | 'numeric' | 'text';
  nilai_gagal: string | string[];
  auto_reject_on_fail: boolean;
  requires_media_on_fail: boolean;
  order: number;
}

export interface Submission {
  id: string;
  moda_transportasi: TransportMode;
  template_id: string;
  data_umum: Record<string, unknown>;
  pengisi_id: string;
  verifikator_id?: string;
  status: SubmissionStatus;
  created_at: Date;
  updated_at: Date;
}

export interface SubmissionAnswer {
  id: string;
  submission_id: string;
  template_item_id: string;
  nilai_jawaban: string;
  alasan?: string;
  status_gagal: boolean;
}

export interface SubmissionAnswerMedia {
  id: string;
  answer_id: string;
  tipe: MediaType;
  file_url: string;
  gps?: { latitude: number; longitude: number };
  timestamp: Date;
}

export interface DocumentSignature {
  id: string;
  submission_id: string;
  user_id: string;
  role_saat_ttd: 'pengisi' | 'verifikator';
  waktu_ttd: Date;
}

export interface DokumenHasil {
  id: string;
  submission_id: string;
  jenis_dokumen: DocumentType;
  file_pdf_url: string;
  status: 'draft' | 'final';
  tanggal_generate: Date;
}

export interface AuditLog {
  id: string;
  user_id: string;
  aksi: string;
  entitas_terkait: string;
  waktu: Date;
}
