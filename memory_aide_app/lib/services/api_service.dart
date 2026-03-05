import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

/// Unified API service for all non-auth REST calls.
class ApiService {
  // ============ PATIENT PROFILE ============

  static Future<Map<String, dynamic>?> getPatient(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.patientUrl(userId)),
        headers: await AuthService.authHeaders(),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('getPatient error: $e');
    }
    return null;
  }

  static Future<bool> updatePatient(
      String userId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.patientUrl(userId)),
        headers: await AuthService.authHeaders(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('updatePatient error: $e');
      return false;
    }
  }

  static Future<String?> uploadPatientPhoto(
      String userId, List<int> bytes, String filename) async {
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse(ApiConfig.patientPhotoUrl(userId)));
      final token = await AuthService.getToken();
      request.headers['Authorization'] = 'Bearer ${token ?? ''}';
      request.files
          .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final response = await request.send();
      if (response.statusCode == 200) {
        final body = jsonDecode(await response.stream.bytesToString());
        return body['photo_url'];
      }
    } catch (e) {
      debugPrint('uploadPatientPhoto error: $e');
    }
    return null;
  }

  // ============ OCR ============

  static Future<List<Map<String, dynamic>>> ocrPrescription(
      List<int> bytes, String filename) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse(ApiConfig.ocrUrl));
      final token = await AuthService.getToken();
      request.headers['Authorization'] = 'Bearer ${token ?? ''}';
      request.files
          .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final response = await request.send();
      if (response.statusCode == 200) {
        final body = jsonDecode(await response.stream.bytesToString());
        return List<Map<String, dynamic>>.from(body['medicines'] ?? []);
      }
    } catch (e) {
      debugPrint('ocrPrescription error: $e');
    }
    return [];
  }

  // ============ REMINDERS ============

  static Future<List<Map<String, dynamic>>> getReminders(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.remindersUrl(userId)),
        headers: await AuthService.authHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('getReminders error: $e');
    }
    return [];
  }

  static Future<bool> createReminder(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.reminderCreateUrl),
        headers: await AuthService.authHeaders(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('createReminder error: $e');
      return false;
    }
  }

  static Future<bool> updateReminder(
      String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.reminderUrl(id)),
        headers: await AuthService.authHeaders(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('updateReminder error: $e');
      return false;
    }
  }

  static Future<bool> deleteReminder(String id) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.reminderUrl(id)),
        headers: await AuthService.authHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('deleteReminder error: $e');
      return false;
    }
  }

  // ============ HABITS ============

  static Future<List<Map<String, dynamic>>> getHabits(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.habitsUrl(userId)),
        headers: await AuthService.authHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('getHabits error: $e');
    }
    return [];
  }

  static Future<bool> createHabit(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.habitCreateUrl),
        headers: await AuthService.authHeaders(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('createHabit error: $e');
      return false;
    }
  }

  static Future<bool> updateHabit(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.habitUrl(id)),
        headers: await AuthService.authHeaders(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('updateHabit error: $e');
      return false;
    }
  }

  static Future<bool> deleteHabit(String id) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.habitUrl(id)),
        headers: await AuthService.authHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('deleteHabit error: $e');
      return false;
    }
  }

  // ============ VOICES ============

  static Future<List<Map<String, dynamic>>> getVoices(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.voicesUrl(userId)),
        headers: await AuthService.authHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('getVoices error: $e');
    }
    return [];
  }

  static Future<bool> uploadVoice(
      List<int> bytes, String filename, String name) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse(ApiConfig.voiceUploadUrl));
      final token = await AuthService.getToken();
      request.headers['Authorization'] = 'Bearer ${token ?? ''}';
      request.fields['name'] = name;
      request.files
          .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('uploadVoice error: $e');
      return false;
    }
  }

  static Future<bool> deleteVoice(String id) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.voiceUrl(id)),
        headers: await AuthService.authHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('deleteVoice error: $e');
      return false;
    }
  }

  // ============ MUSIC ============

  static Future<List<Map<String, dynamic>>> getMusic(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.musicListUrl(userId)),
        headers: await AuthService.authHeaders(),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('getMusic error: $e');
    }
    return [];
  }

  static Future<bool> uploadMusic(List<int> bytes, String filename,
      String title, String patientId, String time) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse(ApiConfig.musicUploadUrl));
      final token = await AuthService.getToken();
      request.headers['Authorization'] = 'Bearer ${token ?? ''}';
      request.fields['title'] = title;
      request.fields['patient_id'] = patientId;
      request.fields['scheduled_time'] = time;
      request.files
          .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('uploadMusic error: $e');
      return false;
    }
  }

  static Future<bool> updateMusic(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.musicUrl(id)),
        headers: await AuthService.authHeaders(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('updateMusic error: $e');
      return false;
    }
  }

  static Future<bool> deleteMusic(String id) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.musicUrl(id)),
        headers: await AuthService.authHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('deleteMusic error: $e');
      return false;
    }
  }

  // ============ DEVICE ============

  static Future<Map<String, dynamic>?> getDeviceStatus(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.deviceUrl(userId)),
        headers: await AuthService.authHeaders(),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('getDeviceStatus error: $e');
    }
    return null;
  }

  static Future<bool> syncDevice(String userId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.deviceSyncUrl(userId)),
        headers: await AuthService.authHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('syncDevice error: $e');
      return false;
    }
  }

  // ============ SETTINGS ============

  static Future<Map<String, dynamic>?> getSettings(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.settingsUrl(userId)),
        headers: await AuthService.authHeaders(),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('getSettings error: $e');
    }
    return null;
  }

  static Future<bool> updateSettings(
      String userId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.settingsUrl(userId)),
        headers: await AuthService.authHeaders(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('updateSettings error: $e');
      return false;
    }
  }
}
