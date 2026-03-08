import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Core auth service with JWT token management.
class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _emailKey = 'user_email';
  static const _patientIdKey = 'patient_id';

  /// Get stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Get stored user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Get stored patient ID
  static Future<String?> getPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    String? pid = prefs.getString(_patientIdKey);
    if (pid != null && pid.isNotEmpty) return pid;

    // Fallback if missing
    final userId = prefs.getString(_userIdKey);
    final token = prefs.getString(_tokenKey);
    if (userId != null && token != null) {
      try {
        final response = await http.get(
          Uri.parse(ApiConfig.patientUrl(userId)),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['id'] != null) {
            pid = data['id'];
            await prefs.setString(_patientIdKey, pid!);
          }
        }
      } catch (_) {}
    }
    return pid;
  }

  /// Get stored email
  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Auth headers for API calls
  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  /// Request OTP for Registration
  static Future<String?> requestRegisterOtp(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerRequestOtpUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      if (response.statusCode == 200) return null;
      final data = jsonDecode(response.body);
      return data['detail'] ?? 'Failed to send OTP.';
    } catch (e) {
      return 'Connection error. Is the server running?';
    }
  }

  /// Verify OTP and Complete Registration
  static Future<String?> verifyRegister(
      String email, String password, String otp) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerVerifyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'otp': otp,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveSession(data);
        return null;
      }
      final data = jsonDecode(response.body);
      return data['detail'] ?? 'Registration failed.';
    } catch (e) {
      return 'Connection error. Is the server running?';
    }
  }

  /// Request OTP for Forgot Password
  static Future<String?> requestForgotPasswordOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.forgotPasswordOtpUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) return null;
      final data = jsonDecode(response.body);
      return data['detail'] ?? 'Failed to send OTP.';
    } catch (e) {
      return 'Connection error. Is the server running?';
    }
  }

  /// Reset Password with OTP
  static Future<String?> resetPassword(
      String email, String otp, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.resetPasswordUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'new_password': newPassword,
        }),
      );
      if (response.statusCode == 200) return null;
      final data = jsonDecode(response.body);
      return data['detail'] ?? 'Failed to reset password.';
    } catch (e) {
      return 'Connection error. Is the server running?';
    }
  }

  /// Login
  static Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveSession(data);
        return null;
      }
      final data = jsonDecode(response.body);
      return data['detail'] ?? 'Login failed.';
    } catch (e) {
      return 'Connection error. Is the server running?';
    }
  }

  /// Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_patientIdKey);
  }

  /// Save session data after login/register
  static Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, data['token'] ?? '');
    await prefs.setString(_userIdKey, data['user_id'] ?? '');
    await prefs.setString(_emailKey, data['email'] ?? '');
    if (data['patient_id'] != null) {
      await prefs.setString(_patientIdKey, data['patient_id']);
    }
  }
}
