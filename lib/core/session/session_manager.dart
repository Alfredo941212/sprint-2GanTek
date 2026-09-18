import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/models/user_model.dart';

class SessionManager {
  SessionManager._internal();

  static final SessionManager instance = SessionManager._internal();

  static const String _userIdKey = 'session_user_id';
  static const String _apiTokenKey = 'api_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  UserModel? _currentUser;
  String? _apiToken;

  UserModel? get currentUser => _currentUser;

  int? get currentUserId => _currentUser?.id;

  String? get apiToken => _apiToken;

  bool get isLoggedIn => _currentUser != null;

  bool get hasApiToken => _apiToken != null && _apiToken!.isNotEmpty;

  Future<void> setCurrentUser(
    UserModel user,
  ) async {
    if (user.id == null) {
      throw ArgumentError(
        'El usuario no tiene identificador.',
      );
    }

    _currentUser = user;

    await _storage.write(
      key: _userIdKey,
      value: user.id.toString(),
    );
  }

  Future<void> setApiToken(String token) async {
    _apiToken = token;

    await _storage.write(
      key: _apiTokenKey,
      value: token,
    );
  }

  Future<int?> getStoredUserId() async {
    final String? storedValue = await _storage.read(
      key: _userIdKey,
    );

    if (storedValue == null) {
      return null;
    }

    return int.tryParse(storedValue);
  }

  Future<String?> getStoredApiToken() async {
    _apiToken ??= await _storage.read(
      key: _apiTokenKey,
    );

    return _apiToken;
  }

  Future<void> clearSession() async {
    _currentUser = null;
    _apiToken = null;

    await _storage.delete(
      key: _userIdKey,
    );

    await _storage.delete(
      key: _apiTokenKey,
    );
  }
}
