class Lot {
  final int? id;
  final int userId;
  final int? farmId;
  final String name;
  final String? description;
  final double minimumProductionPerCow;
  final String status;
  final String? createdAt;

  const Lot({
    this.id,
    required this.userId,
    this.farmId,
    required this.name,
    this.description,
    this.minimumProductionPerCow = 4.0,
    this.status = 'Activo',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name.trim(),
      'description': description?.trim(),
      'minimum_production_per_cow': minimumProductionPerCow,
      'status': status,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  factory Lot.fromMap(Map<String, dynamic> map) {
    return Lot(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      name: map['name'] as String,
      description: map['description'] as String?,
      minimumProductionPerCow:
          (map['minimum_production_per_cow'] as num?)?.toDouble() ?? 4.0,
      status: map['status'] as String? ?? 'Activo',
      createdAt: map['created_at'] as String?,
    );
  }

  factory Lot.fromApi(
    Map<String, dynamic> map,
  ) {
    return Lot(
      id: (map['id'] as num?)?.toInt(),
      userId: 0,
      farmId: (map['finca_id'] as num?)?.toInt(),
      name: map['nombre']?.toString() ?? '',
      description: map['descripcion']?.toString(),
      minimumProductionPerCow: _toDouble(
            map['produccion_minima_por_vaca'],
          ) ??
          4.0,
      status: map['estado']?.toString() ?? 'Activo',
      createdAt: map['created_at']?.toString(),
    );
  }

  Lot copyWith({
    int? id,
    int? userId,
    int? farmId,
    String? name,
    String? description,
    double? minimumProductionPerCow,
    String? status,
    String? createdAt,
  }) {
    return Lot(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      farmId: farmId ?? this.farmId,
      name: name ?? this.name,
      description: description ?? this.description,
      minimumProductionPerCow:
          minimumProductionPerCow ?? this.minimumProductionPerCow,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static double? _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }
}
