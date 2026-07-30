import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';

class GanTekApp extends StatelessWidget {
  const GanTekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GanTek',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
