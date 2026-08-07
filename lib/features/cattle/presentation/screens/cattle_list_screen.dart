import 'package:flutter/material.dart';
import '../../data/models/cattle.dart';
import 'register_cattle_screen.dart';
import '../../data/repositories/cattle_repository.dart';
import '../../../../core/theme/app_colors.dart';
import 'dart:io';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CattleListScreen extends StatefulWidget {
  const CattleListScreen({super.key});

  @override
  State<CattleListScreen> createState() => _CattleListScreenState();
}

class _CattleListScreenState extends State<CattleListScreen> {
  final CattleRepository _repository = CattleRepository();

  late Future<List<Cattle>> _cattleFuture;

  @override
  void initState() {
    super.initState();
    _loadCattle();
  }

  void _loadCattle() {
    setState(() {
      _cattleFuture = _repository.getAllCattle();
    });
  }

  Future<void> _openRegisterScreen() async {
    final bool? wasSaved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterCattleScreen(),
      ),
    );

    if (wasSaved == true) {
      _loadCattle();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ganado registrado correctamente.'),
        ),
      );
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

    if (updated == true) {
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
  }

  Future<void> _deleteCattle(Cattle cattle) async {
    if (cattle.id == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar registro'),
          content: Text(
            '¿Deseas eliminar el animal ${cattle.code}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _repository.deleteCattle(cattle.id!);
    _loadCattle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganado registrado'),
      ),
      body: FutureBuilder<List<Cattle>>(
        future: _cattleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No fue posible cargar el ganado.\n'
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
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.agriculture_outlined,
                      size: 72,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Todavía no hay ganado registrado.',
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
              padding: const EdgeInsets.all(16),
              itemCount: cattleList.length,
              separatorBuilder: (_, __) {
                return const SizedBox(height: 12);
              },
              itemBuilder: (context, index) {
                final Cattle cattle = cattleList[index];

                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: InkWell(
                    onTap: () {
                      _openEditCattle(cattle);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 82,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const FaIcon(
                              FontAwesomeIcons.cow,
                              size: 38,
                              color: Color(0xFF0F5132),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Toro ${cattle.code}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Lote: ${cattle.lot}  |  '
                                  '${cattle.initialWeight.toStringAsFixed(0)} kg',
                                ),
                                Text(
                                  'Corral: ${cattle.corral}',
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Disponible',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
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
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
    );
  }
}

class _CattleImage extends StatelessWidget {
  const _CattleImage({
    required this.imagePath,
  });

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final String? currentPath = imagePath;

    if (currentPath == null || currentPath.isEmpty) {
      return Container(
        width: 82,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F3EC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.pets,
          size: 38,
          color: Color(0xFF0F5132),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
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
            child: const Icon(
              Icons.broken_image_outlined,
            ),
          );
        },
      ),
    );
  }
}
