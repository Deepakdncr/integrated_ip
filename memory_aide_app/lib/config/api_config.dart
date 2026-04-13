// API configuration for CareSoul app.
// Change [baseUrl] when deploying to production.

class ApiConfig {
  static String get baseUrl {
    // ✅ Production: Render backend URL
    // Replace YOUR_RENDER_URL after deploying backend to Render
    const String productionUrl = 'https://YOUR_RENDER_URL.onrender.com';
    return productionUrl;
  }

  // Auth
  static String get loginUrl => '$baseUrl/login';
  static String get registerRequestOtpUrl => '$baseUrl/request-register-otp';
  static String get registerVerifyUrl => '$baseUrl/verify-register';
  static String get forgotPasswordOtpUrl =>
      '$baseUrl/forgot-password/request-otp';
  static String get resetPasswordUrl => '$baseUrl/forgot-password/reset';

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
  static String remindersAllUrl(String userId) => '$baseUrl/reminders/all/$userId';

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

  // SOS
  static String sosStopUrl(String deviceId) => '$baseUrl/sos/stop/$deviceId';

  // File URL helper
  static String fileUrl(String path) => '$baseUrl$path';
}
