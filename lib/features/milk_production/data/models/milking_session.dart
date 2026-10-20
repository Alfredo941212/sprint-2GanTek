class MilkingSession {
  final int? id;
  final String uuid;
  final int? serverId;

  final int userId;
  final int groupId;

  final DateTime date;

  final String? startTime;
  final String? endTime;

  final int? durationMinutes;

  final int cattleCount;

  final double? totalLiters;

  final String status;

  final String observations;

  final String syncStatus;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? lastSyncError;

  const MilkingSession({
    this.id,
    required this.uuid,
    this.serverId,
    required this.userId,
    required this.groupId,
    required this.date,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    this.cattleCount = 0,
    this.totalLiters,
    this.status = 'en_espera',
    this.observations = '',
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
      'uuid': uuid,
      'server_id': serverId,
      'user_id': userId,
      'group_id': groupId,
      'date': _dateToDatabase(date),
      'start_time': startTime,
      'end_time': endTime,
      'duration_minutes': durationMinutes,
      'cattle_count': cattleCount,
      'total_liters': totalLiters,
      'status': status,
      'observations': observations.trim(),
      'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_sync_error': lastSyncError,
    };
  }

  factory MilkingSession.fromMap(
    Map<String, dynamic> map,
  ) {
    return MilkingSession(
      id: _toInt(map['id']),
      uuid: map['uuid']?.toString() ?? '',
      serverId: _toInt(map['server_id']),
      userId: _toInt(map['user_id']) ?? 0,
      groupId: _toInt(map['group_id']) ?? 0,
      date: _parseDate(map['date']),
      startTime: map['start_time']?.toString(),
      endTime: map['end_time']?.toString(),
      durationMinutes: _toInt(map['duration_minutes']),
      cattleCount: _toInt(map['cattle_count']) ?? 0,
      totalLiters: _toDoubleNullable(map['total_liters']),
      status: map['status']?.toString() ?? 'en_espera',
      observations: map['observations']?.toString() ?? '',
      syncStatus: map['sync_status']?.toString() ?? 'pending',
      createdAt: _parseNullableDateTime(map['created_at']),
      updatedAt: _parseNullableDateTime(map['updated_at']),
      lastSyncError: map['last_sync_error']?.toString(),
    );
  }

  // =========================================================
  // API LARAVEL
  // =========================================================

  factory MilkingSession.fromApi(
    Map<String, dynamic> map,
  ) {
    return MilkingSession(
      uuid: map['uuid']?.toString() ?? '',
      serverId: _toInt(map['id']),
      userId: _toInt(map['user_id']) ?? 0,
      groupId: _toInt(map['grupo_ordenio_id']) ?? 0,
      date: _parseDate(map['fecha']),
      startTime: map['hora_inicio']?.toString(),
      endTime: map['hora_fin']?.toString(),
      durationMinutes: _toInt(map['duracion_minutos']),
      cattleCount: _toInt(map['cantidad_vacas']) ?? 0,
      totalLiters: _toDoubleNullable(map['litros_totales']),
      status: map['estado']?.toString() ?? 'en_espera',
      observations: map['observaciones']?.toString() ?? '',
      syncStatus: 'synced',
      createdAt: _parseNullableDateTime(map['created_at']),
      updatedAt: _parseNullableDateTime(map['updated_at']),
      lastSyncError: null,
    );
  }

  // =========================================================
  // COPY WITH
  // =========================================================

  MilkingSession copyWith({
    int? id,
    String? uuid,
    int? serverId,
    int? userId,
    int? groupId,
    DateTime? date,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    int? cattleCount,
    double? totalLiters,
    String? status,
    String? observations,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastSyncError,
  }) {
    return MilkingSession(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      cattleCount: cattleCount ?? this.cattleCount,
      totalLiters: totalLiters ?? this.totalLiters,
      status: status ?? this.status,
      observations: observations ?? this.observations,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncError: lastSyncError ?? this.lastSyncError,
    );
  }

  // =========================================================
  // UTILIDADES
  // =========================================================

  static String _dateToDatabase(
    DateTime date,
  ) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static DateTime _parseDate(
    dynamic value,
  ) {
    if (value is DateTime) {
      return value;
    }

    final parsed = DateTime.tryParse(
      value?.toString() ?? '',
    );

    if (parsed == null) {
      throw const FormatException(
        'Fecha de sesión de ordeña inválida.',
      );
    }

    return parsed;
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

  static double? _toDoubleNullable(
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