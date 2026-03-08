import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../../services/auth_service.dart';
import '../../widgets/care_soul_logo.dart';
import '../../config/theme.dart';
import '../dashboard/dashboard_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String password;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpCtrl = TextEditingController();
  bool _loading = false;
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
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resendOtp() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final err =
        await AuthService.requestRegisterOtp(widget.email, widget.password);

    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      _startTimer();
      setState(() => _success = 'OTP sent successfully');
    } else {
      setState(() => _error = err);
    }
  }

  Future<void> _verifyOtp(String otp) async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    final err = await AuthService.verifyRegister(
      widget.email,
      widget.password,
      otp,
    );

    if (!mounted) return;
    if (err == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
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
      appBar: AppBar(title: const Text('Verify Account')),
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
                        'Enter OTP',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Code sent to ${widget.email}',
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
                        onCompleted: _verifyOtp,
                        autofocus: true,
                      ),
                      const SizedBox(height: 24),
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
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
                      if (_success != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
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
                      _loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: CareSoulTheme.primary))
                          : FilledButton(
                              onPressed: () {
                                if (_otpCtrl.text.length == 6) {
                                  _verifyOtp(_otpCtrl.text);
                                }
                              },
                              child: const Text('Verify & Create Account'),
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
