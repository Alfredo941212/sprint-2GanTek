class ReportSummary {
  final int totalCattle;

  final int productiveCattle;

  final int dryCattle;

  final double totalMilkProduction;

  final double averageDailyProduction;

  final double averageProductionPerCow;

  final int totalMilkings;

  final int appliedVaccines;

  final int upcomingVaccines;

  final int overdueVaccines;

  final int lowProductionAlerts;

  const ReportSummary({
    required this.totalCattle,
    required this.productiveCattle,
    required this.dryCattle,
    required this.totalMilkProduction,
    required this.averageDailyProduction,
    required this.averageProductionPerCow,
    required this.totalMilkings,
    required this.appliedVaccines,
    required this.upcomingVaccines,
    required this.overdueVaccines,
    required this.lowProductionAlerts,
  });

  factory ReportSummary.empty() {
    return const ReportSummary(
      totalCattle: 0,
      productiveCattle: 0,
      dryCattle: 0,
      totalMilkProduction: 0,
      averageDailyProduction: 0,
      averageProductionPerCow: 0,
      totalMilkings: 0,
      appliedVaccines: 0,
      upcomingVaccines: 0,
      overdueVaccines: 0,
      lowProductionAlerts: 0,
    );
  }
}

class LotProductionReport {
  final int lotId;

  final String lotName;

  final double totalLiters;

  const LotProductionReport({
    required this.lotId,
    required this.lotName,
    required this.totalLiters,
  });

  factory LotProductionReport.fromMap(
    Map<String, dynamic> map,
  ) {
    return LotProductionReport(
      lotId: (map['lot_id'] as num?)?.toInt() ?? 0,
      lotName: map['lot_name'] as String? ?? 'Sin lote',
      totalLiters: (map['total_liters'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RecentMilkingReport {
  final int id;

  final String cattleCode;

  final String? cattleName;

  final String lotName;

  final DateTime date;

  final int milkingNumber;

  final String? shift;

  final double liters;

  const RecentMilkingReport({
    required this.id,
    required this.cattleCode,
    required this.cattleName,
    required this.lotName,
    required this.date,
    required this.milkingNumber,
    required this.shift,
    required this.liters,
  });

  factory RecentMilkingReport.fromMap(
    Map<String, dynamic> map,
  ) {
    return RecentMilkingReport(
      id: (map['id'] as num?)?.toInt() ?? 0,
      cattleCode: map['cattle_code'] as String? ?? '',
      cattleName: map['cattle_name'] as String?,
      lotName: map['lot_name'] as String? ?? 'Sin lote',
      date: DateTime.parse(
        map['date'] as String,
      ),
      milkingNumber: (map['milking_number'] as num?)?.toInt() ?? 0,
      shift: map['shift'] as String?,
      liters: (map['liters'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
