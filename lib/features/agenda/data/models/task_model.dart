class TaskModel {
  final int id;
  final int userId;
  final int? ganadoId;
  final int? loteId;

  final String titulo;
  final String? descripcion;
  final String tipo;

  final String fecha;
  final String? hora;

  final String prioridad;
  final String estado;

  final bool recordatorio;
  final bool creadaPorIa;

  TaskModel({
    required this.id,
    required this.userId,
    this.ganadoId,
    this.loteId,
    required this.titulo,
    this.descripcion,
    required this.tipo,
    required this.fecha,
    this.hora,
    required this.prioridad,
    required this.estado,
    required this.recordatorio,
    required this.creadaPorIa,
  });

  factory TaskModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TaskModel(
      id: _toInt(json['id']) ?? 0,
      userId: _toInt(json['user_id']) ?? 0,
      ganadoId: _toInt(json['ganado_id']),
      loteId: _toInt(json['lote_id']),
      titulo: json['titulo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
      tipo: json['tipo']?.toString() ?? '',
      fecha: json['fecha']?.toString() ?? '',
      hora: json['hora']?.toString(),
      prioridad: json['prioridad']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
      recordatorio: _toBool(json['recordatorio']),
      creadaPorIa: _toBool(json['creada_por_ia']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is int) {
      return value == 1;
    }

    return value?.toString() == '1' ||
        value?.toString().toLowerCase() == 'true';
  }
}
