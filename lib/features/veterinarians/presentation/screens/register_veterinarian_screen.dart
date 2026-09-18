import 'package:flutter/material.dart';

import '../../data/models/veterinarian.dart';
import '../../data/repositories/veterinarian_repository.dart';

class RegisterVeterinarianScreen extends StatefulWidget {
  const RegisterVeterinarianScreen({
    super.key,
    this.veterinarian,
  });

  final Veterinarian? veterinarian;

  bool get isEditing => veterinarian != null;

  @override
  State<RegisterVeterinarianScreen> createState() =>
      _RegisterVeterinarianScreenState();
}

class _RegisterVeterinarianScreenState
    extends State<RegisterVeterinarianScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final VeterinarianRepository _repository = VeterinarianRepository();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _licenseController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _specialtyController = TextEditingController();

  final TextEditingController _observationsController = TextEditingController();

  String _status = 'Activo';

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final Veterinarian? veterinarian = widget.veterinarian;

    if (veterinarian != null) {
      _nameController.text = veterinarian.name;

      _licenseController.text = veterinarian.professionalLicense ?? '';

      _phoneController.text = veterinarian.phone ?? '';

      _emailController.text = veterinarian.email ?? '';

      _specialtyController.text = veterinarian.specialty ?? '';

      _observationsController.text = veterinarian.observations ?? '';

      _status = veterinarian.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _licenseController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _specialtyController.dispose();
    _observationsController.dispose();

    super.dispose();
  }

  // =========================================================
  // GUARDAR
  // =========================================================

  Future<void> _saveVeterinarian() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final Veterinarian veterinarian = Veterinarian(
        id: widget.veterinarian?.id,
        name: _nameController.text.trim(),
        professionalLicense: _licenseController.text.trim().isEmpty
            ? null
            : _licenseController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        specialty: _specialtyController.text.trim().isEmpty
            ? null
            : _specialtyController.text.trim(),
        status: _status,
        observations: _observationsController.text.trim().isEmpty
            ? null
            : _observationsController.text.trim(),
        createdAt: widget.veterinarian?.createdAt,
      );

      if (widget.isEditing) {
        await _repository.updateVeterinarian(
          veterinarian,
        );
      } else {
        await _repository.insertVeterinarian(
          veterinarian,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  // =========================================================
  // VALIDACIONES
  // =========================================================

  String? _validateName(
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa el nombre del veterinario.';
    }

    if (value.trim().length < 3) {
      return 'El nombre es demasiado corto.';
    }

    return null;
  }

  String? _validateLicense(
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa la cédula profesional.';
    }

    if (value.trim().length > 50) {
      return 'La cédula profesional no puede superar 50 caracteres.';
    }

    return null;
  }

  String? _validatePhone(
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final String phone = value.trim();

    final RegExp expression = RegExp(
      r'^[0-9]{10}$',
    );

    if (!expression.hasMatch(phone)) {
      return 'El teléfono debe tener 10 dígitos.';
    }

    return null;
  }

  String? _validateEmail(
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final String email = value.trim();

    final RegExp expression = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!expression.hasMatch(email)) {
      return 'Ingresa un correo válido.';
    }

    return null;
  }

  // =========================================================
  // INTERFAZ
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Editar veterinario' : 'Registrar veterinario',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(
            16,
          ),
          children: [
            // ===============================================
            // NOMBRE
            // ===============================================

            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              validator: _validateName,
              decoration: const InputDecoration(
                labelText: 'Nombre del veterinario *',
                prefixIcon: Icon(
                  Icons.person_outline,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ===============================================
            // CÉDULA
            // ===============================================

            TextFormField(
              controller: _licenseController,
              validator: _validateLicense,
              decoration: const InputDecoration(
                labelText: 'Cédula profesional *',
                prefixIcon: Icon(
                  Icons.badge_outlined,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ===============================================
            // TELÉFONO
            // ===============================================

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(
                  Icons.phone_outlined,
                ),
                border: OutlineInputBorder(),
                helperText: '10 dígitos',
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ===============================================
            // CORREO
            // ===============================================

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(
                  Icons.email_outlined,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ===============================================
            // ESPECIALIDAD
            // ===============================================

            TextFormField(
              controller: _specialtyController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Especialidad',
                prefixIcon: Icon(
                  Icons.medical_services_outlined,
                ),
                border: OutlineInputBorder(),
                hintText: 'Ej. Bovinos',
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ===============================================
            // ESTADO
            // ===============================================

            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Estado',
                prefixIcon: Icon(
                  Icons.toggle_on_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Activo',
                  child: Text(
                    'Activo',
                  ),
                ),
                DropdownMenuItem(
                  value: 'Inactivo',
                  child: Text(
                    'Inactivo',
                  ),
                ),
              ],
              onChanged: (
                String? value,
              ) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _status = value;
                });
              },
            ),

            const SizedBox(
              height: 16,
            ),

            // ===============================================
            // OBSERVACIONES
            // ===============================================

            TextFormField(
              controller: _observationsController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observaciones',
                prefixIcon: Icon(
                  Icons.notes_outlined,
                ),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            // ===============================================
            // BOTÓN
            // ===============================================

            FilledButton.icon(
              onPressed: _isSaving ? null : _saveVeterinarian,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      widget.isEditing ? Icons.save_outlined : Icons.add,
                    ),
              label: Text(
                _isSaving
                    ? 'Guardando...'
                    : widget.isEditing
                        ? 'Guardar cambios'
                        : 'Registrar veterinario',
              ),
            ),

            const SizedBox(
              height: 30,
            ),
          ],
        ),
      ),
    );
  }
}
