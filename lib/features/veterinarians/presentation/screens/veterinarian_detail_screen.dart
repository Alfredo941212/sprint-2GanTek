import 'package:flutter/material.dart';

import '../../data/models/veterinarian.dart';

class VeterinarianDetailScreen extends StatefulWidget {
  const VeterinarianDetailScreen({
    super.key,
    required this.veterinarian,
  });

  final Veterinarian veterinarian;

  @override
  State<VeterinarianDetailScreen> createState() =>
      _VeterinarianDetailScreenState();
}

class _VeterinarianDetailScreenState extends State<VeterinarianDetailScreen> {
  late Veterinarian _veterinarian;

  @override
  void initState() {
    super.initState();
    _veterinarian = widget.veterinarian;
  }

  // =========================================================
  // AUXILIARES
  // =========================================================

  String _valueOrDefault(
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) {
      return 'No registrado';
    }

    return value.trim();
  }

  // =========================================================
  // INTERFAZ
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final bool isActive = _veterinarian.status == 'Activo';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detalle del veterinario',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===============================================
          // ENCABEZADO
          // ===============================================

          Center(
            child: CircleAvatar(
              radius: 45,
              child: const Icon(
                Icons.medical_services_outlined,
                size: 42,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            _veterinarian.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.withValues(
                        alpha: 0.12,
                      )
                    : Colors.grey.withValues(
                        alpha: 0.15,
                      ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _veterinarian.status,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:
                      isActive ? Colors.green.shade700 : Colors.grey.shade700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ===============================================
          // INFORMACIÓN PROFESIONAL
          // ===============================================

          _SectionCard(
            title: 'Información profesional',
            icon: Icons.badge_outlined,
            children: [
              _InfoRow(
                label: 'Nombre',
                value: _veterinarian.name,
              ),
              _InfoRow(
                label: 'Cédula profesional',
                value: _valueOrDefault(
                  _veterinarian.professionalLicense,
                ),
              ),
              _InfoRow(
                label: 'Especialidad',
                value: _valueOrDefault(
                  _veterinarian.specialty,
                ),
              ),
              _InfoRow(
                label: 'Estado',
                value: _veterinarian.status,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ===============================================
          // CONTACTO
          // ===============================================

          _SectionCard(
            title: 'Contacto',
            icon: Icons.contact_phone_outlined,
            children: [
              _InfoRow(
                label: 'Teléfono',
                value: _valueOrDefault(
                  _veterinarian.phone,
                ),
              ),
              _InfoRow(
                label: 'Correo',
                value: _valueOrDefault(
                  _veterinarian.email,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ===============================================
          // OBSERVACIONES
          // ===============================================

          _SectionCard(
            title: 'Observaciones',
            icon: Icons.notes_outlined,
            children: [
              Text(
                _valueOrDefault(
                  _veterinarian.observations,
                ),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ===========================================================
// TARJETA DE SECCIÓN
// ===========================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// FILA DE INFORMACIÓN
// ===========================================================

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
