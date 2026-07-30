class Cattle {
  final int? id;
  final String code;
  final DateTime entryDate;
  final double initialWeight;
  final String vaccines;
  final String observations;
  final String? imagePath;
  final String lot;
  final String corral;
  final int userId;

  const Cattle({
    this.id,
    required this.userId,
    required this.code,
    required this.entryDate,
    required this.initialWeight,
    required this.vaccines,
    required this.observations,
    this.imagePath,
    required this.lot,
    required this.corral,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'code': code,
      'entry_date': entryDate.toIso8601String(),
      'initial_weight': initialWeight,
      'vaccines': vaccines,
      'observations': observations,
      'image_path': imagePath,
      'lot': lot,
      'corral': corral,
    };
  }

  factory Cattle.fromMap(Map<String, dynamic> map) {
    return Cattle(
      id: map['id'] as int?,
      userId: (map['user_id'] as num).toInt(),
      code: map['code'] as String,
      entryDate: DateTime.parse(
        map['entry_date'] as String,
      ),
      initialWeight: (map['initial_weight'] as num).toDouble(),
      vaccines: map['vaccines'] as String? ?? '',
      observations: map['observations'] as String? ?? '',
      imagePath: map['image_path'] as String?,
      lot: map['lot'] as String? ?? '',
      corral: map['corral'] as String? ?? '',
    );
  }

  Cattle copyWith({
    int? id,
    String? code,
    DateTime? entryDate,
    double? initialWeight,
    String? vaccines,
    String? observations,
    String? imagePath,
    String? lot,
    String? corral,
  }) {
    return Cattle(
      id: id ?? this.id,
      userId: userId,
      code: code ?? this.code,
      entryDate: entryDate ?? this.entryDate,
      initialWeight: initialWeight ?? this.initialWeight,
      vaccines: vaccines ?? this.vaccines,
      observations: observations ?? this.observations,
      imagePath: imagePath ?? this.imagePath,
      lot: lot ?? this.lot,
      corral: corral ?? this.corral,
    );
  }
}
