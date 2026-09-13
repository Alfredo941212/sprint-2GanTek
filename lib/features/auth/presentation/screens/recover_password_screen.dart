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

  bool _isSaving = false;

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

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
      await _authRepository.sendPasswordResetEmail(
        email: _emailController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Te enviamos un enlace para restablecer tu contraseña. Revisa tu correo electrónico.',
            ),
          ),
        );

      Navigator.pop<String>(
        context,
        _emailController.text.trim(),
      );
    } catch (error) {
      _showMessage(
        error.toString().replaceFirst(
              'Exception: ',
              '',
            ),
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
    _emailController.dispose();

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
            const SizedBox(height: 12),
            const Icon(
              Icons.lock_reset,
              size: 72,
            ),
            const SizedBox(height: 18),
            Text(
              'Recupera tu cuenta',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Ingresa el correo registrado en GanTek y te enviaremos un enlace para restablecer tu contraseña.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            AppTextField(
              label: 'Correo electrónico',
              controller: _emailController,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final String email = value?.trim() ?? '';

                if (email.isEmpty) {
                  return 'Ingresa tu correo electrónico';
                }

                if (!_isValidEmail(email)) {
                  return 'Ingresa un correo válido';
                }

                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _recoverPassword,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.mark_email_read_outlined,
                      ),
                label: Text(
                  _isSaving ? 'Enviando...' : 'Enviar enlace',
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Después de cambiar tu contraseña desde el correo, podrás regresar a GanTek e iniciar sesión con la nueva contraseña.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
