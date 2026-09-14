import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/summary_card.dart';

import '../../../auth/presentation/screens/login_screen.dart';
import '../../../cattle/presentation/screens/cattle_list_screen.dart';
import '../../../cattle/presentation/screens/register_cattle_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../vaccines/presentation/screens/register_vaccine_screen.dart';

import '../../data/models/dashboard_summary.dart';
import '../../data/repositories/dashboard_repository.dart';

import '../../../lots/presentation/screens/lot_list_screen.dart';

import '../../../milk_production/presentation/screens/milking_list_screen.dart';
import '../../../milk_production/presentation/screens/register_milking_screen.dart';

import '../../../milk_production/presentation/screens/monthly_production_screen.dart';
import '../../../milk_production/presentation/screens/production_alerts_screen.dart';
import '../../../vaccines/presentation/screens/health_screen.dart';
import '../../../vaccines/presentation/screens/vaccine_alerts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DashboardRepository _dashboardRepository = DashboardRepository();

  DashboardSummary _summary = DashboardSummary.empty();

  bool _isLoading = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadDashboard();
  }

  // =========================================================
  // ABRIR FORMULARIO
  // =========================================================

  Future<void> _openForm(
    Widget screen,
    String successMessage,
  ) async {
    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    await _loadDashboard();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            successMessage,
          ),
        ),
      );
  }

  // =========================================================
  // CARGAR DASHBOARD
  // =========================================================

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;

        _errorMessage = null;
      });
    }

    try {
      final DashboardSummary result = await _dashboardRepository.getSummary();

      if (!mounted) {
        return;
      }

      setState(() {
        _summary = result;

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();

        _isLoading = false;
      });

      debugPrint(
        'Error cargando dashboard: $error',
      );
    }
  }

  // =========================================================
  // ABRIR PANTALLA
  // =========================================================

  void _open(
    BuildContext context,
    Widget screen,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    ).then(
      (_) {
        _loadDashboard();
      },
    );
  }

  // =========================================================
  // CERRAR SESIÓN
  // =========================================================

  Future<void> _logout() async {
    await SessionManager.instance.clearSession();

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // =========================================================
  // NOMBRE DEL USUARIO
  // =========================================================

  String get _firstName {
    final String? fullName = SessionManager.instance.currentUser?.fullName;

    if (fullName == null || fullName.trim().isEmpty) {
      return 'Usuario';
    }

    return fullName.trim().split(' ').first;
  }

  // =========================================================
  // FORMATEAR LITROS
  // =========================================================

  String _formatLiters(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return '${value.toStringAsFixed(0)} L';
    }

    return '${value.toStringAsFixed(1)} L';
  }

  // =========================================================
  // TEXTO DE LOTES
  // =========================================================

  String _lotsSubtitle(
    List<String> lots,
  ) {
    if (lots.isEmpty) {
      return 'Sin lotes asignados';
    }

    if (lots.length == 1) {
      return lots.first;
    }

    return '${lots.length} lotes';
  }

  // =========================================================
  // MENÚ DEL USUARIO
  // =========================================================

  Future<void> _showUserMenu() async {
    final String? selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(
        1000,
        75,
        12,
        0,
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SessionManager.instance.currentUser?.fullName ??
                    'Usuario GanTek',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                SessionManager.instance.currentUser?.email ?? 'Sin correo',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.person_outline,
            ),
            title: Text(
              'Mi perfil',
            ),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.logout,
              color: AppColors.danger,
            ),
            title: Text(
              'Cerrar sesión',
              style: TextStyle(
                color: AppColors.danger,
              ),
            ),
          ),
        ),
      ],
    );

    if (!mounted) {
      return;
    }

    if (selected == 'profile') {
      _open(
        context,
        const ProfileScreen(),
      );
    }

    if (selected == 'logout') {
      await _logout();
    }
  }

  // =========================================================
  // DETALLE GANADO REGISTRADO
  // =========================================================

  Future<void> _showRegisteredCattleDetail() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.cow,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Text(
                      'Ganado registrado',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 20,
                ),
                _DetailRow(
                  label: 'Total de animales',
                  value: '${_summary.registeredCattle}',
                ),
                const Divider(
                  height: 28,
                ),
                const Text(
                  'Distribución por lote',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                if (_summary.registeredCattleLots.isEmpty)
                  const Text(
                    'Todavía no hay lotes asignados.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  ..._summary.registeredCattleLots.map(
                    (String lot) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.grid_view_outlined,
                              size: 18,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Expanded(
                              child: Text(
                                lot,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(
                  height: 20,
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                      );

                      _open(
                        context,
                        const CattleListScreen(),
                      );
                    },
                    icon: const Icon(
                      Icons.list_alt,
                    ),
                    label: const Text(
                      'Ver ganado',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // DETALLE VACAS PRODUCIENDO
  // =========================================================

  Future<void> _showProductiveCattleDetail() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.water_drop_outlined,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Text(
                      'Vacas produciendo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 20,
                ),
                _DetailRow(
                  label: 'Vacas en producción',
                  value: '${_summary.productiveCattle}',
                ),
                const Divider(
                  height: 28,
                ),
                const Text(
                  'Lotes con vacas en producción',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                if (_summary.productiveCattleLots.isEmpty)
                  const Text(
                    'Todavía no hay información de lotes.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  ..._summary.productiveCattleLots.map(
                    (String lot) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.grid_view_outlined,
                              size: 18,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Expanded(
                              child: Text(
                                lot,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // DETALLE PRODUCCIÓN DE HOY
  // =========================================================

  Future<void> _showTodayProductionDetail() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.water_drop_outlined,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        'Producción - ${_summary.todayLabel}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 20,
                ),
                _DetailRow(
                  label: 'Producción total',
                  value: _formatLiters(
                    _summary.todayMilkProduction,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                _DetailRow(
                  label: 'Vacas en producción',
                  value: '${_summary.productiveCattle}',
                ),
                const SizedBox(
                  height: 8,
                ),
                _DetailRow(
                  label: 'Promedio por vaca',
                  value: _formatLiters(
                    _summary.averagePerCow,
                  ),
                ),
                const Divider(
                  height: 28,
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                      );

                      _open(
                        context,
                        const MilkingListScreen(),
                      );
                    },
                    icon: const Icon(
                      Icons.water_drop_outlined,
                    ),
                    label: const Text(
                      'Ver producción',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // DETALLE PRODUCCIÓN DEL MES
  // =========================================================

  // =========================================================
  // ABRIR REGISTRO DE ORDEÑA
  // =========================================================

  Future<void> _openRegisterMilking() async {
    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterMilkingScreen(),
      ),
    );

    if (saved == true && mounted) {
      await _loadDashboard();
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GANTEK'),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none,
            ),
          ),
          IconButton(
            tooltip: 'Cuenta',
            onPressed: _showUserMenu,
            icon: const Icon(
              Icons.account_circle_outlined,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: _buildBody(),
      ),
    );
  }

  // =========================================================
  // CUERPO
  // =========================================================

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        children: const [
          SizedBox(
            height: 250,
          ),
          Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(
          24,
        ),
        children: [
          const SizedBox(
            height: 130,
          ),
          const Icon(
            Icons.error_outline,
            size: 64,
          ),
          const SizedBox(
            height: 16,
          ),
          const Text(
            'No fue posible cargar el resumen.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 20,
          ),
          ElevatedButton.icon(
            onPressed: _loadDashboard,
            icon: const Icon(
              Icons.refresh,
            ),
            label: const Text(
              'Intentar nuevamente',
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(
        16,
      ),
      children: [
        // =====================================================
        // SALUDO
        // =====================================================

        Text(
          '¡Hola, $_firstName!',
          style: Theme.of(context).textTheme.headlineMedium,
        ),

        const SizedBox(
          height: 4,
        ),

        Text(
          'Resumen de producción',
          style: Theme.of(context).textTheme.bodyLarge,
        ),

        const SizedBox(
          height: 18,
        ),

        // =====================================================
        // TARJETAS
        // =====================================================

        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.30,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            SummaryCard(
              title: 'Ganado registrado',
              value: '${_summary.registeredCattle}',
              subtitle: _lotsSubtitle(
                _summary.registeredCattleLots,
              ),
              icon: const FaIcon(
                FontAwesomeIcons.cow,
              ),
              onTap: _showRegisteredCattleDetail,
            ),
            SummaryCard(
              title: 'Vacas produciendo',
              value: '${_summary.productiveCattle}',
              subtitle: _lotsSubtitle(
                _summary.productiveCattleLots,
              ),
              icon: const Icon(
                Icons.water_drop_outlined,
              ),
              iconColor: AppColors.info,
              onTap: _showProductiveCattleDetail,
            ),
            SummaryCard(
              title: 'Producción hoy',
              value: _formatLiters(
                _summary.todayMilkProduction,
              ),
              subtitle: _summary.todayLabel,
              icon: const Icon(
                Icons.water_drop,
              ),
              iconColor: AppColors.success,
              onTap: _showTodayProductionDetail,
            ),
            SummaryCard(
              title: 'Producción del mes',
              value: _formatLiters(
                _summary.monthlyMilkProduction,
              ),
              subtitle: _summary.monthLabel,
              icon: const Icon(
                Icons.bar_chart_outlined,
              ),
              iconColor: AppColors.gold,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MonthlyProductionScreen(),
                  ),
                );
              },
            ),
            SummaryCard(
              title: 'Alertas de producción',
              value: '${_summary.lowProductionAlerts}',
              subtitle: 'Baja producción y tendencia',
              icon: const Icon(
                Icons.warning_amber_rounded,
              ),
              iconColor: AppColors.warning,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProductionAlertsScreen(),
                  ),
                );
              },
            ),
            SummaryCard(
              title: 'Alertas de vacunación',
              value: '${_summary.upcomingVaccines + _summary.overdueVaccines}',
              subtitle: '${_summary.upcomingVaccines} próximas · '
                  '${_summary.overdueVaccines} vencidas',
              icon: const Icon(
                Icons.vaccines_outlined,
              ),
              iconColor: AppColors.warning,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VaccineAlertsScreen(),
                  ),
                ).then((_) {
                  _loadDashboard();
                });
              },
            ),
          ],
        ),

        const SizedBox(
          height: 24,
        ),

        // =====================================================
        // ACCIONES RÁPIDAS
        // =====================================================

        Text(
          'Acciones rápidas',
          style: Theme.of(context).textTheme.titleLarge,
        ),

        const SizedBox(
          height: 12,
        ),

        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: const FaIcon(
                  FontAwesomeIcons.cow,
                ),
                label: 'Nuevo\nganado',
                onTap: () {
                  _openForm(
                    const RegisterCattleScreen(),
                    'Ganado registrado correctamente.',
                  );
                },
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: _QuickAction(
                icon: const Icon(
                  Icons.water_drop_outlined,
                ),
                label: 'Registrar\nordeña',
                onTap: _openRegisterMilking,
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: _QuickAction(
                icon: const Icon(
                  Icons.vaccines_outlined,
                ),
                label: 'Nueva\nvacuna',
                onTap: () {
                  _openForm(
                    const RegisterVaccineScreen(),
                    'Vacunación registrada correctamente.',
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 26,
        ),

        // =====================================================
        // ADMINISTRACIÓN
        // =====================================================

        Text(
          'Administración',
          style: Theme.of(context).textTheme.titleLarge,
        ),

        const SizedBox(
          height: 12,
        ),

        _ModuleTile(
          icon: const FaIcon(
            FontAwesomeIcons.cow,
          ),
          title: 'Ganado',
          subtitle: 'Consultar, actualizar y administrar animales',
          onTap: () {
            _open(
              context,
              const CattleListScreen(),
            );
          },
        ),

        const SizedBox(
          height: 10,
        ),

        _ModuleTile(
          icon: const Icon(
            Icons.grid_view_outlined,
          ),
          title: 'Lotes',
          subtitle: 'Organizar el ganado por lote',
          onTap: () {
            _open(
              context,
              const LotListScreen(),
            );
          },
        ),

        const SizedBox(
          height: 10,
        ),

        _ModuleTile(
          icon: const Icon(
            Icons.water_drop_outlined,
          ),
          title: 'Producción',
          subtitle: 'Registrar y consultar producción de leche',
          onTap: () {
            _open(
              context,
              const MilkingListScreen(),
            );
          },
        ),

        const SizedBox(
          height: 10,
        ),

        _ModuleTile(
          icon: const Icon(
            Icons.health_and_safety_outlined,
          ),
          title: 'Sanidad',
          subtitle: 'Vacunaciones y veterinarios',
          onTap: () {
            _open(
              context,
              const HealthScreen(),
            );
          },
        ),

        const SizedBox(
          height: 10,
        ),

        _ModuleTile(
          icon: const Icon(
            Icons.bar_chart,
          ),
          title: 'Reportes',
          subtitle: 'Consultar indicadores y producción',
          onTap: () {
            _open(
              context,
              const ReportsScreen(),
            );
          },
        ),

        const SizedBox(
          height: 24,
        ),
      ],
    );
  }
}

// ===========================================================
// ACCIÓN RÁPIDA
// ===========================================================

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;

  final String label;

  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        12,
      ),
      child: Container(
        height: 105,
        padding: const EdgeInsets.all(
          8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            12,
          ),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: const IconThemeData(
                color: AppColors.primary,
                size: 30,
              ),
              child: icon,
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// MÓDULO
// ===========================================================

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget icon;

  final String title;

  final String subtitle;

  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(
              10,
            ),
          ),
          child: Center(
            child: IconTheme(
              data: const IconThemeData(
                color: AppColors.primary,
                size: 24,
              ),
              child: icon,
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }
}

// ===========================================================
// FILA DE DETALLE
// ===========================================================

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;

  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
