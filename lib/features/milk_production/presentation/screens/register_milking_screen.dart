import 'package:flutter/material.dart';

import '../../../cattle/data/models/cattle.dart';
import '../../../cattle/data/repositories/cattle_repository.dart';
import '../../../lots/data/models/lot.dart';
import '../../../lots/data/repositories/lot_repository.dart';
import '../../data/repositories/milking_repository.dart';

class RegisterMilkingScreen extends StatefulWidget {
  const RegisterMilkingScreen({
    super.key,
  });

  @override
  State<RegisterMilkingScreen> createState() => _RegisterMilkingScreenState();
}

class _RegisterMilkingScreenState extends State<RegisterMilkingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final LotRepository _lotRepository = LotRepository();

  final CattleRepository _cattleRepository = CattleRepository();

  final MilkingRepository _milkingRepository = MilkingRepository();

  final TextEditingController _dateController = TextEditingController();

  final TextEditingController _litersController = TextEditingController();

  final TextEditingController _observationsController = TextEditingController();

  List<Lot> _lots = [];
  List<Cattle> _productiveCattle = [];
  List<Cattle> _filteredCattle = [];

  int? _selectedLotId;
  int? _selectedCattleId;

  DateTime _selectedDate = DateTime.now();

  String? _selectedShift;

  bool _isLoading = true;
  bool _isSaving = false;

  static const List<String> _shiftOptions = [
    'Mañana',
    'Tarde',
    'Noche',
  ];

  @override
  void initState() {
    super.initState();

    _updateDateText();
    _loadData();
  }

  // =========================================================
  // CARGAR DATOS
  // =========================================================

  Future<void> _loadData() async {
    try {
      final List<Lot> lots = await _lotRepository.getActiveLots();

      final List<Cattle> cattle = await _cattleRepository.getProductiveCattle();

      if (!mounted) {
        return;
      }

      setState(() {
        _lots = lots;

        _productiveCattle = cattle;

        _filteredCattle = [];

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
        'No fue posible cargar los datos.',
      );

      debugPrint(
        'Error cargando datos de ordeña: $error',
      );
    }
  }

  // =========================================================
  // FILTRAR VACAS POR LOTE
  // =========================================================

  void _filterCattleByLot(
    int? lotId,
  ) {
    if (lotId == null) {
      setState(() {
        _selectedLotId = null;
        _selectedCattleId = null;
        _filteredCattle = [];
      });

      return;
    }

    final List<Cattle> cattle = _productiveCattle
        .where(
          (Cattle cattle) => cattle.lotId == lotId,
        )
        .toList();

    setState(() {
      _selectedLotId = lotId;
      _selectedCattleId = null;
      _filteredCattle = cattle;
    });
  }

  // =========================================================
  // FECHA
  // =========================================================

  void _updateDateText() {
    _dateController.text = '${_selectedDate.day.toString().padLeft(2, '0')}/'
        '${_selectedDate.month.toString().padLeft(2, '0')}/'
        '${_selectedDate.year}';
  }

  Future<void> _pickDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(
        2020,
      ),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = selectedDate;
      _updateDateText();
    });
  }

  // =========================================================
  // GUARDAR ORDEÑA
  // =========================================================

  Future<void> _saveMilking() async {
    if (_isSaving) {
      return;
    }

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final int? cattleId = _selectedCattleId;

    if (cattleId == null) {
      _showMessage(
        'Selecciona una vaca.',
      );

      return;
    }

    final double? liters = double.tryParse(
      _litersController.text.trim().replaceAll(
            ',',
            '.',
          ),
    );

    if (liters == null || liters <= 0) {
      _showMessage(
        'Ingresa una cantidad válida de litros.',
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _milkingRepository.insertMilking(
        cattleId: cattleId,
        date: _selectedDate,
        liters: liters,
        shift: _selectedShift,
        observations: _observationsController.text.trim(),
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

      String message = error.toString();

      if (message.startsWith(
        'Exception: ',
      )) {
        message = message.substring(
          11,
        );
      }

      _showMessage(
        message,
      );

      debugPrint(
        'Error guardando ordeña: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // MENSAJE
  // =========================================================

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
        ),
      );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _dateController.dispose();
    _litersController.dispose();
    _observationsController.dispose();

    super.dispose();
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
          'Registrar ordeña',
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(
                  18,
                ),
                children: [
                  // ============================================
                  // LOTE
                  // ============================================

                  DropdownButtonFormField<int>(
                    initialValue: _selectedLotId,
                    decoration: const InputDecoration(
                      labelText: 'Lote',
                      prefixIcon: Icon(
                        Icons.grid_view_outlined,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: _lots
                        .where(
                      (Lot lot) => lot.id != null,
                    )
                        .map(
                      (Lot lot) {
                        return DropdownMenuItem<int>(
                          value: lot.id!,
                          child: Text(
                            lot.name,
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: _filterCattleByLot,
                    validator: (int? value) {
                      if (value == null) {
                        return 'Selecciona un lote';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // ============================================
                  // VACA
                  // ============================================

                  DropdownButtonFormField<int>(
                    initialValue: _selectedCattleId,
                    decoration: InputDecoration(
                      labelText: 'Vaca',
                      prefixIcon: const Icon(
                        Icons.pets_outlined,
                      ),
                      border: const OutlineInputBorder(),
                      helperText: _selectedLotId == null
                          ? 'Primero selecciona un lote'
                          : _filteredCattle.isEmpty
                              ? 'No hay vacas en producción en este lote'
                              : null,
                    ),
                    items: _filteredCattle
                        .where(
                      (Cattle cattle) => cattle.id != null,
                    )
                        .map(
                      (
                        Cattle cattle,
                      ) {
                        final String cattleName = cattle.name.trim().isNotEmpty
                            ? cattle.name
                            : 'Arete ${cattle.code}';

                        return DropdownMenuItem<int>(
                          value: cattle.id!,
                          child: Text(
                            '$cattleName - ${cattle.code}',
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: _filteredCattle.isEmpty
                        ? null
                        : (int? value) {
                            setState(
                              () {
                                _selectedCattleId = value;
                              },
                            );
                          },
                    validator: (int? value) {
                      if (value == null) {
                        return 'Selecciona una vaca';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // ============================================
                  // FECHA
                  // ============================================

                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: const InputDecoration(
                      labelText: 'Fecha de ordeña',
                      prefixIcon: Icon(
                        Icons.calendar_month_outlined,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // ============================================
                  // LITROS
                  // ============================================

                  TextFormField(
                    controller: _litersController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Litros producidos',
                      hintText: 'Ej. 2.5',
                      prefixIcon: Icon(
                        Icons.water_drop_outlined,
                      ),
                      suffixText: 'L',
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? value) {
                      final String text = value?.trim() ?? '';

                      if (text.isEmpty) {
                        return 'Ingresa los litros producidos';
                      }

                      final double? liters = double.tryParse(
                        text.replaceAll(
                          ',',
                          '.',
                        ),
                      );

                      if (liters == null || liters <= 0) {
                        return 'Ingresa una cantidad válida';
                      }

                      if (liters > 100) {
                        return 'Verifica la cantidad ingresada';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // ============================================
                  // TURNO OPCIONAL
                  // ============================================

                  DropdownButtonFormField<String>(
                    initialValue: _selectedShift,
                    decoration: const InputDecoration(
                      labelText: 'Turno (opcional)',
                      prefixIcon: Icon(
                        Icons.schedule_outlined,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: _shiftOptions.map(
                      (
                        String shift,
                      ) {
                        return DropdownMenuItem<String>(
                          value: shift,
                          child: Text(
                            shift,
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _selectedShift = value;
                      });
                    },
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // ============================================
                  // OBSERVACIONES
                  // ============================================

                  TextFormField(
                    controller: _observationsController,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (opcional)',
                      hintText: 'Ej. Producción normal',
                      prefixIcon: Icon(
                        Icons.notes_outlined,
                      ),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  // ============================================
                  // INFORMACIÓN
                  // ============================================

                  Container(
                    padding: const EdgeInsets.all(
                      14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        12,
                      ),
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            'El número de ordeña se asignará automáticamente según los registros que tenga la vaca en esta fecha.',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  // ============================================
                  // GUARDAR
                  // ============================================

                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveMilking,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.save_outlined,
                            ),
                      label: Text(
                        _isSaving ? 'Guardando...' : 'Guardar ordeña',
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),
                ],
              ),
            ),
    );
  }
}
