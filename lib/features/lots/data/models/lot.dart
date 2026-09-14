class Lot {
  final int? id;
  final int userId;
  final String name;
  final String? description;
  final double minimumProductionPerCow;
  final String status;
  final String? createdAt;

  const Lot({
    this.id,
    required this.userId,
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

  Lot copyWith({
    int? id,
    int? userId,
    String? name,
    String? description,
    double? minimumProductionPerCow,
    String? status,
    String? createdAt,
  }) {
    return Lot(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      minimumProductionPerCow:
          minimumProductionPerCow ?? this.minimumProductionPerCow,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
