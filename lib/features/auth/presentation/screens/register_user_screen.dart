import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/widgets/app_text_field.dart';
import '../../data/repositories/auth_repository.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final AuthRepository _authRepository = AuthRepository();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSaving = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  Future<void> _registerUser() async {
    if (_isSaving) {
      return;
    }

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final String fullName = _nameController.text.trim();

    final String email = _emailController.text.trim().toLowerCase();

    final String phone = _phoneController.text.trim();

    final String password = _passwordController.text;

    setState(() {
      _isSaving = true;
    });

    try {
      final bool exists = await _authRepository.emailExists(email);

      if (exists) {
        _showMessage(
          'Ya existe un usuario registrado con este correo.',
        );
        return;
      }

      await _authRepository.registerUser(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );

      if (!mounted) {
        return;
      }

      // Cierra solamente la pantalla de registro
      // y devuelve el correo al inicio de sesión.
      Navigator.pop<String>(
        context,
        email,
      );
    } on DatabaseException catch (error) {
      _showMessage(
        'No se pudo registrar el usuario: $error',
      );
    } catch (error) {
      _showMessage(
        'Ocurrió un error inesperado: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear usuario'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Icon(
              Icons.person_add_alt_1,
              size: 72,
            ),
            const SizedBox(height: 12),
            Text(
              'Crea tu cuenta en GanTek',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Nombre completo',
              controller: _nameController,
              icon: Icons.person_outline,
              validator: (value) {
                final String name = value?.trim() ?? '';

                if (name.isEmpty) {
                  return 'Ingresa tu nombre completo';
                }

                if (name.length < 4) {
                  return 'El nombre es demasiado corto';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
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

                if (!_isValidEmail(email)) {
                  return 'Ingresa un correo válido';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Número telefónico',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                final String phone = value?.trim() ?? '';

                if (phone.isEmpty) {
                  return 'Ingresa tu número telefónico';
                }

                if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
                  return 'Ingresa exactamente 10 dígitos';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Contraseña',
              controller: _passwordController,
              icon: Icons.lock_outline,
              obscureText: _hidePassword,
              suffixIcon: IconButton(
                tooltip:
                    _hidePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
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
                final String password = value ?? '';

                if (password.isEmpty) {
                  return 'Ingresa una contraseña';
                }

                if (password.length < 6) {
                  return 'Usa al menos 6 caracteres';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Confirmar contraseña',
              controller: _confirmPasswordController,
              icon: Icons.lock_reset_outlined,
              obscureText: _hideConfirmPassword,
              suffixIcon: IconButton(
                tooltip: _hideConfirmPassword
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                onPressed: () {
                  setState(() {
                    _hideConfirmPassword = !_hideConfirmPassword;
                  });
                },
                icon: Icon(
                  _hideConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) {
                final String confirmation = value ?? '';

                if (confirmation.isEmpty) {
                  return 'Confirma tu contraseña';
                }

                if (confirmation != _passwordController.text) {
                  return 'Las contraseñas no coinciden';
                }

                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _registerUser,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.person_add_outlined,
                      ),
                label: Text(
                  _isSaving ? 'Registrando...' : 'Crear cuenta',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
