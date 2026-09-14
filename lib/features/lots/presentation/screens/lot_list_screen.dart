import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/lot.dart';
import '../../data/repositories/lot_repository.dart';
import 'register_lot_screen.dart';

import 'lot_detail_screen.dart';

class LotListScreen extends StatefulWidget {
  const LotListScreen({
    super.key,
  });

  @override
  State<LotListScreen> createState() => _LotListScreenState();
}

class _LotListScreenState extends State<LotListScreen> {
  final LotRepository _lotRepository = LotRepository();

  List<Lot> _lots = [];

  final Map<int, int> _cattleCounts = {};
  final Map<int, int> _productiveCounts = {};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLots();
  }

  // =========================================================
  // CARGAR LOTES
  // =========================================================

  Future<void> _loadLots() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Lot> lots = await _lotRepository.getAllLots();

      final Map<int, int> cattleCounts = {};
      final Map<int, int> productiveCounts = {};

      for (final Lot lot in lots) {
        final int? lotId = lot.id;

        if (lotId == null) {
          continue;
        }

        cattleCounts[lotId] = await _lotRepository.countCattleInLot(
          lotId,
        );

        productiveCounts[lotId] =
            await _lotRepository.countProductiveCattleInLot(
          lotId,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _lots = lots;

        _cattleCounts
          ..clear()
          ..addAll(cattleCounts);

        _productiveCounts
          ..clear()
          ..addAll(productiveCounts);

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _cleanError(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _openLotDetail(
    Lot lot,
  ) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LotDetailScreen(
          lot: lot,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadLots();
    }
  }
  // =========================================================
  // ABRIR FORMULARIO
  // =========================================================

  Future<void> _openLotForm({
    Lot? lot,
  }) async {
    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterLotScreen(
          lot: lot,
        ),
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    await _loadLots();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            lot == null
                ? 'Lote registrado correctamente.'
                : 'Lote actualizado correctamente.',
          ),
        ),
      );
  }

  // =========================================================
  // CONFIRMAR ELIMINACIÓN
  // =========================================================

  Future<void> _confirmDelete(
    Lot lot,
  ) async {
    final int? lotId = lot.id;

    if (lotId == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Eliminar lote',
          ),
          content: Text(
            '¿Deseas eliminar el lote "${lot.name}"?\n\n'
            'Esta acción no se puede deshacer.',
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

    if (confirmed != true || !mounted) {
      return;
    }

    await _deleteLot(lotId);
  }

  // =========================================================
  // ELIMINAR LOTE
  // =========================================================

  Future<void> _deleteLot(
    int lotId,
  ) async {
    try {
      await _lotRepository.deleteLot(
        lotId,
      );

      if (!mounted) {
        return;
      }

      await _loadLots();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Lote eliminado correctamente.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _cleanError(error),
            ),
          ),
        );
    }
  }

  String _cleanError(
    Object error,
  ) {
    String message = error.toString();

    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }

    return message;
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lotes',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openLotForm();
        },
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Nuevo lote',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadLots,
        child: _buildBody(),
      ),
    );
  }

  // =========================================================
  // CONTENIDO
  // =========================================================

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        children: const [
          SizedBox(
            height: 250,
          ),
          Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(
            height: 120,
          ),
          const Icon(
            Icons.error_outline,
            size: 64,
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            'No fue posible cargar los lotes.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 20,
          ),
          ElevatedButton.icon(
            onPressed: _loadLots,
            icon: const Icon(
              Icons.refresh,
            ),
            label: const Text(
              'Intentar nuevamente',
            ),
          ),
        ],
      );
    }

    if (_lots.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(
            height: 110,
          ),
          Icon(
            Icons.grid_view_outlined,
            size: 75,
            color: AppColors.primary.withValues(
              alpha: 0.65,
            ),
          ),
          const SizedBox(
            height: 18,
          ),
          const Text(
            'Aún no tienes lotes registrados',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          const Text(
            'Crea un lote para organizar el ganado y controlar su producción.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(
            height: 22,
          ),
          FilledButton.icon(
            onPressed: () {
              _openLotForm();
            },
            icon: const Icon(
              Icons.add,
            ),
            label: const Text(
              'Registrar primer lote',
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        100,
      ),
      itemCount: _lots.length,
      separatorBuilder: (_, __) => const SizedBox(
        height: 12,
      ),
      itemBuilder: (
        BuildContext context,
        int index,
      ) {
        final Lot lot = _lots[index];

        return _LotCard(
          lot: lot,
          cattleCount: _cattleCounts[lot.id] ?? 0,
          productiveCount: _productiveCounts[lot.id] ?? 0,
          onTap: () {
            _openLotDetail(
              lot,
            );
          },
          onEdit: () {
            _openLotForm(
              lot: lot,
            );
          },
          onDelete: () {
            _confirmDelete(
              lot,
            );
          },
        );
      },
    );
  }
}

// ===========================================================
// TARJETA DE LOTE
// ===========================================================

class _LotCard extends StatelessWidget {
  const _LotCard({
    required this.lot,
    required this.cattleCount,
    required this.productiveCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Lot lot;
  final int cattleCount;
  final int productiveCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool isActive = lot.status == 'Activo';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: const Icon(
                      Icons.grid_view_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lot.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          lot.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
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
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.edit_outlined,
                          ),
                          title: Text(
                            'Editar',
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            color: AppColors.danger,
                          ),
                          title: Text(
                            'Eliminar',
                            style: TextStyle(
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (lot.description != null &&
                  lot.description!.trim().isNotEmpty) ...[
                const SizedBox(
                  height: 12,
                ),
                Text(
                  lot.description!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const Divider(
                height: 28,
              ),
              Row(
                children: [
                  Expanded(
                    child: _LotIndicator(
                      icon: Icons.pets_outlined,
                      value: '$cattleCount',
                      label: 'Ganado',
                    ),
                  ),
                  Expanded(
                    child: _LotIndicator(
                      icon: Icons.water_drop_outlined,
                      value: '$productiveCount',
                      label: 'Produciendo',
                    ),
                  ),
                  Expanded(
                    child: _LotIndicator(
                      icon: Icons.speed_outlined,
                      value:
                          '${lot.minimumProductionPerCow.toStringAsFixed(1)} L',
                      label: 'Mínimo',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// INDICADOR
// ===========================================================

class _LotIndicator extends StatelessWidget {
  const _LotIndicator({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(
          height: 5,
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(
          height: 2,
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
