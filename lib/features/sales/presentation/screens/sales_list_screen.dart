import 'package:flutter/material.dart';

import 'package:gantek/features/sales/data/models/sale.dart';
import 'package:gantek/features/sales/data/repositories/sale_repository.dart';
import 'package:gantek/features/sales/presentation/screens/register_sale_screen.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  final SaleRepository _saleRepository = SaleRepository();

  late Future<List<Sale>> _salesFuture;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  void _loadSales() {
    _salesFuture = _saleRepository.getAllSales();
  }

  Future<void> _openRegisterSale() async {
    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterSaleScreen(),
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    setState(_loadSales);

    _showMessage(
      'Venta registrada correctamente.',
    );
  }

  Future<void> _openEditSale(
    Sale sale,
  ) async {
    final bool? updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterSaleScreen(
          sale: sale,
        ),
      ),
    );

    if (updated != true || !mounted) {
      return;
    }

    setState(_loadSales);

    _showMessage(
      'Venta actualizada correctamente.',
    );
  }

  Future<void> _deleteSale(
    Sale sale,
  ) async {
    if (sale.id == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Eliminar venta',
          ),
          content: Text(
            '¿Deseas eliminar la venta del animal '
            '${sale.cattleCode}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
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

    try {
      final int deletedRows = await _saleRepository.deleteSale(
        sale.id!,
      );

      if (!mounted) {
        return;
      }

      if (deletedRows == 0) {
        _showMessage(
          'No se pudo eliminar la venta.',
        );
        return;
      }

      setState(_loadSales);

      _showMessage(
        'Venta eliminada correctamente.',
      );
    } catch (error) {
      _showMessage(
        'Ocurrió un error al eliminar la venta.',
      );

      debugPrint(
        'Error eliminando venta: $error',
      );
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas'),
      ),
      body: FutureBuilder<List<Sale>>(
        future: _salesFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<Sale>> snapshot,
        ) {
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
                  'No fue posible cargar las ventas.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<Sale> sales = snapshot.data ?? <Sale>[];

          if (sales.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.point_of_sale_outlined,
                      size: 72,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No hay ventas registradas.',
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(_loadSales);
              await _salesFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sales.length,
              separatorBuilder: (_, __) {
                return const SizedBox(
                  height: 12,
                );
              },
              itemBuilder: (
                BuildContext context,
                int index,
              ) {
                final Sale sale = sales[index];

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: const CircleAvatar(
                      child: Icon(
                        Icons.point_of_sale,
                      ),
                    ),
                    title: Text(
                      'Arete ${sale.cattleCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Comprador: ${sale.buyerName}\n'
                      '${sale.saleWeight.toStringAsFixed(1)} kg × '
                      '\$${sale.pricePerKg.toStringAsFixed(2)}\n'
                      'Estado: ${sale.status}',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      _openEditSale(sale);
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (
                        String option,
                      ) {
                        if (option == 'edit') {
                          _openEditSale(sale);
                        }

                        if (option == 'delete') {
                          _deleteSale(sale);
                        }
                      },
                      itemBuilder: (
                        BuildContext context,
                      ) {
                        return const [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.edit_outlined,
                              ),
                              title: Text(
                                'Actualizar',
                              ),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.delete_outline,
                              ),
                              title: Text(
                                'Eliminar',
                              ),
                            ),
                          ),
                        ];
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegisterSale,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nueva venta',
        ),
      ),
    );
  }
}
