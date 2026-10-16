import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../models/ia_analysis_model.dart';

class IaRepository {
  IaRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<IaAnalysisModel> obtenerPrediccionProduccion() async {
    final response = await _apiClient.get(
      '/ia/prediccion-produccion',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'La respuesta de la IA no tiene el formato esperado.',
        );
      }

      return IaAnalysisModel.fromJson(decoded);
    }

    throw Exception(
      'Error al consultar el análisis IA. '
      'Código: ${response.statusCode}',
    );
  }

  Future<String> agregarAAgenda(
    int ganadoId,
  ) async {
    final response = await _apiClient.post(
      '/ia/$ganadoId/agregar-agenda',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString() ??
            'Operación realizada correctamente.';
      }

      return 'Operación realizada correctamente.';
    }

    throw Exception(
      'No se pudo agregar la tarea a la agenda. '
      'Código: ${response.statusCode}',
    );
  }
}
