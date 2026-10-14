import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';

import 'api_service.dart';

/// Uploads private media to Cloudflare R2 using short-lived API-signed URLs.
class StorageService {
  final ApiService _api = ApiService();

  Future<String> uploadSignatureBytes(
    String userId,
    Uint8List bytes, {
    String contentType = 'image/png',
  }) async {
    if (contentType != 'image/png' && contentType != 'image/svg+xml') {
      throw const ApiException('Tanda tangan harus berupa file PNG atau SVG.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != userId) {
      throw const ApiException(
        'Sesi pengguna berakhir. Silakan masuk kembali.',
      );
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw const ApiException(
        'Sesi pengguna tidak valid. Silakan masuk kembali.',
      );
    }

    return _upload(
      token: token,
      body: {
        'purpose': 'signature',
        'content_type': contentType,
        'size': bytes.length,
      },
      contentType: contentType,
      contentLength: bytes.length,
      content: Stream<List<int>>.value(bytes),
    );
  }

  Future<String> uploadEvidenceMedia({
    required String submissionId,
    required String answerId,
    required File file,
    required String contentType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ApiException(
          'Sesi pengguna berakhir. Silakan masuk kembali.');
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw const ApiException(
          'Sesi pengguna tidak valid. Silakan masuk kembali.');
    }

    final length = await file.length();
    return _upload(
      token: token,
      body: {
        'purpose': 'evidence',
        'submission_id': submissionId,
        'answer_id': answerId,
        'content_type': contentType,
        'size': length,
      },
      contentType: contentType,
      contentLength: length,
      content: file.openRead(),
    );
  }

  Future<String> getDownloadUrl(String storagePath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ApiException(
          'Sesi pengguna berakhir. Silakan masuk kembali.');
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw const ApiException(
          'Sesi pengguna tidak valid. Silakan masuk kembali.');
    }

    final result = await _api.post(
      '/uploads/download',
      body: {'storage_path': storagePath},
      idToken: token,
    );
    final url = result['download_url'];
    if (url is! String || Uri.tryParse(url)?.scheme != 'https') {
      throw const ApiException(
          'Server memberikan tautan berkas yang tidak valid.');
    }
    return url;
  }

  Future<void> completeEvidenceUpload({
    required String storagePath,
    required String type,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ApiException(
          'Sesi pengguna berakhir. Silakan masuk kembali.');
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw const ApiException(
          'Sesi pengguna tidak valid. Silakan masuk kembali.');
    }

    await _api.post(
      '/uploads/complete',
      body: {
        'storage_path': storagePath,
        'tipe': type,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toUtc().toIso8601String(),
      },
      idToken: token,
    );
  }

  Future<String> _upload({
    required String token,
    required Map<String, dynamic> body,
    required String contentType,
    required int contentLength,
    required Stream<List<int>> content,
  }) async {
    final signed = await _api.post(
      '/uploads/presign',
      body: body,
      idToken: token,
    );
    final uploadUrl = signed['upload_url'];
    final storagePath = signed['storage_path'];
    if (uploadUrl is! String ||
        storagePath is! String ||
        Uri.tryParse(uploadUrl)?.scheme != 'https') {
      throw const ApiException(
          'Server memberikan URL unggah yang tidak valid.');
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .putUrl(Uri.parse(uploadUrl))
          .timeout(const Duration(seconds: 30));
      request.headers.contentType = ContentType.parse(contentType);
      request.contentLength = contentLength;
      await request.addStream(content);
      final response = await request.close().timeout(
            const Duration(minutes: 2),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw ApiException(
          'Unggah ke penyimpanan berkas gagal (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      await response.drain<void>();
      return storagePath;
    } on SocketException {
      throw const ApiException(
        'Tidak dapat terhubung ke penyimpanan berkas. Periksa koneksi internet.',
      );
    } on TimeoutException {
      throw const ApiException('Unggah berkas terlalu lama dan waktu habis.');
    } finally {
      client.close(force: true);
    }
  }
}
