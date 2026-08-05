import 'package:flutter/material.dart';

import '../../data/models/sale.dart';
import '../../data/repositories/sale_repository.dart';
import 'register_sale_screen.dart';

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

    if (saved == true) {
      setState(_loadSales);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Venta registrada correctamente.',
          ),
        ),
      );
    }
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

    if (updated != true) {
      return;
    }

    setState(_loadSales);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Venta actualizada correctamente.',
          ),
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
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'No fue posible cargar las ventas.\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final List<Sale> sales = snapshot.data ?? [];

          if (sales.isEmpty) {
            return const Center(
              child: Text(
                'Todavía no hay ventas registradas.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sales.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final Sale sale = sales[index];

              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    _openEditSale(sale);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          child: Icon(
                            Icons.point_of_sale,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Arete ${sale.cattleCode}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Comprador: ${sale.buyerName}',
                              ),
                              Text(
                                '${sale.saleWeight.toStringAsFixed(1)} kg × '
                                '\$${sale.pricePerKg.toStringAsFixed(2)}',
                              ),
                              Text(
                                'Estado: ${sale.status}',
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${sale.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegisterSale,
        icon: const Icon(Icons.add),
        label: const Text('Nueva venta'),
      ),
    );
  }
}
