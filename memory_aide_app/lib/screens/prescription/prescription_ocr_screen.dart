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

  /// Opens a dialog to edit the medicine at [index].
  Future<void> _editMedicine(int index) async {
    final med = Map<String, dynamic>.from(_parsedMedicines[index]);

    final nameCtrl =
        TextEditingController(text: med['medicine_name'] ?? '');
    final dosageCtrl =
        TextEditingController(text: med['dosage'] ?? '');
    final frequencyCtrl =
        TextEditingController(text: med['frequency'] ?? '');
    final timeCtrl =
        TextEditingController(text: med['time_of_day'] ?? '08:00');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_rounded,
                  color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Edit Medicine',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Medicine Name',
                  prefixIcon: const Icon(Icons.medication_rounded, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: dosageCtrl,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Dosage',
                  hintText: 'e.g. 500mg, 1 tablet',
                  prefixIcon:
                      const Icon(Icons.science_rounded, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: frequencyCtrl,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Frequency',
                  hintText: 'e.g. Daily, Every 8 hours',
                  prefixIcon:
                      const Icon(Icons.repeat_rounded, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: timeCtrl,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Time of Day',
                  hintText: 'e.g. 08:00, 14:00',
                  prefixIcon:
                      const Icon(Icons.schedule_rounded, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.access_time_rounded,
                        color: Color(0xFF2563EB)),
                    onPressed: () async {
                      // Parse existing time
                      final parts = timeCtrl.text.split(':');
                      final initHour = int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8;
                      final initMin = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay(hour: initHour, minute: initMin),
                      );
                      if (picked != null) {
                        timeCtrl.text =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx, {
                'medicine_name': nameCtrl.text.trim(),
                'dosage': dosageCtrl.text.trim(),
                'frequency': frequencyCtrl.text.trim(),
                'time_of_day': timeCtrl.text.trim(),
              });
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _parsedMedicines[index] = result;
      });
    }
  }

  /// Removes the medicine at [index] with a confirmation.
  void _deleteMedicine(int index) {
    final name = _parsedMedicines[index]['medicine_name'] ?? 'this medicine';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Medicine',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remove "$name" from the list?',
            style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _parsedMedicines.removeAt(index));
            },
            style: FilledButton.styleFrom(backgroundColor: CareSoulTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
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
                    // ── Results Header ──
                    Row(
                      children: [
                        const Icon(Icons.medication_rounded,
                            color: CareSoulTheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Found ${_parsedMedicines.length} Medicines',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the edit icon to correct any details',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[500]),
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Medicine icon
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: CareSoulTheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.medication_rounded,
                                      color: CareSoulTheme.primary),
                                ),
                                const SizedBox(width: 12),
                                // Medicine details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med['medicine_name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 17),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.science_rounded,
                                              size: 14,
                                              color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            med['dosage'] ?? '',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.repeat_rounded,
                                              size: 14,
                                              color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              med['frequency'] ?? '',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700]),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.schedule_rounded,
                                              size: 14,
                                              color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            med['time_of_day'] ?? '',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Action buttons
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Edit button
                                    Material(
                                      color: const Color(0xFF2563EB)
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        onTap: () => _editMedicine(index),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(Icons.edit_rounded,
                                              color: Color(0xFF2563EB),
                                              size: 20),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Delete button
                                    Material(
                                      color: Colors.red.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        onTap: () => _deleteMedicine(index),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(Icons.delete_outline_rounded,
                                              color: Colors.red[400],
                                              size: 20),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
