class MilkingGroup {
  final int? id;
  final int? serverId;

  final int userId;

  final String name;

  final int sortOrder;

  final String status;

  final String syncStatus;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? lastSyncError;

  const MilkingGroup({
    this.id,
    this.serverId,
    required this.userId,
    required this.name,
    required this.sortOrder,
    this.status = 'Activo',
    this.syncStatus = 'pending',
    this.createdAt,
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
      'name': name.trim(),
      'sort_order': sortOrder,
      'status': status,
      'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_sync_error': lastSyncError,
    };
  }

  factory MilkingGroup.fromMap(
    Map<String, dynamic> map,
  ) {
    return MilkingGroup(
      id: _toInt(map['id']),
      serverId: _toInt(map['server_id']),
      userId: _toInt(map['user_id']) ?? 0,
      name: map['name']?.toString() ?? '',
      sortOrder: _toInt(map['sort_order']) ?? 0,
      status: map['status']?.toString() ?? 'Activo',
      syncStatus: map['sync_status']?.toString() ?? 'pending',
      createdAt: _parseNullableDateTime(map['created_at']),
      updatedAt: _parseNullableDateTime(map['updated_at']),
      lastSyncError: map['last_sync_error']?.toString(),
    );
  }

  // =========================================================
  // API LARAVEL
  // =========================================================

  factory MilkingGroup.fromApi(
    Map<String, dynamic> map,
  ) {
    return MilkingGroup(
      serverId: _toInt(map['id']),
      userId: _toInt(map['user_id']) ?? 0,
      name: map['nombre']?.toString() ?? '',
      sortOrder: _toInt(map['orden']) ?? 0,
      status: map['estado']?.toString() == 'inactivo'
          ? 'Inactivo'
          : 'Activo',
      syncStatus: 'synced',
      createdAt: _parseNullableDateTime(map['created_at']),
      updatedAt: _parseNullableDateTime(map['updated_at']),
      lastSyncError: null,
    );
  }

  // =========================================================
  // COPY WITH
  // =========================================================

  MilkingGroup copyWith({
    int? id,
    int? serverId,
    int? userId,
    String? name,
    int? sortOrder,
    String? status,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastSyncError,
  }) {
    return MilkingGroup(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncError: lastSyncError ?? this.lastSyncError,
    );
  }

  // =========================================================
  // UTILIDADES
  // =========================================================

  static int? _toInt(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  static DateTime? _parseNullableDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }
}