class IaAnalysisModel {
  final String modeloPrediccion;
  final String modeloAnomalias;
  final int totalRegistros;
  final int horizonteDias;
  final List<IaGroupModel> grupos;
  final double mae;
  final double rmse;
  final double r2;
  final int registrosEntrenamiento;
  final int registrosPrueba;

  IaAnalysisModel({
    required this.modeloPrediccion,
    required this.modeloAnomalias,
    required this.totalRegistros,
    required this.horizonteDias,
    required this.grupos,
    required this.mae,
    required this.rmse,
    required this.r2,
    required this.registrosEntrenamiento,
    required this.registrosPrueba,
  });

  factory IaAnalysisModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final modelo = json['modelo'];
    final metricas = modelo is Map<String, dynamic> ? modelo['metricas'] : null;
    final gruposJson = json['grupos'];

    return IaAnalysisModel(
      modeloPrediccion: modelo is Map<String, dynamic>
          ? modelo['prediccion']?.toString() ?? ''
          : '',
      modeloAnomalias: modelo is Map<String, dynamic>
          ? modelo['deteccion_anomalias']?.toString() ?? ''
          : '',
      totalRegistros: modelo is Map<String, dynamic>
          ? _toInt(modelo['total_registros'])
          : 0,
      horizonteDias:
          modelo is Map<String, dynamic> ? _toInt(modelo['horizonte_dias']) : 0,
      grupos: gruposJson is List
          ? gruposJson
              .whereType<Map<String, dynamic>>()
              .map(IaGroupModel.fromJson)
              .toList()
          : [],
      mae: metricas is Map<String, dynamic> ? _toDouble(metricas['mae']) : 0,
      rmse: metricas is Map<String, dynamic> ? _toDouble(metricas['rmse']) : 0,
      r2: metricas is Map<String, dynamic> ? _toDouble(metricas['r2']) : 0,
      registrosEntrenamiento: metricas is Map<String, dynamic>
          ? _toInt(
              metricas['registros_entrenamiento'],
            )
          : 0,
      registrosPrueba: metricas is Map<String, dynamic>
          ? _toInt(
              metricas['registros_prueba'],
            )
          : 0,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}

class IaGroupModel {
  final int grupoId;
  final String grupo;
  final double produccionActual;
  final int cantidadVacas;
  final int duracionMinutos;
  final double promedioPorVaca;
  final String tendencia;
  final IaClassificationModel clasificacion;
  final bool anomaliaModelo;
  final double scoreAnomalia;
  final List<IaHistoryModel> historial;
  final List<IaPredictionModel> predicciones;

  IaGroupModel({
    required this.grupoId,
    required this.grupo,
    required this.produccionActual,
    required this.cantidadVacas,
    required this.duracionMinutos,
    required this.promedioPorVaca,
    required this.tendencia,
    required this.clasificacion,
    required this.anomaliaModelo,
    required this.scoreAnomalia,
    required this.historial,
    required this.predicciones,
  });

  factory IaGroupModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return IaGroupModel(
      grupoId: _toInt(
        json['grupo_id'],
      ),
      grupo: json['grupo']?.toString() ?? '',
      produccionActual: _toDouble(
        json['produccion_actual'],
      ),
      cantidadVacas: _toInt(
        json['cantidad_vacas'],
      ),
      duracionMinutos: _toInt(
        json['duracion_minutos'],
      ),
      promedioPorVaca: _toDouble(
        json['promedio_por_vaca'],
      ),
      tendencia: json['tendencia']?.toString() ?? '',
      clasificacion: json['clasificacion'] is Map<String, dynamic>
          ? IaClassificationModel.fromJson(
              json['clasificacion'] as Map<String, dynamic>,
            )
          : IaClassificationModel.empty(),
      anomaliaModelo: json['anomalia_modelo'] == true,
      scoreAnomalia: _toDouble(
        json['score_anomalia'],
      ),
      historial: json['historial'] is List
          ? (json['historial'] as List)
              .whereType<Map<String, dynamic>>()
              .map(
                IaHistoryModel.fromJson,
              )
              .toList()
          : [],
      predicciones: json['predicciones'] is List
          ? (json['predicciones'] as List)
              .whereType<Map<String, dynamic>>()
              .map(
                IaPredictionModel.fromJson,
              )
              .toList()
          : [],
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}

class IaHistoryModel {
  final String fecha;
  final double litros;

  IaHistoryModel({
    required this.fecha,
    required this.litros,
  });

  factory IaHistoryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return IaHistoryModel(
      fecha: json['fecha']?.toString() ?? '',
      litros: _toDouble(
        json['litros'],
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}

class IaPredictionModel {
  final String fecha;
  final double litros;
  final IaClassificationModel clasificacion;

  IaPredictionModel({
    required this.fecha,
    required this.litros,
    required this.clasificacion,
  });

  factory IaPredictionModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return IaPredictionModel(
      fecha: json['fecha']?.toString() ?? '',
      litros: _toDouble(
        json['litros'],
      ),
      clasificacion: json['clasificacion'] is Map<String, dynamic>
          ? IaClassificationModel.fromJson(
              json['clasificacion'] as Map<String, dynamic>,
            )
          : IaClassificationModel.empty(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}

class IaClassificationModel {
  final String nivel;
  final String color;
  final String tipo;
  final String mensaje;

  IaClassificationModel({
    required this.nivel,
    required this.color,
    required this.tipo,
    required this.mensaje,
  });

  factory IaClassificationModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return IaClassificationModel(
      nivel: json['nivel']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? '',
      mensaje: json['mensaje']?.toString() ?? '',
    );
  }

  factory IaClassificationModel.empty() {
    return IaClassificationModel(
      nivel: '',
      color: '',
      tipo: '',
      mensaje: '',
    );
  }
}
