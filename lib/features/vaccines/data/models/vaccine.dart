class Vaccine {
  final int? id;
  final int? serverId;
  final String name;
  final String? manufacturer;
  final String? description;
  final String? recommendedDose;
  final int? intervalDays;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Vaccine({
    this.id,
    this.serverId,
    required this.name,
    this.manufacturer,
    this.description,
    this.recommendedDose,
    this.intervalDays,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toLowerCase() == 'activo';

  factory Vaccine.fromApi(
    Map<String, dynamic> json, {
    int? localId,
  }) {
    return Vaccine(
      id: localId,
      serverId: (json['id'] as num?)?.toInt(),
      name: json['nombre']?.toString() ?? '',
      manufacturer: _nullableString(json['fabricante']),
      description: _nullableString(json['descripcion']),
      recommendedDose: _nullableString(json['dosis_recomendada']),
      intervalDays: (json['intervalo_dias'] as num?)?.toInt(),
      status: json['estado']?.toString() ?? 'Activo',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  factory Vaccine.fromMap(
    Map<String, dynamic> map,
  ) {
    return Vaccine(
      id: (map['id'] as num?)?.toInt(),
      serverId: (map['server_id'] as num?)?.toInt(),
      name: map['name']?.toString() ?? '',
      manufacturer: null,
      description: _nullableString(map['description']),
      recommendedDose: _nullableString(map['recommended_dose']),
      intervalDays: (map['frequency_days'] as num?)?.toInt(),
      status: map['status']?.toString() ?? 'Activo',
      createdAt: _parseDate(map['created_at']),
      updatedAt: null,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'server_id': serverId,
      'name': name.trim(),
      'description': _cleanNullable(description) ?? '',
      'recommended_dose': _cleanNullable(recommendedDose) ?? '',
      'frequency_days': intervalDays,
      'status': status,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  Map<String, dynamic> toApi() {
    return {
      'nombre': name.trim(),
      'fabricante': _cleanNullable(manufacturer),
      'descripcion': _cleanNullable(description),
      'dosis_recomendada': _cleanNullable(recommendedDose),
      'intervalo_dias': intervalDays,
      'estado': status,
    };
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final String text = value.toString().trim();

    return text.isEmpty ? null : text;
  }

  static String? _cleanNullable(String? value) {
    if (value == null) {
      return null;
    }

    final String text = value.trim();

    return text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}
