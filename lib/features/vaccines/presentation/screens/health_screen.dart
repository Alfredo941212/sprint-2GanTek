import 'package:flutter/material.dart';

import '../../../veterinarians/presentation/screens/veterinarian_list_screen.dart';
import 'vaccine_list_screen.dart';

import 'vaccine_alerts_screen.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sanidad',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Gestión sanitaria',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Administra las vacunaciones y los '
            'veterinarios responsables.',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 20),

          // ==========================================
          // VACUNACIONES
          // ==========================================

          _HealthOptionCard(
            icon: Icons.vaccines_outlined,
            title: 'Vacunaciones',
            description: 'Registrar y consultar el historial '
                'de vacunas del ganado.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VaccineListScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          // ==========================================
          // VETERINARIOS
          // ==========================================

          _HealthOptionCard(
            icon: Icons.medical_services_outlined,
            title: 'Veterinarios',
            description: 'Registrar y administrar los '
                'veterinarios responsables.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VeterinarianListScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          _HealthOptionCard(
            icon: Icons.notifications_active_outlined,
            title: 'Alertas de vacunación',
            description: 'Consultar próximas dosis y vacunas vencidas.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VaccineAlertsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HealthOptionCard extends StatelessWidget {
  const _HealthOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                child: Icon(
                  icon,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
