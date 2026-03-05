import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/care_soul_logo.dart';
import 'register_screen.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final err =
        await AuthService.login(_emailCtrl.text.trim(), _passCtrl.text.trim());

    if (!mounted) return;
    if (err == null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } else {
      setState(() {
        _error = err;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const CareSoulLogo(size: 90),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailCtrl,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 28),
                _loading
                    ? const CircularProgressIndicator()
                    : FilledButton(
                        onPressed: _login,
                        child: const Text('Login'),
                      ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text('Create Account',
                      style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
