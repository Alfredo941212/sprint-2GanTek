import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../models/veterinarian.dart';

class VeterinarianRepository {
  // =========================================================
  // REGISTRAR
  // =========================================================

  Future<int> insertVeterinarian(
    Veterinarian veterinarian,
  ) async {
    final String name = veterinarian.name.trim();
    final String license = veterinarian.professionalLicense?.trim() ?? '';

    if (name.isEmpty) {
      throw Exception(
        'El nombre del veterinario es obligatorio.',
      );
    }

    if (license.isEmpty) {
      throw Exception(
        'La cédula profesional es obligatoria.',
      );
    }

    final response = await ApiClient.instance.post(
      '/veterinarios',
      body: veterinarian.toApi(),
    );

    if (response.statusCode == 401) {
      throw Exception(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para registrar veterinarios.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        _extractMessage(
          response.body,
          'Los datos del veterinario no son válidos.',
        ),
      );
    }

    if (response.statusCode != 201) {
      throw Exception(
        'No se pudo registrar el veterinario. '
        'Código ${response.statusCode}.',
      );
    }

    final dynamic decoded = jsonDecode(
      response.body,
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'La respuesta del servidor no es válida.',
      );
    }

    final dynamic data = decoded['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'No se recibió el veterinario registrado.',
      );
    }

    final Veterinarian created = Veterinarian.fromApi(data);

    if (created.id == null) {
      throw Exception(
        'El servidor no devolvió el ID del veterinario.',
      );
    }

    return created.id!;
  }

  // =========================================================
  // OBTENER TODOS
  // =========================================================

  Future<List<Veterinarian>> getAllVeterinarians() async {
    final response = await ApiClient.instance.get(
      '/veterinarios',
    );

    if (response.statusCode == 401) {
      throw Exception(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudieron obtener los veterinarios. '
        'Código ${response.statusCode}.',
      );
    }

    final dynamic decoded = jsonDecode(
      response.body,
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'La respuesta de veterinarios no es válida.',
      );
    }

    final dynamic data = decoded['data'];

    if (data is! List) {
      throw Exception(
        'La lista de veterinarios no es válida.',
      );
    }

    final List<Veterinarian> veterinarians = data
        .whereType<Map<String, dynamic>>()
        .map(
          (Map<String, dynamic> item) => Veterinarian.fromApi(item),
        )
        .toList();

    veterinarians.sort(
      (Veterinarian a, Veterinarian b) => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ),
    );

    return veterinarians;
  }

  // =========================================================
  // OBTENER ACTIVOS
  // =========================================================

  Future<List<Veterinarian>> getActiveVeterinarians() async {
    final List<Veterinarian> veterinarians = await getAllVeterinarians();

    return veterinarians
        .where(
          (Veterinarian veterinarian) => veterinarian.status == 'Activo',
        )
        .toList();
  }

  // =========================================================
  // OBTENER POR ID
  // =========================================================

  Future<Veterinarian?> getVeterinarianById(
    int id,
  ) async {
    final response = await ApiClient.instance.get(
      '/veterinarios/$id',
    );

    if (response.statusCode == 401) {
      throw Exception(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo obtener el veterinario. '
        'Código ${response.statusCode}.',
      );
    }

    final dynamic decoded = jsonDecode(
      response.body,
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'La respuesta del veterinario no es válida.',
      );
    }

    final dynamic data = decoded['data'];

    if (data is! Map<String, dynamic>) {
      return null;
    }

    return Veterinarian.fromApi(data);
  }

  // =========================================================
  // VALIDAR CÉDULA
  // =========================================================

  Future<bool> professionalLicenseExists(
    String professionalLicense, {
    int? excludeVeterinarianId,
  }) async {
    final String license = professionalLicense.trim().toLowerCase();

    if (license.isEmpty) {
      return false;
    }

    final List<Veterinarian> veterinarians = await getAllVeterinarians();

    return veterinarians.any(
      (Veterinarian veterinarian) {
        final String currentLicense =
            veterinarian.professionalLicense?.trim().toLowerCase() ?? '';

        final bool sameLicense = currentLicense == license;

        final bool excluded = excludeVeterinarianId != null &&
            veterinarian.id == excludeVeterinarianId;

        return sameLicense && !excluded;
      },
    );
  }

  // =========================================================
  // ACTUALIZAR
  // =========================================================

  Future<int> updateVeterinarian(
    Veterinarian veterinarian,
  ) async {
    final int? veterinarianId = veterinarian.id;

    if (veterinarianId == null) {
      throw Exception(
        'No se puede actualizar un veterinario sin ID.',
      );
    }

    if (veterinarian.name.trim().isEmpty) {
      throw Exception(
        'El nombre del veterinario es obligatorio.',
      );
    }

    if (veterinarian.professionalLicense?.trim().isEmpty ?? true) {
      throw Exception(
        'La cédula profesional es obligatoria.',
      );
    }

    final response = await ApiClient.instance.put(
      '/veterinarios/$veterinarianId',
      body: veterinarian.toApi(),
    );

    if (response.statusCode == 401) {
      throw Exception(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para editar veterinarios.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'El veterinario ya no existe.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        _extractMessage(
          response.body,
          'Los datos del veterinario no son válidos.',
        ),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo actualizar el veterinario. '
        'Código ${response.statusCode}.',
      );
    }

    return 1;
  }

  // =========================================================
  // DESACTIVAR
  // =========================================================

  Future<int> deleteVeterinarian(
    int veterinarianId,
  ) async {
    final response = await ApiClient.instance.delete(
      '/veterinarios/$veterinarianId',
    );

    if (response.statusCode == 401) {
      throw Exception(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'No tienes permiso para desactivar veterinarios.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'El veterinario ya no existe.',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        _extractMessage(
          response.body,
          'No se pudo desactivar el veterinario.',
        ),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo desactivar el veterinario. '
        'Código ${response.statusCode}.',
      );
    }

    return 1;
  }

  // =========================================================
  // AUXILIAR
  // =========================================================

  String _extractMessage(
    String body,
    String fallback,
  ) {
    try {
      final dynamic decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        final dynamic errors = decoded['errors'];

        if (errors is Map<String, dynamic>) {
          for (final dynamic value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return value.first.toString();
            }
          }
        }

        final dynamic message = decoded['message'];

        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {
      // Se utiliza el mensaje predeterminado.
    }

    return fallback;
  }
}
