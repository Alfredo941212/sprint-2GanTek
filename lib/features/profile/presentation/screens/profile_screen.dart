import 'package:flutter/material.dart';

import '../../../../core/session/session_manager.dart';
import '../../../auth/presentation/screens/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _logout(BuildContext context) {
    SessionManager.instance.clearSession();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 46,
              child: Icon(
                Icons.person,
                size: 50,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              user?.fullName ?? 'Usuario GanTek',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              user?.role ?? 'Ganadero',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 30),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.email_outlined,
                ),
                title: Text(
                  user?.email ?? 'Sin correo',
                ),
                subtitle: const Text(
                  'Correo electrónico',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.phone_outlined,
                ),
                title: Text(
                  user?.phone.isNotEmpty == true ? user!.phone : 'Sin teléfono',
                ),
                subtitle: const Text(
                  'Número telefónico',
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _logout(context);
                },
                icon: const Icon(
                  Icons.logout,
                ),
                label: const Text(
                  'Cerrar sesión',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
