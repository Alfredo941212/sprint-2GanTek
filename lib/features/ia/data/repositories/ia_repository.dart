import 'dart:convert';
import '../models/ia_analysis_model.dart';
import '../../../../core/network/api_client.dart';

class IaRepository {
  IaRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<IaAnalysisModel> obtenerAnalisisProduccion({
    int horizonte = 7,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    final queryParams = <String, String>{
      'horizonte': horizonte.toString(),
    };

    if (fechaInicio != null && fechaInicio.isNotEmpty) {
      queryParams['fecha_inicio'] = fechaInicio;
    }

    if (fechaFin != null && fechaFin.isNotEmpty) {
      queryParams['fecha_fin'] = fechaFin;
    }

    final queryString = queryParams.entries
        .map(
          (entry) => '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');

    final response = await _apiClient.get(
      '/ia/produccion-grupos?$queryString',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'La respuesta de la IA no tiene el formato esperado.',
        );
      }

      final success = decoded['success'];

      if (success != true) {
        throw Exception(
          decoded['message']?.toString() ??
              'No fue posible obtener el análisis de producción.',
        );
      }

      final data = decoded['data'];

      if (data is! Map<String, dynamic>) {
        throw Exception(
          'La respuesta no contiene datos válidos de IA.',
        );
      }

      return IaAnalysisModel.fromJson(data);
    }

    if (response.statusCode == 422) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        throw Exception(
          decoded['message']?.toString() ??
              'No hay suficientes registros para ejecutar el análisis.',
        );
      }
    }

    throw Exception(
      'Error al consultar el análisis de producción. '
      'Código: ${response.statusCode}',
    );
  }
}
