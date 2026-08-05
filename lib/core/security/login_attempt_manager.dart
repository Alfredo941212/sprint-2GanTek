class LoginAttemptManager {
  LoginAttemptManager._internal();

  static final LoginAttemptManager instance = LoginAttemptManager._internal();

  static const int maximumAttempts = 5;
  static const Duration lockDuration = Duration(seconds: 30);

  int _failedAttempts = 0;
  DateTime? _blockedUntil;

  int get failedAttempts => _failedAttempts;

  bool get isBlocked {
    final DateTime? blockedUntil = _blockedUntil;

    if (blockedUntil == null) {
      return false;
    }

    if (DateTime.now().isAfter(blockedUntil)) {
      reset();
      return false;
    }

    return true;
  }

  int get remainingSeconds {
    if (!isBlocked || _blockedUntil == null) {
      return 0;
    }

    final int seconds = _blockedUntil!.difference(DateTime.now()).inSeconds;

    return seconds < 0 ? 0 : seconds;
  }

  void registerFailedAttempt() {
    if (isBlocked) {
      return;
    }

    _failedAttempts++;

    if (_failedAttempts >= maximumAttempts) {
      _blockedUntil = DateTime.now().add(
        lockDuration,
      );

      _failedAttempts = 0;
    }
  }

  void registerSuccessfulLogin() {
    reset();
  }

  void reset() {
    _failedAttempts = 0;
    _blockedUntil = null;
  }
}
