class Lot {
  /// ID local de SQLite.
  final int? id;

  /// ID correspondiente en Laravel/MySQL.
  final int? serverId;

  /// Usuario propietario en SQLite.
  final int userId;

  /// ID de la finca en Laravel/MySQL.
  final int? farmId;

  final String name;
  final String? description;
  final double minimumProductionPerCow;
  final String status;
  final String? createdAt;

  /// Estado de sincronización:
  /// pending = pendiente
  /// synced = sincronizado
  /// error = error al sincronizar
  final String syncStatus;

  final String? updatedAt;
  final String? lastSyncError;

  const Lot({
    this.id,
    this.serverId,
    required this.userId,
    this.farmId,
    required this.name,
    this.description,
    this.minimumProductionPerCow = 4.0,
    this.status = 'Activo',
    this.createdAt,
    this.syncStatus = 'pending',
    this.updatedAt,
    this.lastSyncError,
  });

  // =========================================================
  // SQLITE
  // =========================================================

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'server_id': serverId,
      'user_id': userId,
      'farm_id': farmId,
      'name': name.trim(),
      'description': description?.trim(),
      'minimum_production_per_cow': minimumProductionPerCow,
      'status': status,
      if (createdAt != null) 'created_at': createdAt,
      'sync_status': syncStatus,
      'updated_at': updatedAt,
      'last_sync_error': lastSyncError,
    };
  }

  factory Lot.fromMap(Map<String, dynamic> map) {
    return Lot(
      id: _toInt(map['id']),
      serverId: _toInt(map['server_id']),
      userId: _toInt(map['user_id']) ?? 0,
      farmId: _toInt(map['farm_id']),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      minimumProductionPerCow:
          _toDouble(map['minimum_production_per_cow']) ?? 4.0,
      status: map['status']?.toString() ?? 'Activo',
      createdAt: map['created_at']?.toString(),
      syncStatus: map['sync_status']?.toString() ?? 'pending',
      updatedAt: map['updated_at']?.toString(),
      lastSyncError: map['last_sync_error']?.toString(),
    );
  }

  // =========================================================
  // API LARAVEL
  // =========================================================

  factory Lot.fromApi(
    Map<String, dynamic> map, {
    int userId = 0,
    int? localId,
  }) {
    return Lot(
      id: localId ?? _toInt(map['id']),
      serverId: _toInt(map['id']),
      userId: userId,
      farmId: _toInt(map['finca_id']),
      name: map['nombre']?.toString() ?? '',
      description: map['descripcion']?.toString(),
      minimumProductionPerCow:
          _toDouble(map['produccion_minima_por_vaca']) ?? 4.0,
      status: map['estado']?.toString() ?? 'Activo',
      createdAt: map['created_at']?.toString(),
      syncStatus: 'synced',
      updatedAt: map['updated_at']?.toString(),
      lastSyncError: null,
    );
  }

  // =========================================================
  // COPY WITH
  // =========================================================

  Lot copyWith({
    int? id,
    int? serverId,
    int? userId,
    int? farmId,
    String? name,
    String? description,
    double? minimumProductionPerCow,
    String? status,
    String? createdAt,
    String? syncStatus,
    String? updatedAt,
    String? lastSyncError,
  }) {
    return Lot(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      farmId: farmId ?? this.farmId,
      name: name ?? this.name,
      description: description ?? this.description,
      minimumProductionPerCow:
          minimumProductionPerCow ?? this.minimumProductionPerCow,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncError: lastSyncError ?? this.lastSyncError,
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
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
}
