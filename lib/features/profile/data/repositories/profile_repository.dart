import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/session/session_manager.dart';
import '../../../auth/data/models/user_model.dart';

class ProfileRepository {
  final ApiClient _apiClient = ApiClient.instance;

  Future<UserModel> getProfile() async {
    final response = await _apiClient.get('/perfil');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo obtener el perfil. Código: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del servidor.');
    }

    final data = decoded['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('Datos de perfil inválidos.');
    }

    final currentUser = SessionManager.instance.currentUser;

    if (currentUser == null) {
      throw Exception('No hay un usuario autenticado.');
    }

    final updatedUser = currentUser.copyWith(
      fullName: data['name']?.toString() ?? currentUser.fullName,
      email: data['email']?.toString() ?? currentUser.email,
      phone: data['phone']?.toString() ?? '',
      avatar: data['avatar']?.toString() ?? '',
    );

    await SessionManager.instance.setCurrentUser(updatedUser);

    return updatedUser;
  }

  Future<UserModel> updateProfile({
    required String name,
    required String phone,
  }) async {
    final response = await _apiClient.patch(
      '/perfil',
      body: {
        'name': name.trim(),
        'phone': phone.trim().isEmpty ? null : phone.trim(),
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo actualizar el perfil. Código: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del servidor.');
    }

    final data = decoded['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('Datos de perfil inválidos.');
    }

    final currentUser = SessionManager.instance.currentUser;

    if (currentUser == null) {
      throw Exception('No hay un usuario autenticado.');
    }

    final updatedUser = currentUser.copyWith(
      fullName: data['name']?.toString() ?? currentUser.fullName,
      email: data['email']?.toString() ?? currentUser.email,
      phone: data['phone']?.toString() ?? '',
      avatar: data['avatar']?.toString() ?? currentUser.avatar,
    );

    await SessionManager.instance.setCurrentUser(updatedUser);

    return updatedUser;
  }
}
