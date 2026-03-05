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
    return prefs.getString(_patientIdKey);
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

  /// Register
  static Future<String?> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
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
