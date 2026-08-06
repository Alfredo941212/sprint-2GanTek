class VaccineRecord {
  final int? id;
  final int userId;
  final int cattleId;
  final String cattleCode;
  final String vaccineName;
  final DateTime applicationDate;
  final DateTime? nextDoseDate;
  final int doseNumber;
  final String responsible;
  final String observations;
  final DateTime createdAt;

  const VaccineRecord({
    this.id,
    required this.userId,
    required this.cattleId,
    required this.cattleCode,
    required this.vaccineName,
    required this.applicationDate,
    this.nextDoseDate,
    required this.doseNumber,
    required this.responsible,
    required this.observations,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'cattle_id': cattleId,
      'cattle_code': cattleCode,
      'vaccine_name': vaccineName,
      'application_date': applicationDate.toIso8601String(),
      'next_dose_date': nextDoseDate?.toIso8601String(),
      'dose_number': doseNumber,
      'responsible': responsible,
      'observations': observations,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory VaccineRecord.fromMap(
    Map<String, dynamic> map,
  ) {
    return VaccineRecord(
      id: (map['id'] as num?)?.toInt(),
      userId: (map['user_id'] as num).toInt(),
      cattleId: (map['cattle_id'] as num).toInt(),
      cattleCode: map['cattle_code'] as String? ?? '',
      vaccineName: map['vaccine_name'] as String? ?? '',
      applicationDate: DateTime.parse(
        map['application_date'] as String,
      ),
      nextDoseDate: map['next_dose_date'] == null
          ? null
          : DateTime.parse(
              map['next_dose_date'] as String,
            ),
      doseNumber: (map['dose_number'] as num).toInt(),
      responsible: map['responsible'] as String? ?? '',
      observations: map['observations'] as String? ?? '',
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
    );
  }
}
