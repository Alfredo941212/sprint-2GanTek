import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../models/farm.dart';

class FarmRepository {
  FarmRepository._();

  static final FarmRepository instance = FarmRepository._();

  Future<List<Farm>> getAllFarms() async {
    final response = await ApiClient.instance.get(
      '/fincas',
    );

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'No fue posible cargar las fincas (${response.statusCode}).',
      );
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'La respuesta del servidor no tiene el formato esperado.',
      );
    }

    final dynamic data = decoded['data'];

    if (data is! List) {
      throw Exception(
        'La respuesta del servidor no contiene una lista de fincas.',
      );
    }

    return data.whereType<Map<String, dynamic>>().map(Farm.fromApi).toList();
  }

  Future<Farm?> getFarmById(int farmId) async {
    final response = await ApiClient.instance.get(
      '/fincas/$farmId',
    );

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'No fue posible cargar la finca (${response.statusCode}).',
      );
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'La respuesta del servidor no tiene el formato esperado.',
      );
    }

    final dynamic data = decoded['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'No fue posible interpretar los datos de la finca.',
      );
    }

    return Farm.fromApi(data);
  }
}
