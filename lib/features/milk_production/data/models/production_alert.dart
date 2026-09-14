enum ProductionAlertType {
  cow,
  lot,
  trend,
}

class ProductionAlert {
  final ProductionAlertType type;

  /// Id de la vaca o lote relacionado.
  final int entityId;

  /// Nombre que se mostrará al usuario.
  final String title;

  /// Información adicional.
  final String message;

  /// Producción obtenida.
  final double actualProduction;

  /// Producción mínima esperada.
  final double expectedProduction;

  /// Fecha evaluada.
  final DateTime date;

  /// Id del lote relacionado, cuando aplique.
  final int? lotId;

  /// Nombre del lote, cuando aplique.
  final String? lotName;

  const ProductionAlert({
    required this.type,
    required this.entityId,
    required this.title,
    required this.message,
    required this.actualProduction,
    required this.expectedProduction,
    required this.date,
    this.lotId,
    this.lotName,
  });

  double get difference {
    return expectedProduction - actualProduction;
  }

  double get percentageReached {
    if (expectedProduction <= 0) {
      return 0;
    }

    return (actualProduction / expectedProduction) * 100;
  }

  bool get isLowProduction {
    return actualProduction < expectedProduction;
  }
}
