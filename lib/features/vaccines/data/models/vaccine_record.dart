class VaccineRecord {
  final int? id;

  final int cattleId;
  final int vaccineId;
  final int veterinarianId;

  final String cattleCode;
  final String vaccineName;
  final String veterinarianName;

  final DateTime applicationDate;
  final DateTime? nextDoseDate;

  final String dose;
  final String observations;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VaccineRecord({
    this.id,
    required this.cattleId,
    required this.vaccineId,
    required this.veterinarianId,
    required this.cattleCode,
    required this.vaccineName,
    required this.veterinarianName,
    required this.applicationDate,
    this.nextDoseDate,
    required this.dose,
    required this.observations,
    this.createdAt,
    this.updatedAt,
  });

  // Compatibilidad temporal con las pantallas antiguas.
  String get responsible => veterinarianName;

  factory VaccineRecord.fromApi(Map<String, dynamic> json) {
    final Map<String, dynamic>? cattle = _asMap(json['ganado']);

    final Map<String, dynamic>? vaccine = _asMap(json['vacuna']);

    final Map<String, dynamic>? veterinarian = _asMap(json['veterinario']);

    return VaccineRecord(
      id: _toInt(json['id']),
      cattleId: _toInt(json['ganado_id']) ?? 0,
      vaccineId: _toInt(json['vacuna_id']) ?? 0,
      veterinarianId: _toInt(json['veterinario_id']) ?? 0,
      cattleCode: cattle?['arete_siniiga']?.toString() ?? '',
      vaccineName: vaccine?['nombre']?.toString() ?? '',
      veterinarianName: veterinarian?['nombre']?.toString() ?? '',
      applicationDate: _parseRequiredDate(
        json['fecha_aplicacion'],
      ),
      nextDoseDate: _parseDate(
        json['proxima_aplicacion'],
      ),
      dose: json['dosis']?.toString() ?? '',
      observations: json['observaciones']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toCreateApi() {
    return {
      'ganado_id': cattleId,
      'veterinario_id': veterinarianId,
      'vacuna_id': vaccineId,
      'fecha_aplicacion': _formatDate(applicationDate),
      'proxima_aplicacion':
          nextDoseDate == null ? null : _formatDate(nextDoseDate!),
      'dosis': dose.trim(),
      'observaciones': _cleanNullable(observations),
    };
  }

  Map<String, dynamic> toUpdateApi() {
    return {
      // ganado_id NO debe enviarse al actualizar.
      'veterinario_id': veterinarianId,
      'vacuna_id': vaccineId,
      'fecha_aplicacion': _formatDate(applicationDate),
      'proxima_aplicacion':
          nextDoseDate == null ? null : _formatDate(nextDoseDate!),
      'dosis': dose.trim(),
      'observaciones': _cleanNullable(observations),
    };
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime _parseRequiredDate(dynamic value) {
    final DateTime? parsed = _parseDate(value);

    if (parsed == null) {
      throw FormatException(
        'La vacunación no contiene una fecha válida.',
      );
    }

    return parsed;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String? _cleanNullable(String? value) {
    if (value == null) {
      return null;
    }

    final String text = value.trim();

    return text.isEmpty ? null : text;
  }
}
