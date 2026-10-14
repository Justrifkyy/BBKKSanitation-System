import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:siskara_mobile/core/error_message.dart';
import 'package:siskara_mobile/services/api_service.dart';

void main() {
  group('ErrorMessage', () {
    test('converts server errors to a safe actionable message', () {
      expect(
        ErrorMessage.from(
          const ApiException('Internal server error', statusCode: 500),
        ),
        'Server SISKARA sedang mengalami gangguan (HTTP 500). '
        'Coba kembali beberapa saat lagi.',
      );
    });

    test('keeps useful validation details for client errors', () {
      expect(
        ErrorMessage.from(
          const ApiException('Nomor IMO tidak valid.', statusCode: 422),
        ),
        'Nomor IMO tidak valid.',
      );
    });

    test('explains unavailable private storage without exposing server data',
        () {
      expect(
        ErrorMessage.from(
          const ApiException('R2 credentials missing', statusCode: 503),
        ),
        'Layanan penyimpanan sedang tidak tersedia. Hubungi administrator '
        'atau coba kembali nanti.',
      );
    });

    test('maps database permission failures to an account-facing message', () {
      expect(
        ErrorMessage.from(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        'Akses ke data ditolak. Pastikan akun Anda memiliki izin yang sesuai.',
      );
    });

    test('does not show exception implementation details for unknown errors',
        () {
      expect(
        ErrorMessage.from(
          Exception('private implementation detail'),
          fallback: 'Operasi gagal.',
        ),
        'Operasi gagal.',
      );
    });
  });
}
