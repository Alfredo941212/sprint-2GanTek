class Farm {
  final int? id;
  final String name;
  final String municipality;
  final String? locality;
  final String state;
  final double? area;
  final String? observations;
  final String? createdAt;
  final String? updatedAt;

  const Farm({
    this.id,
    required this.name,
    required this.municipality,
    this.locality,
    required this.state,
    this.area,
    this.observations,
    this.createdAt,
    this.updatedAt,
  });

  factory Farm.fromApi(Map<String, dynamic> map) {
    return Farm(
      id: (map['id'] as num?)?.toInt(),
      name: map['nombre']?.toString() ?? '',
      municipality: map['municipio']?.toString() ?? '',
      locality: map['localidad']?.toString(),
      state: map['estado']?.toString() ?? '',
      area: _toDouble(map['superficie']),
      observations: map['observaciones']?.toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toApi() {
    return {
      'nombre': name.trim(),
      'municipio': municipality.trim(),
      'localidad': _nullableText(locality),
      'estado': state.trim(),
      'superficie': area,
      'observaciones': _nullableText(observations),
    };
  }

  Farm copyWith({
    int? id,
    String? name,
    String? municipality,
    String? locality,
    String? state,
    double? area,
    String? observations,
    String? createdAt,
    String? updatedAt,
  }) {
    return Farm(
      id: id ?? this.id,
      name: name ?? this.name,
      municipality: municipality ?? this.municipality,
      locality: locality ?? this.locality,
      state: state ?? this.state,
      area: area ?? this.area,
      observations: observations ?? this.observations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static String? _nullableText(String? value) {
    final String text = value?.trim() ?? '';

    return text.isEmpty ? null : text;
  }
}
