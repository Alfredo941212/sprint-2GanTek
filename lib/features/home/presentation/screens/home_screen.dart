import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../cattle/presentation/screens/cattle_list_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../sales/presentation/screens/sales_list_screen.dart';
import '../../../vaccines/presentation/screens/vaccine_list_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(
    BuildContext context,
    Widget screen,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
  }

  void _showPending(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Este módulo se desarrollará en el siguiente avance.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GanTek'),
        actions: [
          IconButton(
            tooltip: 'Perfil',
            onPressed: () {
              _open(
                context,
                const ProfileScreen(),
              );
            },
            icon: const Icon(
              Icons.person_outline,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido a GanTek',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Controla el registro, estado y venta de tu ganado.',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Módulos principales',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            icon: Icons.pets,
            title: 'Ganado registrado',
            subtitle: 'Consulta y registra animales',
            onTap: () {
              _open(
                context,
                const CattleListScreen(),
              );
            },
          ),
          _ModuleCard(
            icon: Icons.sell_outlined,
            title: 'Ventas',
            subtitle: 'Registrar y consultar ventas de ganado',
            onTap: () {
              _open(
                context,
                const SalesListScreen(),
              );
            },
          ),
          _ModuleCard(
            icon: Icons.vaccines_outlined,
            title: 'Vacunas',
            subtitle: 'Registrar vacunas y consultar próximas dosis',
            onTap: () {
              _open(
                context,
                const VaccineListScreen(),
              );
            },
          ),
          _ModuleCard(
            icon: Icons.bar_chart,
            title: 'Reportes',
            subtitle: 'Consulta ganado, ventas y control sanitario',
            onTap: () {
              _open(
                context,
                const ReportsScreen(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
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
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
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
