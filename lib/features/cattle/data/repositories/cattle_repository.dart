import '../models/cattle.dart';
import 'dart:convert';

import '../../../../core/network/api_client.dart';

class CattleRepository {
  // =========================================================
  // OBTENER USUARIO ACTUAL
  // =========================================================

  // =========================================================
  // REGISTRAR GANADO
  // =========================================================

  Future<int> insertCattle(
    Cattle cattle,
  ) async {
    final int? lotId = cattle.lotId;

    if (lotId == null) {
      throw Exception(
        'Debes seleccionar un lote.',
      );
    }

    final Map<String, dynamic> body = {
      'lote_id': lotId,
      'arete_siniiga': cattle.code.trim(),
      'nombre': cattle.name.trim().isEmpty ? null : cattle.name.trim(),
      'sexo': cattle.sex,
      'raza': cattle.breed.trim().isEmpty ? null : cattle.breed.trim(),
      'fecha_nacimiento': cattle.birthDate == null
          ? null
          : _formatApiDate(
              cattle.birthDate!,
            ),
      'fecha_ingreso': _formatApiDate(
        cattle.entryDate,
      ),
      'peso_inicial': cattle.initialWeight,
      'estado_productivo': cattle.productiveStatus,
      'produccion_minima_diaria': cattle.minimumDailyProduction,
      'estado': cattle.status,
      'observaciones': cattle.observations.trim().isEmpty
          ? null
          : cattle.observations.trim(),
    };

    final response = await ApiClient.instance.post(
      '/ganado',
      body: body,
    );

    if (response.statusCode == 201) {
      final dynamic decoded = jsonDecode(
        response.body,
      );

      if (decoded is Map<String, dynamic>) {
        final dynamic data = decoded['data'];

        if (data is Map<String, dynamic>) {
          final dynamic id = data['id'];

          if (id is int) {
            return id;
          }

          return int.tryParse(
                id?.toString() ?? '',
              ) ??
              0;
        }
      }

      return 0;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para registrar ganado.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        _extractApiError(
          response.body,
          'Los datos del ganado no son válidos.',
        ),
      );
    }

    throw Exception(
      'No fue posible registrar el ganado '
      '(${response.statusCode}).',
    );
  }

  // =========================================================
  // OBTENER TODO EL GANADO DEL USUARIO
  // =========================================================

  Future<List<Cattle>> getAllCattle() async {
    final response = await ApiClient.instance.get(
      '/ganado',
    );

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'No fue posible cargar el ganado '
        '(${response.statusCode}).',
      );
    }

    final dynamic decoded = jsonDecode(
      response.body,
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'El servidor devolvió una respuesta inválida.',
      );
    }

    final dynamic data = decoded['data'];

    if (data is! List) {
      throw Exception(
        'El servidor no devolvió la lista de ganado.',
      );
    }

    return data.whereType<Map<String, dynamic>>().map(Cattle.fromApi).toList();
  }

  // =========================================================
  // OBTENER GANADO POR ID
  // =========================================================

  Future<Cattle?> getCattleById(
    int id,
  ) async {
    final response = await ApiClient.instance.get(
      '/ganado/$id',
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para consultar este animal.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'No fue posible cargar el ganado '
        '(${response.statusCode}).',
      );
    }

    final dynamic decoded = jsonDecode(
      response.body,
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'El servidor devolvió una respuesta inválida.',
      );
    }

    final dynamic data = decoded['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'El servidor no devolvió la información del animal.',
      );
    }

    return Cattle.fromApi(data);
  }

  // =========================================================
  // VERIFICAR SI EL CÓDIGO / ARETE YA EXISTE
  // =========================================================

  Future<bool> codeExists(
    String code, {
    int? excludeCattleId,
  }) async {
    final List<Cattle> cattle = await getAllCattle();

    final String normalizedCode = code.trim().toLowerCase();

    return cattle.any(
      (Cattle animal) {
        if (excludeCattleId != null && animal.id == excludeCattleId) {
          return false;
        }

        return animal.code.trim().toLowerCase() == normalizedCode;
      },
    );
  }

  // =========================================================
  // ACTUALIZAR GANADO
  // =========================================================

  Future<int> updateCattle(
    Cattle cattle,
  ) async {
    final int? cattleId = cattle.id;

    if (cattleId == null) {
      throw ArgumentError(
        'No se puede actualizar un animal sin identificador.',
      );
    }

    final int? lotId = cattle.lotId;

    if (lotId == null) {
      throw Exception(
        'Debes seleccionar un lote.',
      );
    }

    final Map<String, dynamic> body = {
      'lote_id': lotId,
      'arete_siniiga': cattle.code.trim(),
      'nombre': cattle.name.trim().isEmpty ? null : cattle.name.trim(),
      'sexo': cattle.sex,
      'raza': cattle.breed.trim().isEmpty ? null : cattle.breed.trim(),
      'fecha_nacimiento':
          cattle.birthDate == null ? null : _formatApiDate(cattle.birthDate!),
      'fecha_ingreso': _formatApiDate(cattle.entryDate),
      'peso_inicial': cattle.initialWeight,
      'estado_productivo': cattle.productiveStatus,
      'produccion_minima_diaria': cattle.minimumDailyProduction,
      'estado': cattle.status,
      'observaciones': cattle.observations.trim().isEmpty
          ? null
          : cattle.observations.trim(),
    };

    final response = await ApiClient.instance.put(
      '/ganado/$cattleId',
      body: body,
    );

    if (response.statusCode == 200) {
      return 1;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para actualizar este animal.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'El animal no existe o ya no está disponible.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        _extractApiError(
          response.body,
          'Los datos del ganado no son válidos.',
        ),
      );
    }

    throw Exception(
      'No fue posible actualizar el ganado '
      '(${response.statusCode}).',
    );
  }

  // =========================================================
  // ELIMINAR GANADO
  // =========================================================

  Future<int> deleteCattle(int id) async {
    final response = await ApiClient.instance.delete(
      '/ganado/$id',
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return 1;
    }

    if (response.statusCode == 401) {
      throw Exception(
        'La sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para dar de baja este animal.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'El animal no existe o ya no está disponible.',
      );
    }

    throw Exception(
      'No fue posible dar de baja el animal (${response.statusCode}).',
    );
  }

  // =========================================================
  // OBTENER GANADO ACTIVO
  // =========================================================

  Future<List<Cattle>> getActiveCattle() async {
    final List<Cattle> cattle = await getAllCattle();

    return cattle
        .where(
          (Cattle animal) => animal.status == 'Activo',
        )
        .toList();
  }

  // =========================================================
  // OBTENER VACAS EN PRODUCCIÓN
  // =========================================================

  Future<List<Cattle>> getProductiveCattle() async {
    final List<Cattle> cattle = await getAllCattle();

    final List<Cattle> productiveCattle = cattle.where((Cattle animal) {
      return animal.status == 'Activo' &&
          animal.productiveStatus == 'En producción' &&
          animal.sex == 'Hembra';
    }).toList();

    productiveCattle.sort(
      (Cattle a, Cattle b) => a.code.compareTo(b.code),
    );

    return productiveCattle;
  }

  // =========================================================
  // OBTENER GANADO POR LOTE
  // =========================================================

  Future<List<Cattle>> getCattleByLot(
    int lotId,
  ) async {
    final List<Cattle> cattle = await getAllCattle();

    final List<Cattle> cattleByLot = cattle.where((Cattle animal) {
      return animal.lotId == lotId;
    }).toList();

    cattleByLot.sort(
      (Cattle a, Cattle b) => a.code.compareTo(b.code),
    );

    return cattleByLot;
  }

  // =========================================================
  // CONTAR GANADO
  // =========================================================

  Future<int> countCattle() async {
    final List<Cattle> cattle = await getActiveCattle();

    return cattle.length;
  }

  // =========================================================
  // CONTAR VACAS EN PRODUCCIÓN
  // =========================================================

  Future<int> countProductiveCattle() async {
    final List<Cattle> cattle = await getProductiveCattle();

    return cattle.length;
  }

  String _formatApiDate(
    DateTime date,
  ) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _extractApiError(
    String responseBody,
    String fallback,
  ) {
    try {
      final dynamic decoded = jsonDecode(
        responseBody,
      );

      if (decoded is! Map<String, dynamic>) {
        return fallback;
      }

      final dynamic errors = decoded['errors'];

      if (errors is Map) {
        for (final dynamic value in errors.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }

          if (value != null) {
            return value.toString();
          }
        }
      }

      final dynamic message = decoded['message'];

      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    } catch (_) {
      // Se utiliza el mensaje genérico.
    }

    return fallback;
  }
}
