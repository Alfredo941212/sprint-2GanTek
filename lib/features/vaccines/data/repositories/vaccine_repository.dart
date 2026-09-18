import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../models/vaccine_record.dart';

class VaccineRepository {
  VaccineRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<int> insertVaccineRecord(
    VaccineRecord vaccine,
  ) async {
    final response = await _apiClient.post(
      '/vacunaciones',
      body: vaccine.toCreateApi(),
    );

    if (response.statusCode == 401) {
      throw StateError(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw StateError(
        'No tienes permiso para registrar esta vacunación.',
      );
    }

    if (response.statusCode == 422) {
      throw StateError(
        _extractMessage(
          response.body,
          'Revisa los datos de la vacunación.',
        ),
      );
    }

    if (response.statusCode != 201) {
      throw StateError(
        _extractMessage(
          response.body,
          'No fue posible registrar la vacunación.',
        ),
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    final dynamic data = json['data'];

    if (data is! Map<String, dynamic>) {
      throw StateError(
        'El servidor no devolvió la vacunación registrada.',
      );
    }

    final VaccineRecord created = VaccineRecord.fromApi(data);

    if (created.id == null) {
      throw StateError(
        'El servidor no devolvió el identificador de la vacunación.',
      );
    }

    return created.id!;
  }

  Future<List<VaccineRecord>> getAllVaccines() async {
    final response = await _apiClient.get(
      '/vacunaciones',
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
          'No fue posible cargar las vacunaciones.',
        ),
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    final List<dynamic> data = json['data'] as List<dynamic>? ?? <dynamic>[];

    return data
        .whereType<Map<String, dynamic>>()
        .map(VaccineRecord.fromApi)
        .toList();
  }

  Future<VaccineRecord?> getVaccineById(
    int id,
  ) async {
    final response = await _apiClient.get(
      '/vacunaciones/$id',
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode == 401) {
      throw StateError(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw StateError(
        'No tienes permiso para consultar esta vacunación.',
      );
    }

    if (response.statusCode != 200) {
      throw StateError(
        _extractMessage(
          response.body,
          'No fue posible consultar la vacunación.',
        ),
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    final dynamic data = json['data'];

    if (data is! Map<String, dynamic>) {
      return null;
    }

    return VaccineRecord.fromApi(data);
  }

  Future<List<VaccineRecord>> getVaccinesByCattle(
    int cattleId,
  ) async {
    final List<VaccineRecord> vaccinations = await getAllVaccines();

    return vaccinations
        .where(
          (VaccineRecord vaccination) => vaccination.cattleId == cattleId,
        )
        .toList();
  }

  Future<List<VaccineRecord>> getUpcomingVaccines({
    int days = 30,
  }) async {
    final List<VaccineRecord> vaccinations = await getAllVaccines();

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime limit = today.add(
      Duration(days: days),
    );

    final List<VaccineRecord> result = vaccinations.where(
      (VaccineRecord vaccination) {
        final DateTime? nextDate = vaccination.nextDoseDate;

        if (nextDate == null) {
          return false;
        }

        final DateTime date = DateTime(
          nextDate.year,
          nextDate.month,
          nextDate.day,
        );

        return !date.isBefore(today) && !date.isAfter(limit);
      },
    ).toList();

    result.sort(
      (VaccineRecord a, VaccineRecord b) => a.nextDoseDate!.compareTo(
        b.nextDoseDate!,
      ),
    );

    return result;
  }

  Future<List<VaccineRecord>> getOverdueVaccines() async {
    final List<VaccineRecord> vaccinations = await getAllVaccines();

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final List<VaccineRecord> result = vaccinations.where(
      (VaccineRecord vaccination) {
        final DateTime? nextDate = vaccination.nextDoseDate;

        if (nextDate == null) {
          return false;
        }

        final DateTime date = DateTime(
          nextDate.year,
          nextDate.month,
          nextDate.day,
        );

        return date.isBefore(today);
      },
    ).toList();

    result.sort(
      (VaccineRecord a, VaccineRecord b) => a.nextDoseDate!.compareTo(
        b.nextDoseDate!,
      ),
    );

    return result;
  }

  Future<int> updateVaccineRecord(
    VaccineRecord vaccine,
  ) async {
    if (vaccine.id == null) {
      throw ArgumentError(
        'La vacunación no tiene identificador.',
      );
    }

    final response = await _apiClient.put(
      '/vacunaciones/${vaccine.id}',
      body: vaccine.toUpdateApi(),
    );

    if (response.statusCode == 401) {
      throw StateError(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw StateError(
        'No tienes permiso para modificar esta vacunación.',
      );
    }

    if (response.statusCode == 404) {
      throw StateError(
        'La vacunación ya no existe.',
      );
    }

    if (response.statusCode == 422) {
      throw StateError(
        _extractMessage(
          response.body,
          'Revisa los datos de la vacunación.',
        ),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        _extractMessage(
          response.body,
          'No fue posible actualizar la vacunación.',
        ),
      );
    }

    return 1;
  }

  Future<int> deleteVaccineRecord(
    int id,
  ) async {
    final response = await _apiClient.delete(
      '/vacunaciones/$id',
    );

    if (response.statusCode == 401) {
      throw StateError(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw StateError(
        'No tienes permiso para eliminar esta vacunación.',
      );
    }

    if (response.statusCode == 404) {
      throw StateError(
        'La vacunación ya no existe.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        _extractMessage(
          response.body,
          'No fue posible eliminar la vacunación.',
        ),
      );
    }

    return 1;
  }

  Future<int> countVaccines() async {
    final List<VaccineRecord> vaccinations = await getAllVaccines();

    return vaccinations.length;
  }

  Future<int> countUpcomingVaccines({
    int days = 30,
  }) async {
    final List<VaccineRecord> vaccinations = await getUpcomingVaccines(
      days: days,
    );

    return vaccinations.length;
  }

  Future<int> countOverdueVaccines() async {
    final List<VaccineRecord> vaccinations = await getOverdueVaccines();

    return vaccinations.length;
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
      // Se usa el mensaje predeterminado.
    }

    return fallback;
  }
}
