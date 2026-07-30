import 'package:flutter/material.dart';

import '../../../../core/widgets/app_text_field.dart';
import '../../data/repositories/auth_repository.dart';

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final AuthRepository _authRepository = AuthRepository();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _newPasswordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSaving = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  Future<void> _recoverPassword() async {
    if (_isSaving) {
      return;
    }

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final bool changed = await _authRepository.resetPassword(
        email: _emailController.text,
        newPassword: _newPasswordController.text,
      );

      if (!changed) {
        _showMessage(
          'No existe un usuario con ese correo.',
        );
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contraseña actualizada correctamente.',
          ),
        ),
      );

      Navigator.pop(
        context,
        _emailController.text.trim(),
      );
    } catch (error) {
      _showMessage(
        'No se pudo actualizar la contraseña: $error',
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recuperar contraseña',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Icon(
              Icons.lock_reset,
              size: 72,
            ),
            const SizedBox(height: 12),
            const Text(
              'Ingresa el correo registrado y establece una contraseña nueva.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Correo electrónico',
              controller: _emailController,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa el correo registrado';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Nueva contraseña',
              controller: _newPasswordController,
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
                  return 'Ingresa una contraseña nueva';
                }

                if (value.length < 6) {
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
                if (value != _newPasswordController.text) {
                  return 'Las contraseñas no coinciden';
                }

                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _recoverPassword,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.lock_reset),
              label: Text(
                _isSaving ? 'Actualizando...' : 'Cambiar contraseña',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
