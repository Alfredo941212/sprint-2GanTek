import '../../features/auth/data/models/user_model.dart';

class SessionManager {
  SessionManager._internal();

  static final SessionManager instance = SessionManager._internal();

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  int? get currentUserId => _currentUser?.id;

  bool get isLoggedIn => _currentUser != null;

  void setCurrentUser(UserModel user) {
    _currentUser = user;
  }

  void clearSession() {
    _currentUser = null;
  }
}
