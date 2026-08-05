class DashboardSummary {
  final int registeredCattle;
  final int availableCattle;
  final int publishedCattle;
  final int monthlySales;
  final double monthlyIncome;

  const DashboardSummary({
    required this.registeredCattle,
    required this.availableCattle,
    required this.publishedCattle,
    required this.monthlySales,
    required this.monthlyIncome,
  });

  factory DashboardSummary.empty() {
    return const DashboardSummary(
      registeredCattle: 0,
      availableCattle: 0,
      publishedCattle: 0,
      monthlySales: 0,
      monthlyIncome: 0,
    );
  }
}
