import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bool loggedIn = await AuthService.isLoggedIn();

  runApp(CareSoulApp(initialLoggedIn: loggedIn));
}

class CareSoulApp extends StatelessWidget {
  final bool initialLoggedIn;
  const CareSoulApp({super.key, required this.initialLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CareSoul',
      theme: CareSoulTheme.theme,
      home: initialLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
