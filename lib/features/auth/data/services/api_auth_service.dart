import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/session/session_manager.dart';

class ApiAuthService {
  final ApiClient _apiClient;

  ApiAuthService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/login',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final String? token = data['token']?.toString();

      if (token == null || token.isEmpty) {
        throw Exception(
          'El servidor no devolvió el token de autenticación.',
        );
      }

      await SessionManager.instance.setApiToken(token);

      final String? storedToken =
          await SessionManager.instance.getStoredApiToken();

      print('=== TOKEN API GUARDADO ===');
      print('Recibido: ${token.isNotEmpty}');
      print('Longitud recibido: ${token.length}');
      print('Guardado: ${storedToken != null && storedToken.isNotEmpty}');
      print('Longitud guardado: ${storedToken?.length ?? 0}');
      print('¿Coinciden?: ${storedToken == token}');
      print('=========================');

      return data;
    }

    if (response.statusCode == 422) {
      throw Exception(
        'Correo o contraseña incorrectos.',
      );
    }

    if (response.statusCode == 401) {
      throw Exception(
        'No fue posible autenticar al usuario.',
      );
    }

    throw Exception(
      'Error del servidor (${response.statusCode}).',
    );
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _apiClient.post(
      '/register',
      body: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201) {
      final String? token = data['token']?.toString();

      if (token == null || token.isEmpty) {
        throw Exception(
          'El servidor no devolvió el token de autenticación.',
        );
      }

      await SessionManager.instance.setApiToken(token);

      return data;
    }

    if (response.statusCode == 422) {
      final dynamic errors = data['errors'];

      if (errors is Map<String, dynamic>) {
        if (errors.containsKey('email')) {
          throw Exception(
            'Este correo electrónico ya está registrado.',
          );
        }

        if (errors.containsKey('password')) {
          throw Exception(
            'La contraseña no cumple con los requisitos.',
          );
        }
      }

      throw Exception(
        'Revisa los datos del registro.',
      );
    }

    throw Exception(
      'Error del servidor (${response.statusCode}).',
    );
  }
}
