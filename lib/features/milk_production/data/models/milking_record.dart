class MilkingRecord {
  final int? id;
  final int userId;
  final int cattleId;
  final int? historicalLotId;

  final DateTime date;

  // Se calcula automáticamente.
  // El usuario no tendrá que escribirlo.
  final int milkingNumber;

  // Opcional: Mañana, Tarde, Noche, etc.
  final String? shift;

  final double liters;

  final String? observations;

  final DateTime? createdAt;

  const MilkingRecord({
    this.id,
    required this.userId,
    required this.cattleId,
    this.historicalLotId,
    required this.date,
    required this.milkingNumber,
    this.shift,
    required this.liters,
    this.observations,
    this.createdAt,
  });

  // =========================================================
  // CONVERTIR A MAP PARA SQLITE
  // =========================================================

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'cattle_id': cattleId,
      'historical_lot_id': historicalLotId,
      'date': _dateToDatabase(date),
      'milking_number': milkingNumber,
      'shift': _cleanNullableText(shift),
      'liters': liters,
      'observations': observations?.trim() ?? '',
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  // =========================================================
  // CONVERTIR DESDE SQLITE
  // =========================================================

  factory MilkingRecord.fromMap(
    Map<String, dynamic> map,
  ) {
    return MilkingRecord(
      id: (map['id'] as num?)?.toInt(),
      userId: (map['user_id'] as num).toInt(),
      cattleId: (map['cattle_id'] as num).toInt(),
      historicalLotId: (map['historical_lot_id'] as num?)?.toInt(),
      date: _parseDate(
        map['date'],
      ),
      milkingNumber: (map['milking_number'] as num).toInt(),
      shift: map['shift'] as String?,
      liters: (map['liters'] as num).toDouble(),
      observations: map['observations'] as String?,
      createdAt: _parseNullableDateTime(
        map['created_at'],
      ),
    );
  }

  // =========================================================
  // COPY WITH
  // =========================================================

  MilkingRecord copyWith({
    int? id,
    int? userId,
    int? cattleId,
    int? historicalLotId,
    DateTime? date,
    int? milkingNumber,
    String? shift,
    double? liters,
    String? observations,
    DateTime? createdAt,
  }) {
    return MilkingRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      cattleId: cattleId ?? this.cattleId,
      historicalLotId: historicalLotId ?? this.historicalLotId,
      date: date ?? this.date,
      milkingNumber: milkingNumber ?? this.milkingNumber,
      shift: shift ?? this.shift,
      liters: liters ?? this.liters,
      observations: observations ?? this.observations,
      createdAt: createdAt ?? this.createdAt,
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
}
