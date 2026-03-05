import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;
  String? _userId;
  String? _patientId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _userId = await AuthService.getUserId();
    _patientId = await AuthService.getPatientId();
    if (_userId == null) return;

    final data = await ApiService.getReminders(_userId!);
    if (mounted) {
      setState(() {
        _reminders = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleActive(String id, bool val) async {
    final success = await ApiService.updateReminder(id, {'is_active': val});
    if (success) _loadData();
  }

  Future<void> _delete(String id) async {
    final success = await ApiService.deleteReminder(id);
    if (success) _loadData();
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '08:00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Medicine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Name (e.g. Paracetamol)')),
            const SizedBox(height: 12),
            TextField(
                controller: dosageCtrl,
                decoration:
                    const InputDecoration(labelText: 'Dosage (e.g. 500mg)')),
            const SizedBox(height: 12),
            TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(labelText: 'Time (HH:MM)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || _patientId == null) return;
              await ApiService.createReminder({
                'patient_id': _patientId,
                'medicine_name': nameCtrl.text,
                'dosage': dosageCtrl.text,
                'frequency': 'Daily',
                'time_of_day': timeCtrl.text,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? const Center(
                  child: Text('No medicines added.',
                      style: TextStyle(fontSize: 18, color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reminders.length,
                    itemBuilder: (context, index) {
                      final r = _reminders[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(r['medicine_name'],
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${r['dosage']} • Time: ${r['time_of_day']}',
                              style: const TextStyle(fontSize: 16)),
                          trailing: Switch(
                            value: r['is_active'] ?? true,
                            activeThumbImage: null,
                            activeTrackColor:
                                Colors.teal.withValues(alpha: 0.5),
                            activeThumbColor: Colors.teal,
                            onChanged: (val) => _toggleActive(r['id'], val),
                          ),
                          onLongPress: () => _delete(r['id']),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
