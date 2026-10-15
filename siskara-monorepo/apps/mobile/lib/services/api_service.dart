import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/constants.dart';

class ApiException implements Exception {

  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Calls the trusted web API for operations that require server-side checks.
class ApiService {
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? idToken,
  }) async {
    var baseUri = Uri.parse(AppConstants.apiBaseUrl);
    if (baseUri.host == 'arjuna-bbkk.site') {
      baseUri = baseUri.replace(host: 'www.arjuna-bbkk.site');
    }
    final pathSegments = [
      ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
      ...path.split('/').where((segment) => segment.isNotEmpty),
    ];
    var uri = baseUri.replace(pathSegments: pathSegments);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

    try {
      int redirectCount = 0;
      while (redirectCount < 3) {
        final request = await client.postUrl(uri).timeout(
              const Duration(seconds: 20),
            );
        request.headers.contentType = ContentType.json;
        if (idToken != null) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
        }
        if (body != null) request.write(jsonEncode(body));

        final response = await request.close().timeout(
              const Duration(seconds: 20),
            );

        if ([301, 302, 307, 308].contains(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location != null && location.isNotEmpty) {
            final nextUri = Uri.parse(location);
            uri = nextUri.hasScheme ? nextUri : uri.resolve(location);
            redirectCount++;
            continue;
          }
        }

        final responseBody = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 20));

        Map<String, dynamic> payload;
        try {
          final decoded = jsonDecode(responseBody);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('Response is not a JSON object');
          }
          payload = decoded;
        } on FormatException {
          throw ApiException(
            'Server memberikan respons yang tidak dapat dibaca.',
            statusCode: response.statusCode,
          );
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final message = payload['error'];
          throw ApiException(
            message is String && message.isNotEmpty
                ? message
                : 'Permintaan gagal (${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }

        return payload;
      }

      throw const ApiException('Terlalu banyak pengalihan dari server.');
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException(
        'Tidak dapat terhubung ke server ARJUNA. Periksa koneksi internet.',
      );
    } on TimeoutException {
      throw const ApiException(
        'Server ARJUNA tidak merespons. Silakan coba lagi.',
      );
    } on HttpException {
      throw const ApiException(
        'Respons server tidak dapat diproses. Silakan coba kembali.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
