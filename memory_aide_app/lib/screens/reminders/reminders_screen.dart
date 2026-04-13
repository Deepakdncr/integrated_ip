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
    _patientId = 'test_user'; // Always use test_user for ESP32 integration

    final data = await ApiService.getReminders('test_user');
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
            SnackBar(
              content: const Text('Medicine removed'),
              backgroundColor: CareSoulTheme.success,
              action: SnackBarAction(
                label: 'UNDO',
                textColor: Colors.white,
                onPressed: () {
                  // TODO: Implement undo if needed
                },
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteAllReminders() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Reminders?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('This will permanently delete all medicine reminders. Are you sure?',
            style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: CareSoulTheme.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteAllReminders('test_user');
      if (success) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All reminders cleared'),
              backgroundColor: CareSoulTheme.success,
            ),
          );
        }
      }
    }
  }

  void _editReminder(Map<String, dynamic> r) {
    final nameCtrl = TextEditingController(text: r['medicine_name'] ?? '');
    final dosageCtrl = TextEditingController(text: r['dosage'] ?? '');
    final durationCtrl = TextEditingController(text: r['duration_days'] ?? '');
    final timeStr = r['time_of_day'] ?? '08:00';
    int hour = int.tryParse(timeStr.split(':')[0]) ?? 8;
    int minute = int.tryParse(timeStr.split(':')[1]) ?? 0;
    TimeOfDay selectedTime = TimeOfDay(hour: hour, minute: minute);
    String foodInstruction = r['food_instruction'] ?? 'Anytime';
    final daysRaw = r['days_of_week'] ?? 'everyday';
    bool isEveryday = daysRaw == 'everyday';
    Set<String> selectedDays = isEveryday ? {} : daysRaw.toString().split(',').toSet();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: CareSoulTheme.primary, size: 28),
              SizedBox(width: 10),
              Text('Edit Medicine', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(labelText: 'Medicine Name', prefixIcon: Icon(Icons.medication_outlined, size: 22))),
                const SizedBox(height: 16),
                TextField(controller: dosageCtrl, style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(labelText: 'Dosage', prefixIcon: Icon(Icons.science_outlined, size: 22))),
                const SizedBox(height: 16),
                TextField(controller: durationCtrl, style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(labelText: 'Duration (Days)', prefixIcon: Icon(Icons.calendar_today_outlined, size: 22))),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: selectedTime);
                    if (t != null) setDialogState(() => selectedTime = t);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Reminder Time', prefixIcon: Icon(Icons.schedule_rounded, size: 22)),
                    child: Text(selectedTime.format(context), style: const TextStyle(fontSize: 17)),
                  ),
                ),
                const SizedBox(height: 16),
                _DaysSelector(isEveryday: isEveryday, selectedDays: selectedDays, days: days,
                  onChanged: (everyday, d) { setDialogState(() { isEveryday = everyday; selectedDays = d; }); }),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Food Instruction', style: TextStyle(fontSize: 14, color: CareSoulTheme.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Before Food', label: Text('Before')),
                        ButtonSegment(value: 'Anytime', label: Text('Anytime')),
                        ButtonSegment(value: 'After Food', label: Text('After')),
                      ],
                      selected: {foodInstruction},
                      onSelectionChanged: (s) => setDialogState(() => foodInstruction = s.first),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(
                onPressed: () async {
                  final t = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                  final d = isEveryday ? 'everyday' : (selectedDays.isEmpty ? 'everyday' : selectedDays.join(','));
                  final success = await ApiService.updateReminder(r['id'], {
                    'medicine_name': nameCtrl.text.trim(),
                    'dosage': dosageCtrl.text.trim(),
                    'time_of_day': t,
                    'food_instruction': foodInstruction,
                    'days_of_week': d,
                    'duration_days': durationCtrl.text.trim(),
                  });
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  if (success) { _loadData(); ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Medicine updated!'), backgroundColor: CareSoulTheme.success)); }
                },
                icon: const Icon(Icons.save_rounded, size: 20),
                label: const Text('Save'),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final repeatCountCtrl = TextEditingController(text: '2');
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    String foodInstruction = 'Anytime';
    bool isEveryday = true;
    Set<String> selectedDays = {};

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
                TextField(
                  controller: durationCtrl,
                  style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(
                    labelText: 'Duration (Days)',
                    hintText: 'e.g. 7 days',
                    prefixIcon: Icon(Icons.calendar_today_outlined, size: 22),
                  ),
                ),
                const SizedBox(height: 16),
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
                _DaysSelector(
                  isEveryday: isEveryday,
                  selectedDays: selectedDays,
                  days: days,
                  onChanged: (everyday, days) {
                    setDialogState(() {
                      isEveryday = everyday;
                      selectedDays = days;
                    });
                  },
                ),
                const SizedBox(height: 16),
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
                TextField(
                  controller: repeatCountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(
                    labelText: 'Repeat Count',
                    hintText: 'e.g. 2',
                    prefixIcon: Icon(Icons.repeat_rounded, size: 22),
                    helperText: 'How many times device will announce',
                  ),
                ),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CareSoulTheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: CareSoulTheme.primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_up_rounded,
                            color: CareSoulTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Device will announce medicine name + dosage ${repeatCountCtrl.text.isEmpty ? 2 : (int.tryParse(repeatCountCtrl.text) ?? 2)} time(s) with 5-min interval',
                            style: const TextStyle(
                                fontSize: 12,
                                color: CareSoulTheme.primary,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter medicine name')),
                        );
                        return;
                      }
                      final timeStr =
                          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                      final daysStr = isEveryday
                          ? 'everyday'
                          : (selectedDays.isEmpty
                              ? 'everyday'
                              : selectedDays.join(','));
                      final success = await ApiService.createReminder({
                        'patient_id': 'test_user',
                        'medicine_name': nameCtrl.text.trim(),
                        'dosage': dosageCtrl.text.trim(),
                        'frequency': isEveryday ? 'Daily' : daysStr,
                        'time_of_day': timeStr,
                        'food_instruction': foodInstruction,
                        'repeat_count': int.tryParse(repeatCountCtrl.text.trim()) ?? 2,
                        'repeat_interval_minutes': 5,
                        'days_of_week': daysStr,
                        'duration_days': durationCtrl.text.trim(),
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
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Reminders'),
        actions: [
          if (_reminders.isNotEmpty)
            IconButton(
              onPressed: _deleteAllReminders,
              icon: const Icon(Icons.delete_sweep_rounded, color: CareSoulTheme.error),
              tooltip: 'Clear All',
            ),
        ],
      ),
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
                      final id = r['id'];
                      final isActive = r['is_active'] ?? true;
                      final days = r['days_of_week'] ?? 'everyday';
                      
                      return Dismissible(
                        key: Key(id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) => _deleteReminder(id),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text('Delete Medicine'),
                              content: Text('Remove ${r['medicine_name']}?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(backgroundColor: CareSoulTheme.error),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ?? false;
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: CareSoulTheme.error,
                            borderRadius: BorderRadius.circular(CareSoulTheme.radiusLg),
                          ),
                          child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 30),
                        ),
                        child: Container(
                          width: double.infinity,
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
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today_rounded,
                                              size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            days == 'everyday'
                                                ? '📅 Everyday'
                                                : '📅 $days',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if ((r['duration_days'] ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.date_range_rounded,
                                                size: 14, color: Colors.grey[500]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'For: ${r['duration_days']}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Switch(
                                      value: isActive,
                                      onChanged: (val) =>
                                          _toggleActive(r['id'], val),
                                      activeColor: CareSoulTheme.primary,
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _editReminder(r);
                                        } else if (value == 'delete') {
                                          _deleteReminder(id);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(children: [
                                            Icon(Icons.edit_outlined, color: Colors.blue[600], size: 20),
                                            const SizedBox(width: 12),
                                            const Text('Edit'),
                                          ]),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(children: [
                                            Icon(Icons.delete_outline_rounded, color: Colors.red[600], size: 20),
                                            const SizedBox(width: 12),
                                            const Text('Delete', style: TextStyle(color: Colors.red)),
                                          ]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _DaysSelector extends StatelessWidget {
  final bool isEveryday;
  final Set<String> selectedDays;
  final List<String> days;
  final void Function(bool everyday, Set<String> days) onChanged;

  const _DaysSelector({
    required this.isEveryday,
    required this.selectedDays,
    required this.days,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Repeat Days',
          style: TextStyle(
            fontSize: 14,
            color: CareSoulTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => onChanged(!isEveryday, isEveryday ? {} : selectedDays),
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Checkbox(
                value: isEveryday,
                activeColor: CareSoulTheme.primary,
                onChanged: (v) => onChanged(v ?? true, {}),
              ),
              const Text('Everyday',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (!isEveryday) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: days.map((d) {
              final selected = selectedDays.contains(d);
              return FilterChip(
                label: Text(d,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : CareSoulTheme.textSecondary)),
                selected: selected,
                selectedColor: CareSoulTheme.primary,
                checkmarkColor: Colors.white,
                backgroundColor: Colors.grey[100],
                onSelected: (v) {
                  final newDays = Set<String>.from(selectedDays);
                  if (v) {
                    newDays.add(d);
                  } else {
                    newDays.remove(d);
                  }
                  onChanged(false, newDays);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
