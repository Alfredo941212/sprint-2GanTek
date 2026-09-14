import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../lots/data/models/lot.dart';
import '../../../lots/data/repositories/lot_repository.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/cattle.dart';
import '../../data/repositories/cattle_repository.dart';
import 'register_cattle_screen.dart';

import 'cattle_detail_screen.dart';

class CattleListScreen extends StatefulWidget {
  const CattleListScreen({
    super.key,
  });

  @override
  State<CattleListScreen> createState() => _CattleListScreenState();
}

class _CattleListScreenState extends State<CattleListScreen> {
  final CattleRepository _repository = CattleRepository();

  final LotRepository _lotRepository = LotRepository();

  late Future<List<Cattle>> _cattleFuture;

  Map<int, String> _lotNames = {};

  @override
  void initState() {
    super.initState();

    _loadCattle();
  }

  // =========================================================
  // CARGAR GANADO
  // =========================================================

  void _loadCattle() {
    setState(() {
      _cattleFuture = _loadCattleWithLots();
    });
  }

  Future<List<Cattle>> _loadCattleWithLots() async {
    final List<Cattle> cattle = await _repository.getAllCattle();

    final List<Lot> lots = await _lotRepository.getAllLots();

    final Map<int, String> lotNames = {};

    for (final Lot lot in lots) {
      final int? lotId = lot.id;

      if (lotId != null) {
        lotNames[lotId] = lot.name;
      }
    }

    if (mounted) {
      setState(() {
        _lotNames = lotNames;
      });
    }

    return cattle;
  }

  // =========================================================
  // REGISTRAR
  // =========================================================

  Future<void> _openRegisterScreen() async {
    final bool? wasSaved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterCattleScreen(),
      ),
    );

    if (wasSaved != true) {
      return;
    }

    _loadCattle();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ganado registrado correctamente.',
        ),
      ),
    );
  }

  // =========================================================
  // EDITAR
  // =========================================================
  Future<void> _openCattleDetail(
    Cattle cattle,
  ) async {
    final int? lotId = cattle.lotId;

    final String lotName = lotId == null
        ? 'Sin lote asignado'
        : (_lotNames[lotId] ?? 'Lote no disponible');

    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CattleDetailScreen(
          cattle: cattle,
          lotName: lotName,
        ),
      ),
    );

    if (changed == true) {
      _loadCattle();
    }
  }

  Future<void> _openEditCattle(
    Cattle cattle,
  ) async {
    final bool? updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterCattleScreen(
          cattle: cattle,
        ),
      ),
    );

    if (updated != true) {
      return;
    }

    _loadCattle();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Registro actualizado correctamente.',
        ),
      ),
    );
  }

  // =========================================================
  // ELIMINAR
  // =========================================================

  Future<void> _deleteCattle(
    Cattle cattle,
  ) async {
    if (cattle.id == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Eliminar registro',
          ),
          content: Text(
            '¿Deseas eliminar el animal '
            '${cattle.code}?',
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

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteCattle(
        cattle.id!,
      );

      _loadCattle();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registro eliminado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible eliminar el registro.',
          ),
        ),
      );

      debugPrint(
        'Error eliminando ganado: $error',
      );
    }
  }

  // =========================================================
  // MOSTRAR OPCIONES
  // =========================================================

  void _showOptions(
    Cattle cattle,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (
        BuildContext sheetContext,
      ) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                ),
                title: const Text(
                  'Editar animal',
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _openEditCattle(
                    cattle,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                ),
                title: const Text(
                  'Eliminar registro',
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _deleteCattle(
                    cattle,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // TEXTO DEL PESO
  // =========================================================

  String _weightText(
    Cattle cattle,
  ) {
    final double? weight = cattle.initialWeight;

    if (weight == null) {
      return 'Peso: sin registro';
    }

    return 'Peso: '
        '${weight.toStringAsFixed(0)} kg';
  }

  // =========================================================
  // TEXTO DEL LOTE
  // =========================================================

  String _lotText(
    Cattle cattle,
  ) {
    final int? lotId = cattle.lotId;

    if (lotId == null) {
      return 'Sin lote asignado';
    }

    final String? lotName = _lotNames[lotId];

    if (lotName == null || lotName.trim().isEmpty) {
      return 'Lote no disponible';
    }

    return lotName;
  }

  // =========================================================
  // COLOR DEL ESTADO PRODUCTIVO
  // =========================================================

  Color _productiveStatusColor(
    String status,
  ) {
    switch (status) {
      case 'En producción':
        return AppColors.success;

      case 'Seca':
        return Colors.orange.shade700;

      case 'Gestante':
        return Colors.blue.shade700;

      default:
        return Colors.grey.shade700;
    }
  }

  Color _productiveStatusBackground(
    String status,
  ) {
    switch (status) {
      case 'En producción':
        return AppColors.successSoft;

      case 'Seca':
        return Colors.orange.shade50;

      case 'Gestante':
        return Colors.blue.shade50;

      default:
        return Colors.grey.shade200;
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
          'Ganado registrado',
        ),
      ),
      body: FutureBuilder<List<Cattle>>(
        future: _cattleFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<Cattle>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(
                  24,
                ),
                child: Text(
                  'No fue posible cargar '
                  'el ganado.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<Cattle> cattleList = snapshot.data ?? <Cattle>[];

          if (cattleList.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(
                  24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.cow,
                      size: 64,
                    ),
                    SizedBox(
                      height: 16,
                    ),
                    Text(
                      'Todavía no hay ganado registrado.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(
                      height: 8,
                    ),
                    Text(
                      'Presiona "Registrar" '
                      'para agregar tu primer animal.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _loadCattle();

              await _cattleFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(
                16,
              ),
              itemCount: cattleList.length,
              separatorBuilder: (
                BuildContext context,
                int index,
              ) {
                return const SizedBox(
                  height: 12,
                );
              },
              itemBuilder: (
                BuildContext context,
                int index,
              ) {
                final Cattle cattle = cattleList[index];

                return Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () {
                      _openCattleDetail(
                        cattle,
                      );
                    },
                    onLongPress: () {
                      _showOptions(
                        cattle,
                      );
                    },
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(
                        12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ===============================
                          // FOTO
                          // ===============================

                          _CattleImage(
                            imagePath: cattle.imagePath,
                          ),

                          const SizedBox(
                            width: 12,
                          ),

                          // ===============================
                          // INFORMACIÓN
                          // ===============================

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cattle.name.trim().isNotEmpty
                                            ? cattle.name
                                            : 'Arete ${cattle.code}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Opciones',
                                      onPressed: () {
                                        _showOptions(
                                          cattle,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.more_vert,
                                      ),
                                    ),
                                  ],
                                ),
                                if (cattle.name.trim().isNotEmpty)
                                  Text(
                                    'Arete: '
                                    '${cattle.code}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                const SizedBox(
                                  height: 5,
                                ),
                                Text(
                                  '${_lotText(cattle)}  •  '
                                  '${_weightText(cattle)}',
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  cattle.breed.trim().isEmpty
                                      ? 'Raza: sin especificar'
                                      : 'Raza: ${cattle.breed}',
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 6,
                                  children: [
                                    _StatusChip(
                                      text: cattle.productiveStatus,
                                      foreground: _productiveStatusColor(
                                        cattle.productiveStatus,
                                      ),
                                      background: _productiveStatusBackground(
                                        cattle.productiveStatus,
                                      ),
                                    ),
                                    _StatusChip(
                                      text: cattle.status,
                                      foreground: cattle.status == 'Activo'
                                          ? AppColors.success
                                          : Colors.grey.shade700,
                                      background: cattle.status == 'Activo'
                                          ? AppColors.successSoft
                                          : Colors.grey.shade200,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegisterScreen,
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Registrar',
        ),
      ),
    );
  }
}

// ===========================================================
// IMAGEN DEL GANADO
// ===========================================================

class _CattleImage extends StatelessWidget {
  const _CattleImage({
    required this.imagePath,
  });

  final String? imagePath;

  @override
  Widget build(
    BuildContext context,
  ) {
    final String? currentPath = imagePath;

    if (currentPath == null || currentPath.isEmpty) {
      return Container(
        width: 82,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(
            10,
          ),
        ),
        alignment: Alignment.center,
        child: const FaIcon(
          FontAwesomeIcons.cow,
          size: 36,
          color: Color(0xFF0F5132),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(
        10,
      ),
      child: Image.file(
        File(currentPath),
        width: 82,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Container(
            width: 82,
            height: 72,
            alignment: Alignment.center,
            color: AppColors.primaryLight,
            child: const FaIcon(
              FontAwesomeIcons.cow,
              size: 34,
              color: Color(0xFF0F5132),
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================
// ETIQUETA DE ESTADO
// ===========================================================

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    required this.foreground,
    required this.background,
  });

  final String text;

  final Color foreground;

  final Color background;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
