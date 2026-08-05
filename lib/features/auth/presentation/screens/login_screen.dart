import 'package:flutter/material.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import 'recover_password_screen.dart';
import 'register_user_screen.dart';
import '../../../../core/security/login_attempt_manager.dart';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LoginAttemptManager _attemptManager = LoginAttemptManager.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final AuthRepository _authRepository = AuthRepository();

  Timer? _lockTimer;
  int _remainingSeconds = 0;
  bool _isLoading = false;
  bool _hidePassword = true;

  void _startLockTimer() {
    _lockTimer?.cancel();

    setState(() {
      _remainingSeconds = _attemptManager.remainingSeconds;
    });

    _lockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final int seconds = _attemptManager.remainingSeconds;

        setState(() {
          _remainingSeconds = seconds;
        });

        if (!_attemptManager.isBlocked) {
          timer.cancel();

          setState(() {
            _remainingSeconds = 0;
          });
        }
      },
    );
  }

  Future<void> _login() async {
    if (_isLoading) {
      return;
    }

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }
    if (_attemptManager.isBlocked) {
      _startLockTimer();

      _showMessage(
        'Demasiados intentos fallidos. '
        'Espera ${_attemptManager.remainingSeconds} segundos.',
      );

      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final UserModel? user = await _authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (user == null) {
        _showMessage(
          'Correo o contraseña incorrectos.',
        );
        return;
      }
      SessionManager.instance.setCurrentUser(user);
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } catch (error) {
      _showMessage(
        'No fue posible iniciar sesión: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openRegisterUser() async {
    final String? registeredEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterUserScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    if (registeredEmail == null) {
      return;
    }

    _emailController.text = registeredEmail;
    _passwordController.clear();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Cuenta creada. Ingresa tu contraseña para iniciar sesión.',
          ),
        ),
      );
  }

  Future<void> _openRecoverPassword() async {
    final String? recoveredEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const RecoverPasswordScreen(),
      ),
    );

    if (recoveredEmail != null) {
      _emailController.text = recoveredEmail;
      _passwordController.clear();

      _showMessage(
        'Contraseña actualizada. Ya puedes iniciar sesión.',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primary,
                      child: Icon(
                        Icons.agriculture,
                        size: 54,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'GanTek',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Gestión inteligente de ganado',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    AppTextField(
                      label: 'Correo electrónico',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final String email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Ingresa tu correo';
                        }

                        if (!email.contains('@') || !email.contains('.')) {
                          return 'Ingresa un correo válido';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Contraseña',
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      obscureText: _hidePassword,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _hidePassword = !_hidePassword;
                          });
                        },
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa tu contraseña';
                        }

                        if (value.length < 6) {
                          return 'Mínimo 6 caracteres';
                        }

                        return null;
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _openRecoverPassword,
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading || _attemptManager.isBlocked
                            ? null
                            : _login,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          _attemptManager.isBlocked
                              ? 'Bloqueado: $_remainingSeconds s'
                              : _isLoading
                                  ? 'Iniciando sesión...'
                                  : 'Iniciar sesión',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Flexible(
                          child: Text(
                            '¿No tienes una cuenta?',
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _openRegisterUser,
                          child: const Text(
                            'Crear usuario',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
