import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../../services/auth_service.dart';
import '../../widgets/care_soul_logo.dart';
import '../../config/theme.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _success;
  int _resendTimer = 120;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() => _resendTimer = 120);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer == 0) {
        timer.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resendOtp() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final err = await AuthService.requestForgotPasswordOtp(widget.email);

    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      _startTimer();
      setState(() => _success = 'OTP sent successfully');
    } else {
      setState(() => _error = err);
    }
  }

  Future<void> _resetPassword() async {
    if (_otpCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final err = await AuthService.resetPassword(
      widget.email,
      _otpCtrl.text.trim(),
      _passCtrl.text.trim(),
    );

    if (!mounted) return;
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully! Please login.'),
          backgroundColor: CareSoulTheme.success,
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _error = err;
        _loading = false;
        _otpCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 55,
      textStyle: const TextStyle(
          fontSize: 22,
          color: CareSoulTheme.textPrimary,
          fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: CareSoulTheme.surface,
        border: Border.all(color: CareSoulTheme.divider),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                const CareSoulLogo(size: 80, showSubtitle: false),
                const SizedBox(height: 32),
                Container(
                  decoration: CareSoulTheme.cardDecoration,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'New Password',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter the OTP sent to ${widget.email}',
                        style: const TextStyle(
                            fontSize: 14, color: CareSoulTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Pinput(
                        length: 6,
                        controller: _otpCtrl,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: defaultPinTheme.copyWith(
                          decoration: (defaultPinTheme.decoration)?.copyWith(
                            border: Border.all(
                                color: CareSoulTheme.primary, width: 2),
                          ),
                        ),
                        autofocus: true,
                        onCompleted: (pin) {
                          if (_passCtrl.text.isNotEmpty &&
                              _confirmCtrl.text.isNotEmpty) {
                            _resetPassword();
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        style: const TextStyle(fontSize: 17),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirmCtrl,
                        obscureText: _obscure,
                        style: const TextStyle(fontSize: 17),
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        onSubmitted: (_) => _resetPassword(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CareSoulTheme.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: CareSoulTheme.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: CareSoulTheme.error,
                                        fontSize: 14)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                CareSoulTheme.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: CareSoulTheme.success, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_success!,
                                    style: const TextStyle(
                                        color: CareSoulTheme.success,
                                        fontSize: 14)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: CareSoulTheme.primary))
                          : FilledButton(
                              onPressed: _resetPassword,
                              child: const Text('Confirm Reset'),
                            ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed:
                            _resendTimer == 0 && !_loading ? _resendOtp : null,
                        child: Text(
                          _resendTimer > 0
                              ? 'Resend OTP in $_resendTimer s'
                              : 'Resend OTP',
                          style: TextStyle(
                            color: _resendTimer == 0
                                ? CareSoulTheme.primary
                                : CareSoulTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
