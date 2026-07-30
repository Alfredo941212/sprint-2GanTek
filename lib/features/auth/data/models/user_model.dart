class UserModel {
  final int? id;
  final String fullName;
  final String email;
  final String phone;
  final String passwordHash;
  final String role;
  final DateTime createdAt;

  const UserModel({
    this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.passwordHash,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password_hash': passwordHash,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String? ?? '',
      passwordHash: map['password_hash'] as String,
      role: map['role'] as String? ?? 'ganadero',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  UserModel copyWith({
    int? id,
    String? fullName,
    String? email,
    String? phone,
    String? passwordHash,
    String? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
