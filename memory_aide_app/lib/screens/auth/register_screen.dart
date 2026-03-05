import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/care_soul_logo.dart';
import 'login_screen.dart';
import '../dashboard/dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _register() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final err = await AuthService.register(
        _emailCtrl.text.trim(), _passCtrl.text.trim());

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
                const CareSoulLogo(size: 80),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailCtrl,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline)),
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
                        onPressed: _register,
                        child: const Text('Create Account')),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('Already have an account? Login',
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
