import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../../widgets/empty_state.dart';

/// Medicine reminders screen – CRUD for medication reminders.
/// Sends repeat_count=2, repeat_interval_minutes=5 for IoT announcements.
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

  Future<void> _deleteReminder(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Medicine',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Remove this medicine reminder?',
            style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: CareSoulTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteReminder(id);
      if (success) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Medicine removed'),
              backgroundColor: CareSoulTheme.success,
            ),
          );
        }
      }
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    String foodInstruction = 'Anytime';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.medication_rounded,
                  color: CareSoulTheme.primary, size: 28),
              SizedBox(width: 10),
              Text('Add Medicine',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name',
                    hintText: 'e.g. Paracetamol',
                    prefixIcon: Icon(Icons.medication_outlined, size: 22),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dosageCtrl,
                  style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(
                    labelText: 'Dosage',
                    hintText: 'e.g. 500mg',
                    prefixIcon: Icon(Icons.science_outlined, size: 22),
                  ),
                ),
                const SizedBox(height: 16),
                // Time picker
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (t != null) {
                      setDialogState(() => selectedTime = t);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Reminder Time',
                      prefixIcon: Icon(Icons.schedule_rounded, size: 22),
                    ),
                    child: Text(
                      selectedTime.format(context),
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Food Instruction Segmented Button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Food Instruction',
                      style: TextStyle(
                        fontSize: 14,
                        color: CareSoulTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'Before Food', label: Text('Before')),
                        ButtonSegment(value: 'Anytime', label: Text('Anytime')),
                        ButtonSegment(
                            value: 'After Food', label: Text('After')),
                      ],
                      selected: {foodInstruction},
                      onSelectionChanged: (Set<String> newSelection) {
                        setDialogState(() {
                          foodInstruction = newSelection.first;
                        });
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return CareSoulTheme.primary;
                            }
                            return Colors.transparent;
                          },
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white;
                            }
                            return CareSoulTheme.textSecondary;
                          },
                        ),
                        textStyle: WidgetStateProperty.all(
                            const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Announcement info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CareSoulTheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: CareSoulTheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.volume_up_rounded,
                          color: CareSoulTheme.primary, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Device will announce medicine name + dosage twice with 5-min interval',
                          style: TextStyle(
                              fontSize: 12,
                              color: CareSoulTheme.primary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || _patientId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter medicine name')),
                  );
                  return;
                }
                final timeStr =
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                final success = await ApiService.createReminder({
                  'patient_id': _patientId,
                  'medicine_name': nameCtrl.text.trim(),
                  'dosage': dosageCtrl.text.trim(),
                  'frequency': 'Daily',
                  'time_of_day': timeStr,
                  'food_instruction': foodInstruction,
                  'repeat_count': 2,
                  'repeat_interval_minutes': 5,
                });
                if (!context.mounted) return;
                Navigator.pop(ctx);
                if (success) {
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Medicine added successfully!'),
                      backgroundColor: CareSoulTheme.success,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Medicine'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine Reminders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Medicine',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.medication_rounded,
                  title: 'No Medicines Added',
                  subtitle:
                      'Tap the button below to add\nmedicine reminders for the patient.',
                  buttonLabel: 'Add Medicine',
                  onAction: _showAddDialog,
                  color: const Color(0xFF0891B2),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _reminders.length,
                    itemBuilder: (context, index) {
                      final r = _reminders[index];
                      final isActive = r['is_active'] ?? true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(CareSoulTheme.radiusLg),
                          border: Border.all(
                            color: isActive
                                ? CareSoulTheme.primary.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isActive
                                      ? CareSoulTheme.primary
                                      : Colors.grey)
                                  .withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Medicine icon
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (isActive
                                          ? CareSoulTheme.primary
                                          : Colors.grey)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.medication_rounded,
                                  color: isActive
                                      ? CareSoulTheme.primary
                                      : Colors.grey,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r['medicine_name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                        color: isActive
                                            ? CareSoulTheme.textPrimary
                                            : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.science_outlined,
                                            size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          r['dosage'] ?? '',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(Icons.schedule_rounded,
                                            size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          r['time_of_day'] ?? '',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.restaurant_rounded,
                                            size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          r['food_instruction'] ?? 'Anytime',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: CareSoulTheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '🔊 Repeats ${r['repeat_count'] ?? 2}x • ${r['repeat_interval_minutes'] ?? 5} min interval',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Controls
                              Column(
                                children: [
                                  Switch(
                                    value: isActive,
                                    onChanged: (val) =>
                                        _toggleActive(r['id'], val),
                                  ),
                                  GestureDetector(
                                    onTap: () => _deleteReminder(r['id']),
                                    child: Icon(Icons.delete_outline_rounded,
                                        color: Colors.red[300], size: 22),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
