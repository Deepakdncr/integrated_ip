import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<Map<String, dynamic>> _habits = [];
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

    final data = await ApiService.getHabits(_userId!);
    if (mounted) {
      setState(() {
        _habits = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleActive(String id, bool val) async {
    final success = await ApiService.updateHabit(id, {'is_active': val});
    if (success) _loadData();
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '30');
    final timeCtrl = TextEditingController(text: '09:00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Habit Routine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title (e.g. Morning Walk)')),
            const SizedBox(height: 12),
            TextField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Duration (Mins)')),
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
              if (titleCtrl.text.isEmpty || _patientId == null) return;
              await ApiService.createHabit({
                'patient_id': _patientId,
                'title': titleCtrl.text,
                'duration_minutes': int.tryParse(durationCtrl.text) ?? 0,
                'scheduled_time': timeCtrl.text,
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
      appBar: AppBar(title: const Text('Habit Routines')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? const Center(
                  child: Text('No habits added.',
                      style: TextStyle(fontSize: 18, color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _habits.length,
                    itemBuilder: (context, index) {
                      final h = _habits[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.directions_walk,
                                  color: Colors.white)),
                          title: Text(h['title'],
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              'Time: ${h['scheduled_time']} • ${h['duration_minutes']} mins',
                              style: const TextStyle(fontSize: 16)),
                          trailing: Switch(
                            value: h['is_active'] ?? true,
                            activeThumbColor: Colors.orange,
                            onChanged: (val) => _toggleActive(h['id'], val),
                          ),
                          onLongPress: () async {
                            await ApiService.deleteHabit(h['id']);
                            _loadData();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
