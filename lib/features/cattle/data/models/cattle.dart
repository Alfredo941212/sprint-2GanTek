class Cattle {
  // ID local de SQLite.
  final int? id;

  // ID correspondiente en Laravel/MySQL.
  final int? serverId;

  final int userId;
  final int? lotId;

  final String code;
  final String name;
  final String sex;
  final String breed;

  final DateTime? birthDate;
  final DateTime entryDate;

  final double? initialWeight;

  final String productiveStatus;
  final double minimumDailyProduction;

  final String status;
  final String observations;

  final String? imagePath;

  // pending | synced | error
  final String syncStatus;

  final DateTime? updatedAt;
  final String? lastSyncError;

  const Cattle({
    this.id,
    this.serverId,
    required this.userId,
    this.lotId,
    required this.code,
    required this.name,
    required this.sex,
    required this.breed,
    this.birthDate,
    required this.entryDate,
    this.initialWeight,
    required this.productiveStatus,
    required this.minimumDailyProduction,
    required this.status,
    required this.observations,
    this.imagePath,
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
      'lot_id': lotId,
      'code': code,
      'name': name,
      'sex': sex,
      'breed': breed,
      'birth_date': birthDate?.toIso8601String(),
      'entry_date': entryDate.toIso8601String(),
      'initial_weight': initialWeight,
      'productive_status': productiveStatus,
      'minimum_daily_production': minimumDailyProduction,
      'status': status,
      'observations': observations,
      'image_path': imagePath,
      'sync_status': syncStatus,
      'updated_at': updatedAt?.toIso8601String(),
      'last_sync_error': lastSyncError,
    };
  }

  factory Cattle.fromMap(
    Map<String, dynamic> map,
  ) {
    return Cattle(
      id: _toInt(map['id']),
      serverId: _toInt(map['server_id']),
      userId: _toInt(map['user_id']) ?? 0,
      lotId: _toInt(map['lot_id']),
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      sex: map['sex']?.toString() ?? 'Hembra',
      breed: map['breed']?.toString() ?? '',
      birthDate: _parseDate(
        map['birth_date'],
      ),
      entryDate: _parseDate(
            map['entry_date'],
          ) ??
          DateTime.now(),
      initialWeight: _toDouble(
        map['initial_weight'],
      ),
      productiveStatus: map['productive_status']?.toString() ?? 'En producción',
      minimumDailyProduction: _toDouble(map['minimum_daily_production']) ?? 4.0,
      status: map['status']?.toString() ?? 'Activo',
      observations: map['observations']?.toString() ?? '',
      imagePath: map['image_path']?.toString(),
      syncStatus: map['sync_status']?.toString() ?? 'pending',
      updatedAt: _parseDateTime(
        map['updated_at'],
      ),
      lastSyncError: map['last_sync_error']?.toString(),
    );
  }

  // =========================================================
  // API LARAVEL
  // =========================================================

  factory Cattle.fromApi(
    Map<String, dynamic> map, {
    int userId = 0,
    int? localLotId,
    int? localId,
  }) {
    return Cattle(
      // El id de Laravel NO se guarda como id local.
      id: localId,

      serverId: _toInt(
        map['id'],
      ),

      userId: userId,

      // Aquí recibiremos el ID SQLite del lote.
      lotId: localLotId,

      code: map['arete_siniiga']?.toString() ?? '',
      name: map['nombre']?.toString() ?? '',
      sex: map['sexo']?.toString() ?? 'Hembra',
      breed: map['raza']?.toString() ?? '',
      birthDate: _parseDate(
        map['fecha_nacimiento'],
      ),
      entryDate: _parseDate(
            map['fecha_ingreso'],
          ) ??
          DateTime.now(),
      initialWeight: _toDouble(
        map['peso_inicial'],
      ),
      productiveStatus: map['estado_productivo']?.toString() ?? 'En producción',
      minimumDailyProduction: _toDouble(map['produccion_minima_diaria']) ?? 4.0,
      status: map['estado']?.toString() ?? 'Activo',
      observations: map['observaciones']?.toString() ?? '',
      imagePath: null,
      syncStatus: 'synced',
      updatedAt: _parseDateTime(
        map['updated_at'],
      ),
      lastSyncError: null,
    );
  }

  // =========================================================
  // COPY WITH
  // =========================================================

  Cattle copyWith({
    int? id,
    int? serverId,
    int? userId,
    int? lotId,
    bool clearLot = false,
    String? code,
    String? name,
    String? sex,
    String? breed,
    DateTime? birthDate,
    bool clearBirthDate = false,
    DateTime? entryDate,
    double? initialWeight,
    bool clearInitialWeight = false,
    String? productiveStatus,
    double? minimumDailyProduction,
    String? status,
    String? observations,
    String? imagePath,
    bool clearImagePath = false,
    String? syncStatus,
    DateTime? updatedAt,
    String? lastSyncError,
    bool clearLastSyncError = false,
  }) {
    return Cattle(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      lotId: clearLot ? null : lotId ?? this.lotId,
      code: code ?? this.code,
      name: name ?? this.name,
      sex: sex ?? this.sex,
      breed: breed ?? this.breed,
      birthDate: clearBirthDate ? null : birthDate ?? this.birthDate,
      entryDate: entryDate ?? this.entryDate,
      initialWeight:
          clearInitialWeight ? null : initialWeight ?? this.initialWeight,
      productiveStatus: productiveStatus ?? this.productiveStatus,
      minimumDailyProduction:
          minimumDailyProduction ?? this.minimumDailyProduction,
      status: status ?? this.status,
      observations: observations ?? this.observations,
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncError:
          clearLastSyncError ? null : lastSyncError ?? this.lastSyncError,
    );
  }

  // =========================================================
  // UTILIDADES
  // =========================================================

  static DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final String text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  static DateTime? _parseDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    final String text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
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
