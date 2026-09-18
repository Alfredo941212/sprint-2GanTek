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

  // =========================================================
  // SQLITE - COMPATIBILIDAD TEMPORAL
  // =========================================================

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'name': name.trim(),
      'professional_license': _cleanNullable(
        professionalLicense,
      ),
      'phone': _cleanNullable(
        phone,
      ),
      'email': _cleanNullable(
        email,
      ),
      'specialty': _cleanNullable(
        specialty,
      ),
      'status': status,
      'observations': _cleanNullable(
        observations,
      ),
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
      id: (map['id'] as num?)?.toInt(),
      name: map['name']?.toString() ?? '',
      professionalLicense: map['professional_license']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      specialty: map['specialty']?.toString(),
      status: map['status']?.toString() ?? 'Activo',
      observations: map['observations']?.toString(),
      createdAt: map['created_at']?.toString(),
    );
  }

  // =========================================================
  // API LARAVEL
  // =========================================================

  factory Veterinarian.fromApi(
    Map<String, dynamic> map,
  ) {
    return Veterinarian(
      id: (map['id'] as num?)?.toInt(),
      name: map['nombre']?.toString() ?? '',
      professionalLicense: map['cedula_profesional']?.toString(),
      phone: map['telefono']?.toString(),
      email: map['correo']?.toString(),
      specialty: map['especialidad']?.toString(),
      status: map['estado']?.toString() ?? 'Activo',
      observations: map['observaciones']?.toString(),
      createdAt: map['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toApi() {
    return {
      'nombre': name.trim(),
      'cedula_profesional': professionalLicense?.trim() ?? '',
      'telefono': _cleanNullable(
        phone,
      ),
      'correo': _cleanNullable(
        email,
      ),
      'especialidad': _cleanNullable(
        specialty,
      ),
      'estado': status,
      'observaciones': _cleanNullable(
        observations,
      ),
    };
  }

  // =========================================================
  // COPY WITH
  // =========================================================

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

  // =========================================================
  // AUXILIAR
  // =========================================================

  static String? _cleanNullable(
    String? value,
  ) {
    if (value == null) {
      return null;
    }

    final String cleaned = value.trim();

    if (cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }
}
