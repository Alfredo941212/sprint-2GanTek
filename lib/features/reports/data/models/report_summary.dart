class ReportSummary {
  final int totalCattle;
  final int availableCattle;
  final int soldCattle;

  final int completedSales;
  final double totalSalesAmount;
  final double totalSoldWeight;
  final double averagePricePerKg;

  final int appliedVaccines;
  final int upcomingVaccines;
  final int overdueVaccines;

  const ReportSummary({
    required this.totalCattle,
    required this.availableCattle,
    required this.soldCattle,
    required this.completedSales,
    required this.totalSalesAmount,
    required this.totalSoldWeight,
    required this.averagePricePerKg,
    required this.appliedVaccines,
    required this.upcomingVaccines,
    required this.overdueVaccines,
  });

  factory ReportSummary.empty() {
    return const ReportSummary(
      totalCattle: 0,
      availableCattle: 0,
      soldCattle: 0,
      completedSales: 0,
      totalSalesAmount: 0,
      totalSoldWeight: 0,
      averagePricePerKg: 0,
      appliedVaccines: 0,
      upcomingVaccines: 0,
      overdueVaccines: 0,
    );
  }
}

class RecentSaleReport {
  final int id;
  final String cattleCode;
  final String buyerName;
  final DateTime saleDate;
  final double saleWeight;
  final double pricePerKg;
  final double total;
  final String status;

  const RecentSaleReport({
    required this.id,
    required this.cattleCode,
    required this.buyerName,
    required this.saleDate,
    required this.saleWeight,
    required this.pricePerKg,
    required this.total,
    required this.status,
  });

  factory RecentSaleReport.fromMap(
    Map<String, dynamic> map,
  ) {
    return RecentSaleReport(
      id: (map['id'] as num).toInt() ?? 0,
      cattleCode: map['cattle_code'] as String? ?? '',
      buyerName: map['buyer_name'] as String? ?? '',
      saleDate: DateTime.parse(
        map['sale_date'] as String,
      ),
      saleWeight: (map['sale_weight'] as num?)?.toDouble() ?? 0,
      pricePerKg: (map['price_per_kg'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? '',
    );
  }
}
