import 'package:flutter/material.dart';

import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/summary_card.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../cattle/presentation/screens/cattle_list_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../sales/presentation/screens/sales_list_screen.dart';
import '../../../vaccines/presentation/screens/vaccine_list_screen.dart';
import '../../data/models/dashboard_summary.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../../cattle/presentation/screens/register_cattle_screen.dart';
import '../../../sales/presentation/screens/register_sale_screen.dart';
import '../../../vaccines/presentation/screens/register_vaccine_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
          content: Text(successMessage),
        ),
      );
  }

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

  void _open(
    BuildContext context,
    Widget screen,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    ).then((_) {
      /*
       * Cuando regresamos de ganado, ventas,
       * vacunas o reportes, actualizamos el panel.
       */
      _loadDashboard();
    });
  }

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

  String get _firstName {
    final String? fullName = SessionManager.instance.currentUser?.fullName;

    if (fullName == null || fullName.trim().isEmpty) {
      return 'Usuario';
    }

    return fullName.trim().split(' ').first;
  }

  String _formatMoney(double value) {
    final String amount = value.toStringAsFixed(2);

    final List<String> parts = amount.split('.');

    final String integers = parts[0];
    final String decimals = parts[1];

    final StringBuffer result = StringBuffer();

    for (int index = 0; index < integers.length; index++) {
      final int position = integers.length - index;

      result.write(integers[index]);

      if (position > 1 && position % 3 == 1) {
        result.write(',');
      }
    }

    return '\$${result.toString()}.$decimals MXN';
  }

  Future<void> _showUserMenu() async {
    final selected = await showMenu<String>(
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
              const SizedBox(height: 3),
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
            title: Text('Mi perfil'),
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

  @override
  Widget build(BuildContext context) {
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

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        children: const [
          SizedBox(height: 250),
          Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 130),
          const Icon(
            Icons.error_outline,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No fue posible cargar el resumen.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            label: const Text(
              'Intentar nuevamente',
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '¡Hola, $_firstName!',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Resumen comercial',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.48,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            SummaryCard(
              title: 'Ganado registrado',
              value: '${_summary.registeredCattle}',
              icon: Icons.pets,
            ),
            SummaryCard(
              title: 'Listos para venta',
              value: '${_summary.availableCattle}',
              icon: Icons.sell_outlined,
              iconColor: AppColors.gold,
            ),
            SummaryCard(
              title: 'Publicados',
              value: '${_summary.publishedCattle}',
              icon: Icons.campaign_outlined,
              iconColor: AppColors.info,
            ),
            SummaryCard(
              title: 'Ventas del mes',
              value: '${_summary.monthlySales}',
              icon: Icons.point_of_sale,
              iconColor: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.successSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.trending_up,
                color: AppColors.success,
                size: 36,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ingresos del mes',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatMoney(
                        _summary.monthlyIncome,
                      ),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Acciones rápidas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.add_circle_outline,
                label: 'Nuevo\nganado',
                onTap: () {
                  _openForm(
                    const RegisterCattleScreen(),
                    'Ganado registrado correctamente.',
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: Icons.point_of_sale_outlined,
                label: 'Nueva\nventa',
                onTap: () {
                  _openForm(
                    const RegisterSaleScreen(),
                    'Venta registrada correctamente.',
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: Icons.vaccines_outlined,
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
        const SizedBox(height: 26),
        Text(
          'Administración',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _ModuleTile(
          icon: Icons.pets,
          title: 'Ganado',
          subtitle: 'Consultar, actualizar y eliminar animales',
          onTap: () {
            _open(
              context,
              const CattleListScreen(),
            );
          },
        ),
        const SizedBox(height: 10),
        _ModuleTile(
          icon: Icons.point_of_sale,
          title: 'Ventas',
          subtitle: 'Consultar, actualizar y cancelar ventas',
          onTap: () {
            _open(
              context,
              const SalesListScreen(),
            );
          },
        ),
        const SizedBox(height: 10),
        _ModuleTile(
          icon: Icons.vaccines_outlined,
          title: 'Vacunas',
          subtitle: 'Consultar, actualizar y eliminar vacunas',
          onTap: () {
            _open(
              context,
              const VaccineListScreen(),
            );
          },
        ),
        const SizedBox(height: 10),
        _ModuleTile(
          icon: Icons.bar_chart,
          title: 'Reportes',
          subtitle: 'Consultar indicadores',
          onTap: () {
            _open(
              context,
              const ReportsScreen(),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 105,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }
}
