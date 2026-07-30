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
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(
                      Icons.point_of_sale,
                    ),
                  ),
                  title: Text(
                    'Arete ${sale.cattleCode}',
                  ),
                  subtitle: Text(
                    'Comprador: ${sale.buyerName}\n'
                    '${sale.saleWeight.toStringAsFixed(1)} kg × '
                    '\$${sale.pricePerKg.toStringAsFixed(2)}\n'
                    'Estado: ${sale.status}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    '\$${sale.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
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
