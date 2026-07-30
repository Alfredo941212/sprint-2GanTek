import 'package:flutter/material.dart';
import '../../data/models/cattle.dart';
import 'register_cattle_screen.dart';
import '../../data/repositories/cattle_repository.dart';

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
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.pets),
                    ),
                    title: Text(
                      'Arete: ${cattle.code}',
                    ),
                    subtitle: Text(
                      '${cattle.initialWeight.toStringAsFixed(1)} kg\n'
                      'Lote: ${cattle.lot.isEmpty ? "Sin lote" : cattle.lot}\n'
                      'Corral: ${cattle.corral.isEmpty ? "Sin corral" : cattle.corral}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Eliminar',
                      onPressed: () {
                        _deleteCattle(cattle);
                      },
                      icon: const Icon(Icons.delete_outline),
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
