class DashboardSummary {
  final int registeredCattle;

  final int productiveCattle;

  final double todayMilkProduction;

  final double monthlyMilkProduction;

  final double averagePerCow;

  final int lowProductionAlerts;

  final int upcomingVaccines;

  final int overdueVaccines;

  final List<String> registeredCattleLots;

  final List<String> productiveCattleLots;

  final String todayLabel;

  final String monthLabel;

  const DashboardSummary({
    required this.registeredCattle,
    required this.productiveCattle,
    required this.todayMilkProduction,
    required this.monthlyMilkProduction,
    required this.averagePerCow,
    required this.lowProductionAlerts,
    required this.upcomingVaccines,
    required this.overdueVaccines,
    required this.registeredCattleLots,
    required this.productiveCattleLots,
    required this.todayLabel,
    required this.monthLabel,
  });

  factory DashboardSummary.empty() {
    return const DashboardSummary(
      registeredCattle: 0,
      productiveCattle: 0,
      todayMilkProduction: 0,
      monthlyMilkProduction: 0,
      averagePerCow: 0,
      lowProductionAlerts: 0,
      upcomingVaccines: 0,
      overdueVaccines: 0,
      registeredCattleLots: <String>[],
      productiveCattleLots: <String>[],
      todayLabel: '',
      monthLabel: '',
    );
  }
}
