class Veterinarian {
  const Veterinarian({
    this.id,
    required this.name,
    this.professionalLicense,
    this.phone,
    this.email,
    this.specialty,
    this.status = 'Activo',
    this.observations,
    this.createdAt,
  });

  final int? id;
  final String name;
  final String? professionalLicense;
  final String? phone;
  final String? email;
  final String? specialty;
  final String status;
  final String? observations;
  final String? createdAt;

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'name': name.trim(),
      'professional_license': professionalLicense?.trim().isEmpty == true
          ? null
          : professionalLicense?.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
      'specialty': specialty?.trim().isEmpty == true ? null : specialty?.trim(),
      'status': status,
      'observations':
          observations?.trim().isEmpty == true ? null : observations?.trim(),
      'created_at': createdAt,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory Veterinarian.fromMap(
    Map<String, dynamic> map,
  ) {
    return Veterinarian(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      professionalLicense: map['professional_license'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      specialty: map['specialty'] as String?,
      status: (map['status'] as String?) ?? 'Activo',
      observations: map['observations'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Veterinarian copyWith({
    int? id,
    String? name,
    String? professionalLicense,
    String? phone,
    String? email,
    String? specialty,
    String? status,
    String? observations,
    String? createdAt,
  }) {
    return Veterinarian(
      id: id ?? this.id,
      name: name ?? this.name,
      professionalLicense: professionalLicense ?? this.professionalLicense,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      specialty: specialty ?? this.specialty,
      status: status ?? this.status,
      observations: observations ?? this.observations,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
