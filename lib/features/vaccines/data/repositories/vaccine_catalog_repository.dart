import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../models/vaccine.dart';

class VaccineCatalogRepository {
  VaccineCatalogRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<Vaccine>> getAllVaccines() async {
    final response = await _apiClient.get(
      '/vacunas',
    );

    if (response.statusCode == 401) {
      throw StateError(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode != 200) {
      throw StateError(
        _extractMessage(
          response.body,
          'No fue posible cargar las vacunas.',
        ),
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    final List<dynamic> data = json['data'] as List<dynamic>? ?? <dynamic>[];

    final List<Vaccine> vaccines =
        data.whereType<Map<String, dynamic>>().map(Vaccine.fromApi).toList();

    vaccines.sort(
      (Vaccine a, Vaccine b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return vaccines;
  }

  Future<List<Vaccine>> getActiveVaccines() async {
    final List<Vaccine> vaccines = await getAllVaccines();

    return vaccines
        .where(
          (Vaccine vaccine) => vaccine.isActive,
        )
        .toList();
  }

  Future<Vaccine?> getVaccineById(int id) async {
    final response = await _apiClient.get(
      '/vacunas/$id',
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode == 401) {
      throw StateError(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode != 200) {
      throw StateError(
        _extractMessage(
          response.body,
          'No fue posible consultar la vacuna.',
        ),
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    final dynamic data = json['data'];

    if (data is! Map<String, dynamic>) {
      return null;
    }

    return Vaccine.fromApi(data);
  }

  Future<int> insertVaccine(Vaccine vaccine) async {
    final response = await _apiClient.post(
      '/vacunas',
      body: vaccine.toApi(),
    );

    if (response.statusCode == 401) {
      throw StateError(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw StateError(
        'No tienes permiso para registrar vacunas.',
      );
    }

    if (response.statusCode == 422) {
      throw StateError(
        _extractMessage(
          response.body,
          'Revisa los datos de la vacuna.',
        ),
      );
    }

    if (response.statusCode != 201) {
      throw StateError(
        _extractMessage(
          response.body,
          'No fue posible registrar la vacuna.',
        ),
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    final dynamic data = json['data'];

    if (data is! Map<String, dynamic>) {
      throw StateError(
        'El servidor no devolvió la vacuna registrada.',
      );
    }

    final Vaccine created = Vaccine.fromApi(data);

    if (created.id == null) {
      throw StateError(
        'El servidor no devolvió el identificador de la vacuna.',
      );
    }

    return created.id!;
  }

  Future<int> updateVaccine(Vaccine vaccine) async {
    if (vaccine.id == null) {
      throw ArgumentError(
        'La vacuna no tiene identificador.',
      );
    }

    final response = await _apiClient.put(
      '/vacunas/${vaccine.id}',
      body: vaccine.toApi(),
    );

    if (response.statusCode == 401) {
      throw StateError(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw StateError(
        'No tienes permiso para modificar vacunas.',
      );
    }

    if (response.statusCode == 404) {
      throw StateError(
        'La vacuna ya no existe.',
      );
    }

    if (response.statusCode == 422) {
      throw StateError(
        _extractMessage(
          response.body,
          'Revisa los datos de la vacuna.',
        ),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        _extractMessage(
          response.body,
          'No fue posible actualizar la vacuna.',
        ),
      );
    }

    return 1;
  }

  Future<int> deactivateVaccine(int id) async {
    final response = await _apiClient.delete(
      '/vacunas/$id',
    );

    if (response.statusCode == 401) {
      throw StateError(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw StateError(
        'No tienes permiso para desactivar vacunas.',
      );
    }

    if (response.statusCode == 404) {
      throw StateError(
        'La vacuna ya no existe.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        _extractMessage(
          response.body,
          'No fue posible desactivar la vacuna.',
        ),
      );
    }

    return 1;
  }

  String _extractMessage(
    String responseBody,
    String fallback,
  ) {
    try {
      final dynamic decoded = jsonDecode(responseBody);

      if (decoded is Map<String, dynamic>) {
        final dynamic message = decoded['message'];

        if (message is String && message.trim().isNotEmpty) {
          return message;
        }

        final dynamic errors = decoded['errors'];

        if (errors is Map<String, dynamic>) {
          for (final dynamic value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return value.first.toString();
            }

            if (value != null) {
              return value.toString();
            }
          }
        }
      }
    } catch (_) {
      // Se utiliza el mensaje predeterminado.
    }

    return fallback;
  }
}
