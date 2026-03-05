import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

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
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
        source: ImageSource.gallery); // Can use camera too

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
      }
    }
  }

  Future<void> _saveAsReminders() async {
    if (_parsedMedicines.isEmpty || _patientId == null) return;

    setState(() => _isLoading = true);

    bool allSuccess = true;
    for (var med in _parsedMedicines) {
      final success = await ApiService.createReminder({
        'patient_id': _patientId,
        'medicine_name': med['medicine_name'] ?? 'Unknown',
        'dosage': med['dosage'] ?? '',
        'frequency': med['frequency'] ?? 'Daily',
        'time_of_day': (med['time_of_day'] as String)
            .split(',')
            .first
            .trim(), // Take first time
      });
      if (!success) allSuccess = false;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                allSuccess ? 'Saved to Reminders!' : 'Some saves failed.')),
      );
      if (allSuccess) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Prescription')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _scanPrescription,
                    icon: const Icon(Icons.document_scanner, size: 28),
                    label: const Text('Select Prescription Image'),
                  ),
                  const SizedBox(height: 20),
                  if (_parsedMedicines.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Upload an image to extract medicines automatically via AI.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ),
                    )
                  else ...[
                    const Text('Detected Medicines:',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _parsedMedicines.length,
                        itemBuilder: (context, index) {
                          final med = _parsedMedicines[index];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                  child: Icon(Icons.medication)),
                              title: Text(med['medicine_name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '${med['dosage']} • ${med['frequency']}\nTime: ${med['time_of_day']}'),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saveAsReminders,
                      child: const Text('Save All as Reminders'),
                    )
                  ]
                ],
              ),
            ),
    );
  }
}
