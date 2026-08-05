import 'package:flutter/material.dart';

import '../../../../core/session/session_manager.dart';
import '../../../cattle/data/models/cattle.dart';
import '../../../cattle/data/repositories/cattle_repository.dart';
import '../../data/models/sale.dart';
import '../../data/repositories/sale_repository.dart';

class RegisterSaleScreen extends StatefulWidget {
  const RegisterSaleScreen({
    super.key,
    this.sale,
  });

  final Sale? sale;

  bool get isEditing => sale != null;

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

  List<Cattle> _availableCattle = <Cattle>[];
  Cattle? _selectedCattle;

  DateTime _saleDate = DateTime.now();
  String _paymentMethod = 'Efectivo';

  bool _isLoading = true;
  bool _isSaving = false;

  double get _total {
    final double weight = double.tryParse(
          _weightController.text.trim().replaceAll(',', '.'),
        ) ??
        0;

    final double price = double.tryParse(
          _priceController.text.trim().replaceAll(',', '.'),
        ) ??
        0;

    return weight * price;
  }

  @override
  void initState() {
    super.initState();

    final Sale? sale = widget.sale;

    if (sale != null) {
      _buyerController.text = sale.buyerName;
      _phoneController.text = sale.buyerPhone;
      _weightController.text = sale.saleWeight.toStringAsFixed(1);
      _priceController.text = sale.pricePerKg.toStringAsFixed(2);
      _observationsController.text = sale.observations;
      _saleDate = sale.saleDate;
      _paymentMethod = sale.paymentMethod;
    }

    _weightController.addListener(_updateTotal);
    _priceController.addListener(_updateTotal);

    _loadAvailableCattle();
  }

  void _updateTotal() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _loadAvailableCattle() async {
    try {
      final List<Cattle> cattle = await _cattleRepository.getAvailableCattle();

      final Sale? sale = widget.sale;
      Cattle? originalCattle;

      if (sale != null) {
        originalCattle = await _cattleRepository.getCattleById(
          sale.cattleId,
        );

        final bool alreadyIncluded = cattle.any(
          (Cattle item) => item.id == originalCattle?.id,
        );

        if (originalCattle != null && !alreadyIncluded) {
          cattle.insert(0, originalCattle);
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _availableCattle = cattle;
        _selectedCattle = originalCattle;
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
        'No fue posible cargar el ganado.',
      );

      debugPrint(
        'Error cargando ganado para venta: $error',
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

    final int? userId = SessionManager.instance.currentUserId;

    if (userId == null) {
      _showMessage(
        'No hay una sesión activa.',
      );
      return;
    }

    final Cattle? selectedCattle = _selectedCattle;

    if (selectedCattle == null || selectedCattle.id == null) {
      _showMessage(
        'Selecciona el animal vendido.',
      );
      return;
    }

    final double? weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );

    final double? price = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );

    if (weight == null || weight <= 0) {
      _showMessage(
        'Ingresa un peso de venta válido.',
      );
      return;
    }

    if (price == null || price <= 0) {
      _showMessage(
        'Ingresa un precio válido.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final Sale? originalSale = widget.sale;

      final Sale sale = Sale(
        id: widget.sale?.id,
        userId: userId,
        cattleId: selectedCattle.id!,
        cattleCode: selectedCattle.code,
        buyerName: _buyerController.text.trim(),
        buyerPhone: _phoneController.text.trim(),
        saleDate: _saleDate,
        saleWeight: weight,
        pricePerKg: price,
        total: weight * price,
        paymentMethod: _paymentMethod,
        observations: _observationsController.text.trim(),
        status: originalSale?.status ?? 'completada',
        createdAt: originalSale?.createdAt ?? DateTime.now(),
      );

      if (widget.isEditing) {
        final int updatedRows = await _saleRepository.updateSale(
          sale,
        );

        if (updatedRows == 0) {
          throw StateError(
            'La venta no existe o pertenece a otro usuario.',
          );
        }
      } else {
        await _saleRepository.insertSale(
          sale,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      _showMessage(
        widget.isEditing
            ? 'No se pudo actualizar la venta.'
            : 'No se pudo guardar la venta.',
      );

      debugPrint(
        'Error guardando venta: $error',
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
  void dispose() {
    _weightController.removeListener(
      _updateTotal,
    );

    _priceController.removeListener(
      _updateTotal,
    );

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
        title: Text(
          widget.isEditing ? 'Actualizar venta' : 'Registrar venta',
        ),
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
                  if (_availableCattle.isEmpty && !widget.isEditing)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 46,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No hay ganado disponible para venta.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<Cattle>(
                      initialValue: _selectedCattle,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Animal vendido',
                        prefixIcon: Icon(
                          Icons.agriculture,
                        ),
                      ),
                      items: _availableCattle.map(
                        (Cattle cattle) {
                          return DropdownMenuItem<Cattle>(
                            value: cattle,
                            child: Text(
                              'Arete ${cattle.code} - '
                              '${cattle.initialWeight.toStringAsFixed(1)} kg',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (Cattle? cattle) {
                        setState(() {
                          _selectedCattle = cattle;

                          if (cattle != null && !widget.isEditing) {
                            _weightController.text =
                                cattle.initialWeight.toStringAsFixed(
                              1,
                            );
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
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del comprador',
                      prefixIcon: Icon(
                        Icons.person_outline,
                      ),
                    ),
                    validator: (value) {
                      final String buyer = value?.trim() ?? '';

                      if (buyer.isEmpty) {
                        return 'Ingresa el comprador';
                      }

                      if (buyer.length < 3) {
                        return 'El nombre es demasiado corto';
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
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                      ),
                    ),
                    validator: (value) {
                      final String phone = value?.trim() ?? '';

                      if (phone.isEmpty) {
                        return null;
                      }

                      if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
                        return 'Ingresa exactamente 10 dígitos';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.calendar_month,
                      ),
                      title: const Text(
                        'Fecha de venta',
                      ),
                      subtitle: Text(
                        '${_saleDate.day.toString().padLeft(2, '0')}/'
                        '${_saleDate.month.toString().padLeft(2, '0')}/'
                        '${_saleDate.year}',
                      ),
                      trailing: const Icon(
                        Icons.edit_calendar,
                      ),
                      onTap: _pickDate,
                    ),
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
                        (value ?? '').trim().replaceAll(',', '.'),
                      );

                      if (weight == null || weight <= 0) {
                        return 'Ingresa un peso válido';
                      }

                      if (weight > 2000) {
                        return 'El peso es demasiado alto';
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
                      prefixIcon: Icon(
                        Icons.attach_money,
                      ),
                    ),
                    validator: (value) {
                      final double? price = double.tryParse(
                        (value ?? '').trim().replaceAll(',', '.'),
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
                      padding: const EdgeInsets.all(
                        18,
                      ),
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
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Método de pago',
                      prefixIcon: Icon(
                        Icons.payments_outlined,
                      ),
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
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _paymentMethod = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _observationsController,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (opcional)',
                      prefixIcon: Icon(
                        Icons.notes_outlined,
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isSaving ||
                            (_availableCattle.isEmpty && !widget.isEditing)
                        ? null
                        : _saveSale,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            widget.isEditing
                                ? Icons.update
                                : Icons.point_of_sale,
                          ),
                    label: Text(
                      _isSaving
                          ? 'Guardando...'
                          : widget.isEditing
                              ? 'Actualizar venta'
                              : 'Registrar venta',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
