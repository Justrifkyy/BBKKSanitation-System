import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

class ErrorMessage {
  ErrorMessage._();

  static String from(Object error, {String fallback = 'Silakan coba kembali.'}) {
    if (error is ApiException) {
      return _apiMessage(error, fallback);
    }
    if (error is FirebaseAuthException) {
      return _authMessage(error.code);
    }
    if (error is FirebaseException) {
      return _firebaseMessage(error);
    }
    if (error is SocketException) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    }
    if (error is FileSystemException) {
      return 'Berkas tidak dapat dibaca atau disimpan. Pastikan penyimpanan perangkat tersedia.';
    }
    if (error is HttpException) {
      return 'Respons server tidak dapat diproses. Silakan coba kembali.';
    }
    if (error is TimeoutException) {
      return 'Server terlalu lama merespons. Periksa koneksi lalu coba kembali.';
    }
    if (error is FormatException) {
      return 'Data yang diterima tidak sesuai format. Muat ulang lalu coba lagi.';
    }
    if (error is TypeError) {
      return 'Data yang diterima memiliki tipe yang tidak sesuai. Muat ulang atau hubungi administrator.';
    }
    if (error is PlatformException) {
      return _platformMessage(error.code);
    }
    if (error is StateError) {
      return error.message.toString();
    }
    return fallback;
  }

  static String _apiMessage(ApiException error, String fallback) {
    final status = error.statusCode;
    if (status == null) return error.message;

    if (status >= 500) {
      return status == 503
          ? 'Layanan penyimpanan sedang tidak tersedia. Hubungi administrator atau coba kembali nanti.'
          : 'Server ARJUNA sedang mengalami gangguan (HTTP $status). Coba kembali beberapa saat lagi.';
    }

    return switch (status) {
      400 || 422 => error.message,
      401 => 'Sesi Anda telah berakhir. Silakan masuk kembali.',
      403 => 'Akun Anda tidak memiliki izin untuk melakukan tindakan ini.',
      404 => 'Data atau layanan yang diminta tidak ditemukan.',
      408 => 'Permintaan ke server kehabisan waktu. Coba kembali.',
      409 => error.message,
      413 => 'Ukuran berkas terlalu besar. Kurangi ukuran berkas lalu coba lagi.',
      429 => 'Terlalu banyak permintaan. Tunggu sebentar lalu coba kembali.',
      _ => error.message.isNotEmpty
          ? error.message
          : 'Permintaan gagal (HTTP $status). $fallback',
    };
  }

  static String _authMessage(String code) => switch (code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Email atau kata sandi tidak sesuai.',
        'email-already-in-use' => 'Email sudah terdaftar. Silakan masuk.',
        'invalid-email' => 'Format email tidak valid.',
        'weak-password' => 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.',
        'network-request-failed' =>
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        'too-many-requests' =>
          'Terlalu banyak percobaan. Tunggu beberapa saat lalu coba kembali.',
        'user-disabled' =>
          'Akun ini dinonaktifkan. Hubungi administrator ARJUNA.',
        'operation-not-allowed' =>
          'Metode autentikasi belum diaktifkan. Hubungi administrator.',
        'requires-recent-login' =>
          'Silakan keluar dan masuk kembali sebelum mengubah pengaturan keamanan.',
        _ => 'Autentikasi gagal. Periksa data akun dan coba kembali.',
      };

  static String _firebaseMessage(FirebaseException error) {
    if (error.plugin == 'cloud_firestore') {
      return switch (error.code) {
        'permission-denied' =>
          'Akses ke data ditolak. Pastikan akun Anda memiliki izin yang sesuai.',
        'unavailable' =>
          'Database sedang tidak tersedia. Periksa koneksi lalu coba kembali.',
        'deadline-exceeded' =>
          'Database terlalu lama merespons. Coba kembali.',
        'not-found' => 'Data yang diminta tidak ditemukan.',
        'already-exists' => 'Data tersebut sudah tersedia.',
        'failed-precondition' =>
          'Data belum siap dimuat. Periksa konfigurasi database atau coba lagi.',
        'unauthenticated' => 'Sesi Anda berakhir. Silakan masuk kembali.',
        'resource-exhausted' =>
          'Batas penggunaan database tercapai. Coba kembali nanti.',
        _ => 'Terjadi masalah saat mengakses database (${error.code}).',
      };
    }

    return switch (error.code) {
      'unavailable' =>
        'Layanan sedang tidak tersedia. Periksa koneksi lalu coba kembali.',
      'permission-denied' =>
        'Akses ditolak. Pastikan akun Anda memiliki izin yang sesuai.',
      'unauthenticated' => 'Sesi Anda berakhir. Silakan masuk kembali.',
      'resource-exhausted' =>
        'Batas penggunaan layanan tercapai. Coba kembali nanti.',
      _ => 'Layanan ARJUNA mengalami kendala (${error.code}).',
    };
  }

  static String _platformMessage(String code) => switch (code) {
        'camera_access_denied' ||
        'camera_access_restricted' =>
          'Izin kamera ditolak. Aktifkan izin kamera di pengaturan perangkat.',
        'photo_access_denied' ||
        'photo_access_restricted' =>
          'Izin foto ditolak. Aktifkan izin yang diperlukan di pengaturan perangkat.',
        'locationServicesDisabled' =>
          'Aktifkan layanan lokasi untuk mengambil foto bukti.',
        _ => 'Fitur perangkat tidak dapat digunakan ($code). Periksa izin aplikasi.',
      };
}
