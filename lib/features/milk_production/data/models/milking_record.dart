class MilkingRecord {
  final int? id;

  // Identificador único generado por Flutter.
  // Permite evitar duplicados al sincronizar con Laravel.
  final String? uuid;

  // ID del registro equivalente en MySQL/Laravel.
  final int? serverId;

  final int userId;
  final int cattleId;
  final int? historicalLotId;

  final DateTime date;

  // Se calcula automáticamente.
  final int milkingNumber;

  // Opcional: Mañana, Tarde, etc.
  final String? shift;

  final double liters;
  final String? observations;

  // pending | synced | error
  final String syncStatus;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? lastSyncError;

  const MilkingRecord({
    this.id,
    this.uuid,
    this.serverId,
    required this.userId,
    required this.cattleId,
    this.historicalLotId,
    required this.date,
    required this.milkingNumber,
    this.shift,
    required this.liters,
    this.observations,
    this.syncStatus = 'pending',
    this.createdAt,
    this.updatedAt,
    this.lastSyncError,
  });

  // =========================================================
  // CONVERTIR A MAP PARA SQLITE
  // =========================================================

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'uuid': uuid,
      'server_id': serverId,
      'user_id': userId,
      'cattle_id': cattleId,
      'historical_lot_id': historicalLotId,
      'date': _dateToDatabase(date),
      'milking_number': milkingNumber,
      'shift': _cleanNullableText(shift),
      'liters': liters,
      'observations': observations?.trim() ?? '',
      'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_sync_error': lastSyncError,
    };
  }

  // =========================================================
  // CONVERTIR DESDE SQLITE
  // =========================================================

  factory MilkingRecord.fromMap(
    Map<String, dynamic> map,
  ) {
    return MilkingRecord(
      id: _toInt(map['id']),
      uuid: map['uuid']?.toString(),
      serverId: _toInt(map['server_id']),
      userId: _toInt(map['user_id']) ?? 0,
      cattleId: _toInt(map['cattle_id']) ?? 0,
      historicalLotId: _toInt(map['historical_lot_id']),
      date: _parseDate(map['date']),
      milkingNumber: _toInt(map['milking_number']) ?? 1,
      shift: map['shift']?.toString(),
      liters: _toDouble(map['liters']),
      observations: map['observations']?.toString(),
      syncStatus: map['sync_status']?.toString() ?? 'pending',
      createdAt: _parseNullableDateTime(map['created_at']),
      updatedAt: _parseNullableDateTime(map['updated_at']),
      lastSyncError: map['last_sync_error']?.toString(),
    );
  }

  // =========================================================
  // CONVERTIR DESDE API LARAVEL
  // =========================================================

  factory MilkingRecord.fromApi(
    Map<String, dynamic> map,
  ) {
    return MilkingRecord(
      // OJO:
      // El id recibido aquí pertenece al servidor.
      serverId: _toInt(map['id']),
      uuid: map['uuid']?.toString(),

      userId: _toInt(map['user_id']) ?? 0,
      cattleId: _toInt(map['ganado_id']) ?? 0,
      historicalLotId: _toInt(map['lote_historico_id']),
      date: _parseDate(map['fecha']),
      milkingNumber: _toInt(map['numero_ordenio']) ?? 1,
      shift: map['turno']?.toString(),
      liters: _toDouble(map['litros']),
      observations: map['observaciones']?.toString(),
      syncStatus: 'synced',
      createdAt: _parseNullableDateTime(map['created_at']),
      updatedAt: _parseNullableDateTime(map['updated_at']),
      lastSyncError: null,
    );
  }

  // =========================================================
  // COPY WITH
  // =========================================================

  MilkingRecord copyWith({
    int? id,
    String? uuid,
    int? serverId,
    int? userId,
    int? cattleId,
    int? historicalLotId,
    DateTime? date,
    int? milkingNumber,
    String? shift,
    double? liters,
    String? observations,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastSyncError,
  }) {
    return MilkingRecord(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      cattleId: cattleId ?? this.cattleId,
      historicalLotId: historicalLotId ?? this.historicalLotId,
      date: date ?? this.date,
      milkingNumber: milkingNumber ?? this.milkingNumber,
      shift: shift ?? this.shift,
      liters: liters ?? this.liters,
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
    final String year = date.year.toString();
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static DateTime _parseDate(
    dynamic value,
  ) {
    if (value is DateTime) {
      return value;
    }

    final DateTime? parsed = DateTime.tryParse(
      value?.toString() ?? '',
    );

    if (parsed == null) {
      throw const FormatException(
        'Fecha de ordeña inválida.',
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

  static String? _cleanNullableText(
    String? value,
  ) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return text;
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

  static double _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }
}
