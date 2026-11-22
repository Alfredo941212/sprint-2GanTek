import 'package:flutter/material.dart';

import '../../../../core/session/session_manager.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../data/repositories/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileRepository _repository = ProfileRepository();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  UserModel? _user;

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _repository.getProfile();

      if (!mounted) {
        return;
      }

      setState(() {
        _user = user;
        _nameController.text = user.fullName;
        _phoneController.text = user.phone;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _user = SessionManager.instance.currentUser;

        if (_user != null) {
          _nameController.text = _user!.fullName;
          _phoneController.text = _user!.phone;
        }

        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar la información del perfil.',
          ),
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El nombre debe tener al menos 2 caracteres.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedUser = await _repository.updateProfile(
        name: name,
        phone: phone,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _user = updatedUser;
        _nameController.text = updatedUser.fullName;
        _phoneController.text = updatedUser.phone;
        _isEditing = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Perfil actualizado correctamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar el perfil.',
          ),
        ),
      );
    }
  }

  void _cancelEdit() {
    final user = _user;

    if (user == null) {
      return;
    }

    setState(() {
      _nameController.text = user.fullName;
      _phoneController.text = user.phone;
      _isEditing = false;
    });
  }

  Future<void> _logout() async {
    await SessionManager.instance.clearSession();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final user = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (!_isEditing)
            IconButton(
              tooltip: 'Editar perfil',
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(
                Icons.edit_outlined,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 46,
                child: Icon(
                  Icons.person,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),

              if (_isEditing) ...[
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(
                      Icons.person_outline,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : _cancelEdit,
                        child: const Text(
                          'Cancelar',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : _saveProfile,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Guardar',
                              ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  user?.fullName ?? 'Usuario GanTek',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user?.role ?? 'Ganadero',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 30),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.email_outlined,
                    ),
                    title: Text(
                      user?.email ?? 'Sin correo',
                    ),
                    subtitle: const Text(
                      'Correo electrónico',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.phone_outlined,
                    ),
                    title: Text(
                      user?.phone.isNotEmpty == true
                          ? user!.phone
                          : 'Sin teléfono',
                    ),
                    subtitle: const Text(
                      'Número telefónico',
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : _logout,
                  icon: const Icon(
                    Icons.logout,
                  ),
                  label: const Text(
                    'Cerrar sesión',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}