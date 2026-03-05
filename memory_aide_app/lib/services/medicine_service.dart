import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MedicineService {
  // Use 10.0.2.2 for Android emulator, localhost for web/iOS
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    // For Android emulator, 10.0.2.2 maps to host machine's localhost
    return 'http://10.0.2.2:8000';
  }

  // Add a medicine
  Future<String?> addMedicine({
    required String userId,
    required String name,
    required String dosage,
    required String frequency,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add-medicine'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'name': name,
          'dosage': dosage,
          'frequency': frequency,
        }),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Failed to add medicine.';
      }
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  // Get all medicines for a user
  Future<List<Map<String, dynamic>>> getMedicines(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/medicines/$userId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching medicines: $e');
      return [];
    }
  }

  // Delete a medicine
  Future<String?> deleteMedicine(String medicineId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/medicines/$medicineId'),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Failed to delete medicine.';
      }
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  // Update a medicine
  Future<String?> updateMedicine({
    required String medicineId,
    String? name,
    String? dosage,
    String? frequency,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (dosage != null) body['dosage'] = dosage;
      if (frequency != null) body['frequency'] = frequency;

      final response = await http.put(
        Uri.parse('$baseUrl/medicines/$medicineId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Failed to update medicine.';
      }
    } catch (e) {
      return 'Connection error: $e';
    }
  }
}
