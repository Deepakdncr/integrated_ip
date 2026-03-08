import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';

/// Prescription OCR screen – scan prescription image, extract medicines,
/// and save as reminders with IoT announcement config.
class PrescriptionOcrScreen extends StatefulWidget {
  const PrescriptionOcrScreen({super.key});

  @override
  State<PrescriptionOcrScreen> createState() => _PrescriptionOcrScreenState();
}

class _PrescriptionOcrScreenState extends State<PrescriptionOcrScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _parsedMedicines = [];
  String? _patientId;

  @override
  void initState() {
    super.initState();
    _loadPatient();
  }

  Future<void> _loadPatient() async {
    _patientId = await AuthService.getPatientId();
  }

  Future<void> _scanPrescription() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Upload Prescription',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _isLoading = true;
        _parsedMedicines = [];
      });

      final bytes = await image.readAsBytes();
      final data = await ApiService.ocrPrescription(bytes, image.name);

      if (mounted) {
        setState(() {
          _parsedMedicines = data;
          _isLoading = false;
        });

        if (data.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${data.length} medicines!'),
              backgroundColor: CareSoulTheme.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not extract medicines. Please upload a clear image again.'),
              backgroundColor: CareSoulTheme.error,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveAsReminders() async {
    if (_parsedMedicines.isEmpty || _patientId == null) return;

    setState(() => _isLoading = true);

    bool allSuccess = true;
    for (var med in _parsedMedicines) {
      final timeStr =
          (med['time_of_day'] as String?)?.split(',').first.trim() ?? '08:00';
      final success = await ApiService.createReminder({
        'patient_id': _patientId,
        'medicine_name': med['medicine_name'] ?? 'Unknown',
        'dosage': med['dosage'] ?? '',
        'frequency': med['frequency'] ?? 'Daily',
        'time_of_day': timeStr,
        'food_instruction': 'Anytime',
        'repeat_count': 2,
        'repeat_interval_minutes': 5,
      });
      if (!success) allSuccess = false;
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (allSuccess) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CareSoulTheme.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: CareSoulTheme.success, size: 56),
                ),
                const SizedBox(height: 20),
                const Text('Saved!',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  'All medicines added as reminders.\nDevice will announce them at scheduled times.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: CareSoulTheme.textSecondary),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: CareSoulTheme.success,
                      minimumSize: const Size(180, 48)),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Some saves failed'),
            backgroundColor: CareSoulTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Prescription'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Processing prescription...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Scan Button ──
                  Container(
                    decoration: CareSoulTheme.cardDecoration,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2563EB).withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.document_scanner_rounded,
                              size: 48, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Upload Prescription',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'AI will extract medicine names,\ndosages, and schedules',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, color: CareSoulTheme.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _scanPrescription,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Select Image'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            minimumSize: const Size(200, 50),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_parsedMedicines.isNotEmpty) ...[
                    // ── Results ──
                    Row(
                      children: [
                        const Icon(Icons.medication_rounded,
                            color: CareSoulTheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Found ${_parsedMedicines.length} Medicines',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ...List.generate(
                      _parsedMedicines.length,
                      (index) {
                        final med = _parsedMedicines[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: CareSoulTheme.primary
                                    .withValues(alpha: 0.15)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: CareSoulTheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.medication_rounded,
                                  color: CareSoulTheme.primary),
                            ),
                            title: Text(
                              med['medicine_name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 17),
                            ),
                            subtitle: Text(
                              '${med['dosage']} • ${med['frequency']}\nTime: ${med['time_of_day']}',
                              style: const TextStyle(fontSize: 14, height: 1.4),
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saveAsReminders,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save All as Reminders'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
    );
  }
}
