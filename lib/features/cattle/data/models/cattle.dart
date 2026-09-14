class Cattle {
  final int? id;

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

  const Cattle({
    this.id,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
    };
  }

  factory Cattle.fromMap(
    Map<String, dynamic> map,
  ) {
    return Cattle(
      id: (map['id'] as num?)?.toInt(),
      userId: (map['user_id'] as num).toInt(),
      lotId: (map['lot_id'] as num?)?.toInt(),
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
      initialWeight: (map['initial_weight'] as num?)?.toDouble(),
      productiveStatus: map['productive_status']?.toString() ?? 'En producción',
      minimumDailyProduction:
          (map['minimum_daily_production'] as num?)?.toDouble() ?? 4.0,
      status: map['status']?.toString() ?? 'Activo',
      observations: map['observations']?.toString() ?? '',
      imagePath: map['image_path']?.toString(),
    );
  }

  Cattle copyWith({
    int? id,
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
  }) {
    return Cattle(
      id: id ?? this.id,
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
    );
  }

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
}
