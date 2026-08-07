import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/models/user_model.dart';

class SessionManager {
  SessionManager._internal();

  static final SessionManager instance = SessionManager._internal();

  static const String _userIdKey = 'session_user_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  int? get currentUserId => _currentUser?.id;

  bool get isLoggedIn => _currentUser != null;

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

  Future<int?> getStoredUserId() async {
    final String? storedValue = await _storage.read(
      key: _userIdKey,
    );

    if (storedValue == null) {
      return null;
    }

    return int.tryParse(
      storedValue,
    );
  }

  Future<void> clearSession() async {
    _currentUser = null;

    await _storage.delete(
      key: _userIdKey,
    );
  }
}
