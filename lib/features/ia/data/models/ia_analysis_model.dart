import 'ia_animal_model.dart';

class IaAnalysisModel {
  final String fechaAnalisis;
  final int totalAnimales;
  final List<IaAnimalModel> animales;

  IaAnalysisModel({
    required this.fechaAnalisis,
    required this.totalAnimales,
    required this.animales,
  });

  factory IaAnalysisModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = json['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'La respuesta del análisis IA no tiene el formato esperado.',
      );
    }

    final animalesJson = data['animales'];

    return IaAnalysisModel(
      fechaAnalisis: data['fecha_analisis']?.toString() ?? '',
      totalAnimales: _toInt(data['total_animales']) ?? 0,
      animales: animalesJson is List
          ? animalesJson
              .whereType<Map<String, dynamic>>()
              .map(IaAnimalModel.fromJson)
              .toList()
          : [],
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
