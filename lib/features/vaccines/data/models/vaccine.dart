class Vaccine {
  final int? id;
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

  factory Vaccine.fromApi(Map<String, dynamic> json) {
    return Vaccine(
      id: (json['id'] as num?)?.toInt(),
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
