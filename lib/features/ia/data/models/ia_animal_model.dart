class IaAnimalModel {
  final int ganadoId;
  final String arete;

  final String estadoIa;
  final String mensaje;

  final String? fechaUltimaProduccion;

  final double? produccionReal;
  final double? produccionEsperada;
  final double? produccionMinima;

  final double? diferenciaLitros;
  final double? diferenciaPorcentual;

  final String? tendencia;
  final String? calidadAjuste;

  final double? r2;
  final double? prediccionSiguienteDia;

  final int? diasUtilizados;
  final int? diasRegistrados;
  final int diasIncompletos;

  IaAnimalModel({
    required this.ganadoId,
    required this.arete,
    required this.estadoIa,
    required this.mensaje,
    this.fechaUltimaProduccion,
    this.produccionReal,
    this.produccionEsperada,
    this.produccionMinima,
    this.diferenciaLitros,
    this.diferenciaPorcentual,
    this.tendencia,
    this.calidadAjuste,
    this.r2,
    this.prediccionSiguienteDia,
    this.diasUtilizados,
    this.diasRegistrados,
    required this.diasIncompletos,
  });

  factory IaAnimalModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return IaAnimalModel(
      ganadoId: json['ganado_id'] ?? 0,
      arete: json['arete']?.toString() ?? '',
      estadoIa: json['estado_ia']?.toString() ?? '',
      mensaje: json['mensaje']?.toString() ?? '',
      fechaUltimaProduccion: json['fecha_ultima_produccion']?.toString(),
      produccionReal: _toDouble(json['produccion_real']),
      produccionEsperada: _toDouble(json['produccion_esperada']),
      produccionMinima: _toDouble(json['produccion_minima']),
      diferenciaLitros: _toDouble(json['diferencia_litros']),
      diferenciaPorcentual: _toDouble(json['diferencia_porcentual']),
      tendencia: json['tendencia']?.toString(),
      calidadAjuste: json['calidad_ajuste']?.toString(),
      r2: _toDouble(json['r2']),
      prediccionSiguienteDia: _toDouble(
        json['prediccion_siguiente_dia'],
      ),
      diasUtilizados: _toInt(json['dias_utilizados']),
      diasRegistrados: _toInt(json['dias_registrados']),
      diasIncompletos: _toInt(json['dias_incompletos']) ?? 0,
    );
  }

  static double? _toDouble(dynamic value) {
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
}
