/// User model matching the Firestore `users` collection schema.
class UserModel {
  final String id;
  final String nama;
  final String role;
  final String phone;
  final String? idNumber;
  final String? signatureUrl;
  final String? pinHash;
  final String? dibuatOleh;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.nama,
    required this.role,
    required this.phone,
    this.idNumber,
    this.signatureUrl,
    this.pinHash,
    this.dibuatOleh,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      id: docId,
      nama: map['nama'] ?? '',
      role: map['role'] ?? '',
      phone: map['phone'] ?? '',
      idNumber: map['id_number'],
      signatureUrl: map['signature_url'],
      pinHash: map['pin_hash'],
      dibuatOleh: map['dibuat_oleh'],
      createdAt: (map['created_at'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'role': role,
      'phone': phone,
      'id_number': idNumber,
      'signature_url': signatureUrl,
      'pin_hash': pinHash,
      'dibuat_oleh': dibuatOleh,
      'created_at': createdAt,
    };
  }

  bool get isKepala =>
      role == 'kepala_kapal' || role == 'kepala_penerbangan';

  bool get isStaf => role == 'staf_bbkk';

  bool get isAdmin => role == 'validator_admin';

  bool get hasSignature => signatureUrl != null && signatureUrl!.isNotEmpty;

  String get transportMode {
    if (role == 'kepala_kapal') return 'kapal';
    if (role == 'kepala_penerbangan') return 'pesawat';
    return '';
  }

  UserModel copyWith({
    String? nama,
    String? phone,
    String? idNumber,
    String? signatureUrl,
    String? pinHash,
  }) {
    return UserModel(
      id: id,
      nama: nama ?? this.nama,
      role: role,
      phone: phone ?? this.phone,
      idNumber: idNumber ?? this.idNumber,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      pinHash: pinHash ?? this.pinHash,
      dibuatOleh: dibuatOleh,
      createdAt: createdAt,
    );
  }
}
