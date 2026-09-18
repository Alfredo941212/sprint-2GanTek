import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../cattle/data/models/cattle.dart';
import '../../../cattle/data/repositories/cattle_repository.dart';
import '../../../milk_production/data/repositories/milking_repository.dart';
import '../../data/models/lot.dart';
import '../../data/repositories/lot_repository.dart';
import 'register_lot_screen.dart';

class LotDetailScreen extends StatefulWidget {
  const LotDetailScreen({
    super.key,
    required this.lot,
  });

  final Lot lot;

  @override
  State<LotDetailScreen> createState() => _LotDetailScreenState();
}

class _LotDetailScreenState extends State<LotDetailScreen> {
  final LotRepository _lotRepository = LotRepository();

  final CattleRepository _cattleRepository = CattleRepository();

  final MilkingRepository _milkingRepository = MilkingRepository();

  late Lot _lot;

  bool _isLoading = true;
  bool _isDeleting = false;

  String? _errorMessage;

  List<Cattle> _cattle = [];

  int _productiveCattle = 0;

  double _todayProduction = 0;
  double _monthlyProduction = 0;

  @override
  void initState() {
    super.initState();

    _lot = widget.lot;

    _loadData();
  }

  // =========================================================
  // CARGAR INFORMACIÓN
  // =========================================================

  Future<void> _loadData() async {
    final int? lotId = _lot.id;

    if (lotId == null) {
      setState(() {
        _errorMessage = 'El lote no tiene un identificador válido.';
        _isLoading = false;
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // El ganado general ya se obtiene desde Laravel/MySQL.
      final List<Cattle> allCattle = await _cattleRepository.getAllCattle();

      // Filtramos solamente el ganado perteneciente a este lote.
      final List<Cattle> cattle = allCattle.where(
        (Cattle animal) {
          return animal.lotId == lotId && animal.status == 'Activo';
        },
      ).toList();

      // Calculamos las vacas productivas usando los datos del servidor.
      final int productiveCattle = cattle.where(
        (Cattle animal) {
          return animal.sex == 'Hembra' &&
              animal.productiveStatus == 'En producción';
        },
      ).length;

      final DateTime now = DateTime.now();

      // Producción todavía permanece en SQLite temporalmente.
      final double todayProduction =
          await _milkingRepository.getDailyProductionByLot(
        lotId: lotId,
        date: now,
      );

      final double monthlyProduction =
          await _milkingRepository.getMonthlyProductionByLot(
        lotId: lotId,
        month: now,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _cattle = cattle;
        _productiveCattle = productiveCattle;
        _todayProduction = todayProduction;
        _monthlyProduction = monthlyProduction;
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

      debugPrint(
        'Error cargando detalle del lote: $error',
      );
    }
  }

  // =========================================================
  // EDITAR
  // =========================================================

  Future<void> _editLot() async {
    final int? lotId = _lot.id;

    if (lotId == null) {
      return;
    }

    try {
      final Lot? currentLot = await _lotRepository.getLotById(
        lotId,
      );

      if (!mounted) {
        return;
      }

      if (currentLot != null) {
        _lot = currentLot;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'No fue posible cargar la información actualizada del lote.',
            ),
          ),
        );

      return;
    }
    final bool? updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterLotScreen(
          lot: _lot,
        ),
      ),
    );

    if (updated != true) {
      return;
    }

    try {
      final Lot? updatedLot = await _lotRepository.getLotById(
        lotId,
      );

      if (!mounted) {
        return;
      }

      if (updatedLot != null) {
        setState(() {
          _lot = updatedLot;
        });
      }

      await _loadData();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Lote actualizado correctamente.',
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

  // =========================================================
  // ELIMINAR
  // =========================================================

  Future<void> _deleteLot() async {
    final int? lotId = _lot.id;

    if (lotId == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Eliminar lote',
          ),
          content: Text(
            '¿Deseas eliminar el lote '
            '"${_lot.name}"?\n\n'
            'No se podrá eliminar si todavía '
            'tiene ganado asignado.',
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

    setState(() {
      _isDeleting = true;
    });

    try {
      await _lotRepository.deleteLot(
        lotId,
      );

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
        _isDeleting = false;
      });

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

    if (message.startsWith(
      'Exception: ',
    )) {
      message = message.substring(11);
    }

    return message;
  }

  String _formatLiters(
    double liters,
  ) {
    return '${liters.toStringAsFixed(1)} L';
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
          'Detalle del lote',
        ),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: _isDeleting ? null : _editLot,
            icon: const Icon(
              Icons.edit_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: _isDeleting ? null : _deleteLot,
            icon: const Icon(
              Icons.delete_outline,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _buildContent(),
                ),
    );
  }

  // =========================================================
  // ERROR
  // =========================================================

  Widget _buildError() {
    return ListView(
      padding: const EdgeInsets.all(
        24,
      ),
      children: [
        const SizedBox(
          height: 100,
        ),
        const Icon(
          Icons.error_outline,
          size: 60,
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
        FilledButton.icon(
          onPressed: _loadData,
          icon: const Icon(
            Icons.refresh,
          ),
          label: const Text(
            'Reintentar',
          ),
        ),
      ],
    );
  }

  // =========================================================
  // CONTENIDO
  // =========================================================

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        32,
      ),
      children: [
        // =====================================================
        // CABECERA
        // =====================================================

        Card(
          child: Padding(
            padding: const EdgeInsets.all(
              18,
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(
                      18,
                    ),
                  ),
                  child: const Icon(
                    Icons.grid_view_outlined,
                    size: 34,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  _lot.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 6,
                ),
                _StatusChip(
                  text: _lot.status,
                  active: _lot.status == 'Activo',
                ),
                if (_lot.description != null &&
                    _lot.description!.trim().isNotEmpty) ...[
                  const SizedBox(
                    height: 12,
                  ),
                  Text(
                    _lot.description!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        // =====================================================
        // RESUMEN
        // =====================================================

        _SectionCard(
          title: 'Resumen del lote',
          icon: Icons.analytics_outlined,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Indicator(
                      label: 'Ganado',
                      value: '${_cattle.length}',
                      icon: Icons.pets_outlined,
                    ),
                  ),
                  Expanded(
                    child: _Indicator(
                      label: 'Produciendo',
                      value: '$_productiveCattle',
                      icon: Icons.water_drop_outlined,
                    ),
                  ),
                  Expanded(
                    child: _Indicator(
                      label: 'Mínimo/vaca',
                      value:
                          '${_lot.minimumProductionPerCow.toStringAsFixed(1)} L',
                      icon: Icons.speed_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        // =====================================================
        // PRODUCCIÓN
        // =====================================================

        _SectionCard(
          title: 'Producción de leche',
          icon: Icons.water_drop_outlined,
          child: Row(
            children: [
              Expanded(
                child: _ProductionValue(
                  label: 'Hoy',
                  value: _formatLiters(
                    _todayProduction,
                  ),
                ),
              ),
              Container(
                height: 50,
                width: 1,
                color: Colors.grey.shade300,
              ),
              Expanded(
                child: _ProductionValue(
                  label: 'Este mes',
                  value: _formatLiters(
                    _monthlyProduction,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        // =====================================================
        // GANADO
        // =====================================================

        _SectionCard(
          title: 'Ganado del lote',
          icon: Icons.pets_outlined,
          child: _buildCattleList(),
        ),

        const SizedBox(
          height: 24,
        ),

        // =====================================================
        // ACCIONES
        // =====================================================

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isDeleting ? null : _editLot,
                icon: const Icon(
                  Icons.edit_outlined,
                ),
                label: const Text(
                  'Editar',
                ),
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isDeleting ? null : _deleteLot,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.delete_outline,
                      ),
                label: Text(
                  _isDeleting ? 'Eliminando...' : 'Eliminar',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================
  // LISTA DE GANADO
  // =========================================================

  Widget _buildCattleList() {
    if (_cattle.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 12,
        ),
        child: Text(
          'No hay ganado asignado a este lote.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      children: _cattle.map(
        (Cattle cattle) {
          final String name =
              cattle.name.trim().isEmpty ? 'Arete ${cattle.code}' : cattle.name;

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: const Icon(
                Icons.pets_outlined,
                color: AppColors.primary,
              ),
            ),
            title: Text(name),
            subtitle: Text(
              'Arete: ${cattle.code} • '
              '${cattle.productiveStatus}',
            ),
            trailing: const Icon(
              Icons.chevron_right,
            ),
          );
        },
      ).toList(),
    );
  }
}

// ===========================================================
// TARJETA DE SECCIÓN
// ===========================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: AppColors.primary,
                ),
                const SizedBox(
                  width: 8,
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// INDICADOR
// ===========================================================

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
        ),
        const SizedBox(
          height: 6,
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(
          height: 3,
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

// ===========================================================
// PRODUCCIÓN
// ===========================================================

class _ProductionValue extends StatelessWidget {
  const _ProductionValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// ESTADO
// ===========================================================

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    required this.active,
  });

  final String text;
  final bool active;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.successSoft : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? AppColors.success : Colors.grey.shade700,
        ),
      ),
    );
  }
}
