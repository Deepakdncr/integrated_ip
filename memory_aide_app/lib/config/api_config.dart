// API configuration for CareSoul app.
// Change [baseUrl] when deploying to production.
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    // Android emulator maps 10.0.2.2 to host localhost
    return 'http://10.0.2.2:8000';
  }

  // Auth
  static String get loginUrl => '$baseUrl/login';
  static String get registerUrl => '$baseUrl/register';

  // Patient
  static String patientUrl(String userId) => '$baseUrl/patient/$userId';
  static String patientPhotoUrl(String userId) =>
      '$baseUrl/patient/$userId/photo';

  // OCR
  static String get ocrUrl => '$baseUrl/ocr/prescription';

  // Reminders
  static String remindersUrl(String userId) => '$baseUrl/reminders/$userId';
  static String get reminderCreateUrl => '$baseUrl/reminders';
  static String reminderUrl(String id) => '$baseUrl/reminders/$id';

  // Habits
  static String habitsUrl(String userId) => '$baseUrl/habits/$userId';
  static String get habitCreateUrl => '$baseUrl/habits';
  static String habitUrl(String id) => '$baseUrl/habits/$id';

  // Voice
  static String voicesUrl(String userId) => '$baseUrl/voices/$userId';
  static String get voiceUploadUrl => '$baseUrl/voices/upload';
  static String voiceUrl(String id) => '$baseUrl/voices/$id';

  // Music
  static String musicListUrl(String userId) => '$baseUrl/music/$userId';
  static String get musicUploadUrl => '$baseUrl/music/upload';
  static String musicUrl(String id) => '$baseUrl/music/$id';

  // Device
  static String deviceUrl(String userId) => '$baseUrl/device/$userId';
  static String deviceSyncUrl(String userId) => '$baseUrl/device/sync/$userId';

  // Settings
  static String settingsUrl(String userId) => '$baseUrl/settings/$userId';

  // File URL helper
  static String fileUrl(String path) => '$baseUrl$path';
}
