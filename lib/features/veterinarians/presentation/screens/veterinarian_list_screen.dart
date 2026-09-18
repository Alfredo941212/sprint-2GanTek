import 'package:flutter/material.dart';

import '../../data/models/veterinarian.dart';
import '../../data/repositories/veterinarian_repository.dart';
import 'register_veterinarian_screen.dart';
import 'veterinarian_detail_screen.dart';

class VeterinarianListScreen extends StatefulWidget {
  const VeterinarianListScreen({
    super.key,
  });

  @override
  State<VeterinarianListScreen> createState() => _VeterinarianListScreenState();
}

class _VeterinarianListScreenState extends State<VeterinarianListScreen> {
  final VeterinarianRepository _repository = VeterinarianRepository();

  List<Veterinarian> _veterinarians = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVeterinarians();
  }

  // =========================================================
  // DETALLE
  // =========================================================

  Future<void> _openVeterinarianDetail(
    Veterinarian veterinarian,
  ) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VeterinarianDetailScreen(
          veterinarian: veterinarian,
        ),
      ),
    );

    if (changed == true) {
      await _loadVeterinarians();
    }
  }

  // =========================================================
  // CARGAR VETERINARIOS
  // =========================================================

  Future<void> _loadVeterinarians() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Veterinarian> veterinarians =
          await _repository.getAllVeterinarians();

      if (!mounted) {
        return;
      }

      setState(() {
        _veterinarians = veterinarians;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString().replaceFirst(
              'Exception: ',
              '',
            );

        _isLoading = false;
      });
    }
  }

  // =========================================================
  // REGISTRAR
  // =========================================================

  Future<void> _openRegisterVeterinarian() async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterVeterinarianScreen(),
      ),
    );

    if (changed == true) {
      await _loadVeterinarians();
    }
  }

  // =========================================================
  // EDITAR
  // =========================================================

  Future<void> _openEditVeterinarian(
    Veterinarian veterinarian,
  ) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterVeterinarianScreen(
          veterinarian: veterinarian,
        ),
      ),
    );

    if (changed == true) {
      await _loadVeterinarians();
    }
  }

  // =========================================================
  // ELIMINAR
  // =========================================================

  Future<void> _deleteVeterinarian(
    Veterinarian veterinarian,
  ) async {
    final int? id = veterinarian.id;

    if (id == null) {
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Eliminar veterinario',
          ),
          content: Text(
            '¿Deseas eliminar a ${veterinarian.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Eliminar',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await _repository.deleteVeterinarian(
        id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veterinario eliminado correctamente.',
          ),
        ),
      );

      await _loadVeterinarians();
    } catch (error) {
      if (!mounted) {
        return;
      }

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
  // INTERFAZ
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Veterinarios',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegisterVeterinarian,
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Registrar',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadVeterinarians,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(
          24,
        ),
        children: [
          const SizedBox(
            height: 100,
          ),
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red.shade400,
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 16,
          ),
          Center(
            child: FilledButton.icon(
              onPressed: _loadVeterinarians,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Reintentar',
              ),
            ),
          ),
        ],
      );
    }

    if (_veterinarians.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(
          24,
        ),
        children: [
          const SizedBox(
            height: 100,
          ),
          Icon(
            Icons.medical_services_outlined,
            size: 70,
            color: Colors.grey.shade400,
          ),
          const SizedBox(
            height: 18,
          ),
          const Text(
            'No hay veterinarios registrados',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            'Registra al primer veterinario para utilizarlo posteriormente en las vacunaciones.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          Center(
            child: FilledButton.icon(
              onPressed: _openRegisterVeterinarian,
              icon: const Icon(
                Icons.add,
              ),
              label: const Text(
                'Registrar veterinario',
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        100,
      ),
      itemCount: _veterinarians.length,
      separatorBuilder: (
        _,
        __,
      ) {
        return const SizedBox(
          height: 10,
        );
      },
      itemBuilder: (
        BuildContext context,
        int index,
      ) {
        final Veterinarian veterinarian = _veterinarians[index];

        return _VeterinarianCard(
          veterinarian: veterinarian,

          // Al tocar la tarjeta abre el detalle.
          onTap: () {
            _openVeterinarianDetail(
              veterinarian,
            );
          },

          // Editar desde los tres puntos.
          onEdit: () {
            _openEditVeterinarian(
              veterinarian,
            );
          },

          // Eliminar desde los tres puntos.
          onDelete: () {
            _deleteVeterinarian(
              veterinarian,
            );
          },
        );
      },
    );
  }
}

// ===========================================================
// TARJETA
// ===========================================================

class _VeterinarianCard extends StatelessWidget {
  const _VeterinarianCard({
    required this.veterinarian,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Veterinarian veterinarian;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool isActive = veterinarian.status == 'Activo';

    final String specialty = veterinarian.specialty?.trim().isNotEmpty == true
        ? veterinarian.specialty!
        : 'Sin especialidad';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(
            14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =================================================
              // ICONO
              // =================================================

              const CircleAvatar(
                radius: 27,
                child: Icon(
                  Icons.medical_services_outlined,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              // =================================================
              // INFORMACIÓN
              // =================================================

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      veterinarian.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      specialty,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (veterinarian.professionalLicense?.trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        'Cédula: ${veterinarian.professionalLicense}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(
                      height: 8,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.withValues(
                                alpha: 0.12,
                              )
                            : Colors.grey.withValues(
                                alpha: 0.15,
                              ),
                        borderRadius: BorderRadius.circular(
                          20,
                        ),
                      ),
                      child: Text(
                        veterinarian.status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // =================================================
              // TRES PUNTOS
              // =================================================

              PopupMenuButton<String>(
                tooltip: 'Opciones',
                icon: const Icon(
                  Icons.more_vert,
                ),
                onSelected: (
                  String value,
                ) {
                  if (value == 'edit') {
                    onEdit();
                  }

                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (
                  BuildContext context,
                ) {
                  return [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                          ),
                          SizedBox(
                            width: 12,
                          ),
                          Text(
                            'Editar',
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                          ),
                          SizedBox(
                            width: 12,
                          ),
                          Text(
                            'Eliminar',
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
