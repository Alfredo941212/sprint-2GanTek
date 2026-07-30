import 'package:flutter/material.dart';

import '../../../cattle/data/models/cattle.dart';
import '../../../cattle/data/repositories/cattle_repository.dart';
import '../../data/models/sale.dart';
import '../../data/repositories/sale_repository.dart';

class RegisterSaleScreen extends StatefulWidget {
  const RegisterSaleScreen({super.key});

  @override
  State<RegisterSaleScreen> createState() => _RegisterSaleScreenState();
}

class _RegisterSaleScreenState extends State<RegisterSaleScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final CattleRepository _cattleRepository = CattleRepository();

  final SaleRepository _saleRepository = SaleRepository();

  final TextEditingController _buyerController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _weightController = TextEditingController();

  final TextEditingController _priceController = TextEditingController();

  final TextEditingController _observationsController = TextEditingController();

  List<Cattle> _availableCattle = [];
  Cattle? _selectedCattle;

  DateTime _saleDate = DateTime.now();
  String _paymentMethod = 'Efectivo';

  bool _isLoading = true;
  bool _isSaving = false;

  double get _total {
    final double weight = double.tryParse(
          _weightController.text.replaceAll(',', '.'),
        ) ??
        0;

    final double price = double.tryParse(
          _priceController.text.replaceAll(',', '.'),
        ) ??
        0;

    return weight * price;
  }

  @override
  void initState() {
    super.initState();

    _weightController.addListener(_updateTotal);
    _priceController.addListener(_updateTotal);

    _loadAvailableCattle();
  }

  void _updateTotal() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAvailableCattle() async {
    try {
      final List<Cattle> cattle = await _cattleRepository.getAvailableCattle();

      if (!mounted) {
        return;
      }

      setState(() {
        _availableCattle = cattle;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'No fue posible cargar el ganado: $error',
      );
    }
  }

  Future<void> _pickDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _saleDate = selectedDate;
    });
  }

  Future<void> _saveSale() async {
    if (_isSaving) {
      return;
    }

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    if (_selectedCattle == null || _selectedCattle!.id == null) {
      _showMessage('Selecciona el animal vendido.');
      return;
    }

    final double weight = double.parse(
      _weightController.text.replaceAll(',', '.'),
    );

    final double price = double.parse(
      _priceController.text.replaceAll(',', '.'),
    );

    setState(() {
      _isSaving = true;
    });

    try {
      final Sale sale = Sale(
        cattleId: _selectedCattle!.id!,
        cattleCode: _selectedCattle!.code,
        buyerName: _buyerController.text.trim(),
        buyerPhone: _phoneController.text.trim(),
        saleDate: _saleDate,
        saleWeight: weight,
        pricePerKg: price,
        total: weight * price,
        paymentMethod: _paymentMethod,
        observations: _observationsController.text.trim(),
        status: 'completada',
        createdAt: DateTime.now(),
      );

      await _saleRepository.insertSale(sale);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      _showMessage(
        'No se pudo guardar la venta: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _buyerController.dispose();
    _phoneController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    _observationsController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar venta'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  DropdownButtonFormField<Cattle>(
                    initialValue: _selectedCattle,
                    decoration: const InputDecoration(
                      labelText: 'Animal vendido',
                      prefixIcon: Icon(Icons.agriculture),
                    ),
                    items: _availableCattle.map((cattle) {
                      return DropdownMenuItem<Cattle>(
                        value: cattle,
                        child: Text(
                          'Arete ${cattle.code} - '
                          '${cattle.initialWeight.toStringAsFixed(1)} kg',
                        ),
                      );
                    }).toList(),
                    onChanged: (Cattle? cattle) {
                      setState(() {
                        _selectedCattle = cattle;

                        if (cattle != null) {
                          _weightController.text =
                              cattle.initialWeight.toStringAsFixed(1);
                        }
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Selecciona un animal';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _buyerController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del comprador',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el comprador';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_month,
                    ),
                    title: const Text('Fecha de venta'),
                    subtitle: Text(
                      '${_saleDate.day.toString().padLeft(2, '0')}/'
                      '${_saleDate.month.toString().padLeft(2, '0')}/'
                      '${_saleDate.year}',
                    ),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Peso de venta (kg)',
                      prefixIcon: Icon(
                        Icons.monitor_weight_outlined,
                      ),
                    ),
                    validator: (value) {
                      final double? weight = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );

                      if (weight == null || weight <= 0) {
                        return 'Ingresa un peso válido';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Precio por kg',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (value) {
                      final double? price = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );

                      if (price == null || price <= 0) {
                        return 'Ingresa un precio válido';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Text(
                            'Total de la venta',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '\$${_total.toStringAsFixed(2)} MXN',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Método de pago',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Efectivo',
                        child: Text('Efectivo'),
                      ),
                      DropdownMenuItem(
                        value: 'Transferencia',
                        child: Text('Transferencia'),
                      ),
                      DropdownMenuItem(
                        value: 'Crédito',
                        child: Text('Crédito'),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _paymentMethod = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _observationsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (opcional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSale,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.point_of_sale,
                          ),
                    label: Text(
                      _isSaving ? 'Guardando...' : 'Registrar venta',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
