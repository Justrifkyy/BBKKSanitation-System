import 'package:flutter_test/flutter_test.dart';
import 'package:arjuna_mobile/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('identifies ship captain role and transport mode', () {
      final user = UserModel.fromMap(
        {
          'nama': 'Kapten ARJUNA',
          'role': 'kepala_kapal',
          'phone': '0800000000',
          'has_pin': true,
        },
        'captain-1',
      );

      expect(user.id, 'captain-1');
      expect(user.isKepala, isTrue);
      expect(user.isStaf, isFalse);
      expect(user.transportMode, 'kapal');
      expect(user.hasPin, isTrue);
    });

    test('identifies BBKK staff role', () {
      final user = UserModel.fromMap(
        {
          'nama': 'Petugas ARJUNA',
          'role': 'staf_bbkk',
          'phone': '0800000001',
        },
        'staff-1',
      );

      expect(user.isStaf, isTrue);
      expect(user.isKepala, isFalse);
      expect(user.transportMode, isEmpty);
    });
  });
}
