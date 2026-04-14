import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../../widgets/empty_state.dart';

/// Habit routines screen – CRUD for daily routines.
/// Routines trigger audio announcements on the IoT device.
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

  // Preset habit suggestions
  static const List<Map<String, dynamic>> _presets = [
    {'title': 'Morning Walk', 'time': '08:00', 'duration': 15, 'icon': '🚶'},
    {'title': 'Breakfast Time', 'time': '09:00', 'duration': 0, 'icon': '🍽️'},
    {'title': 'Afternoon Nap', 'time': '13:00', 'duration': 30, 'icon': '😴'},
    {'title': 'Evening Prayer', 'time': '18:00', 'duration': 15, 'icon': '🙏'},
    {'title': 'Dinner Time', 'time': '20:00', 'duration': 0, 'icon': '🍛'},
    {'title': 'Sleep Time', 'time': '22:00', 'duration': 0, 'icon': '🌙'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    // _userId = await AuthService.getUserId();
    // _patientId = await AuthService.getPatientId();
    _userId = 'test_user'; // Hardcoded for ESP32 integration
    _patientId = 'test_user';

    final data = await ApiService.getHabits('test_user');
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

  Future<void> _deleteHabit(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Routine',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Remove this habit routine?',
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
      final success = await ApiService.deleteHabit(id);
      if (success) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Habit removed'),
              backgroundColor: CareSoulTheme.success,
            ),
          );
        }
      }
    }
  }

  void _editHabit(Map<String, dynamic> h) {
    final titleCtrl = TextEditingController(text: h['title'] ?? '');
    final durationCtrl = TextEditingController(text: (h['duration_minutes'] ?? 0).toString());
    final timeStr = h['scheduled_time'] ?? '09:00';
    int hour = int.tryParse(timeStr.split(':')[0]) ?? 9;
    int minute = int.tryParse(timeStr.split(':')[1]) ?? 0;
    TimeOfDay selectedTime = TimeOfDay(hour: hour, minute: minute);
    final daysRaw = h['days_of_week'] ?? 'everyday';
    bool isEveryday = daysRaw == 'everyday';
    Set<String> selectedDays = isEveryday ? {} : daysRaw.toString().split(',').toSet();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.edit_rounded, color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 10),
            Text('Edit Habit', style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, style: const TextStyle(fontSize: 17),
                decoration: const InputDecoration(labelText: 'Routine Title', prefixIcon: Icon(Icons.edit_outlined, size: 22))),
              const SizedBox(height: 16),
              TextField(controller: durationCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 17),
                decoration: const InputDecoration(labelText: 'Duration (minutes)', prefixIcon: Icon(Icons.timer_outlined, size: 22))),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: selectedTime);
                  if (t != null) setDialogState(() => selectedTime = t);
                },
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Scheduled Time', prefixIcon: Icon(Icons.schedule_rounded, size: 22)),
                  child: Text(selectedTime.format(context), style: const TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(height: 12),
              _HabitDaysSelector(isEveryday: isEveryday, selectedDays: selectedDays, days: days,
                onChanged: (everyday, d) { setDialogState(() { isEveryday = everyday; selectedDays = d; }); }),
            ]),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(
                onPressed: () async {
                  final t = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                  final d = isEveryday ? 'everyday' : (selectedDays.isEmpty ? 'everyday' : selectedDays.join(','));
                  final success = await ApiService.updateHabit(h['id'], {
                    'title': titleCtrl.text.trim(),
                    'duration_minutes': int.tryParse(durationCtrl.text.trim()) ?? 0,
                    'scheduled_time': t,
                    'days_of_week': d,
                  });
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  if (success) { _loadData(); ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Habit updated!'), backgroundColor: CareSoulTheme.success)); }
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Save'),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(
      {String? presetTitle, String? presetTime, int? presetDuration}) {
    final titleCtrl = TextEditingController(text: presetTitle ?? '');
    final durationCtrl =
        TextEditingController(text: (presetDuration ?? 30).toString());
    final repeatCountCtrl = TextEditingController(text: '2');

    // Parse preset time or default to 09:00
    int hour = 9, minute = 0;
    if (presetTime != null && presetTime.contains(':')) {
      hour = int.tryParse(presetTime.split(':')[0]) ?? 9;
      minute = int.tryParse(presetTime.split(':')[1]) ?? 0;
    }
    TimeOfDay selectedTime = TimeOfDay(hour: hour, minute: minute);
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
              Icon(Icons.directions_walk_rounded,
                  color: Color(0xFFF59E0B), size: 28),
              SizedBox(width: 10),
              Text('Add Habit Routine',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(
                    labelText: 'Routine Title',
                    hintText: 'e.g. Morning Walk',
                    prefixIcon: Icon(Icons.edit_outlined, size: 22),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    hintText: '0 for no duration',
                    prefixIcon: Icon(Icons.timer_outlined, size: 22),
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
                      labelText: 'Scheduled Time',
                      prefixIcon: Icon(Icons.schedule_rounded, size: 22),
                    ),
                    child: Text(
                      selectedTime.format(context),
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Days of week
                _HabitDaysSelector(
                  isEveryday: isEveryday,
                  selectedDays: selectedDays,
                  days: days,
                  onChanged: (everyday, d) {
                    setDialogState(() {
                      isEveryday = everyday;
                      selectedDays = d;
                    });
                  },
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.volume_up_rounded,
                          color: Color(0xFFF59E0B), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'IoT device will announce this routine at scheduled time',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
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
                  child: FilledButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty || _patientId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter routine title')),
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
                      final success = await ApiService.createHabit({
                        'patient_id': _patientId,
                        'title': titleCtrl.text.trim(),
                        'duration_minutes':
                            int.tryParse(durationCtrl.text.trim()) ?? 0,
                        'scheduled_time': timeStr,
                        'days_of_week': daysStr,
                        'repeat_count': int.tryParse(repeatCountCtrl.text.trim()) ?? 2,
                      });
                      if (!context.mounted) return;
                      Navigator.pop(ctx);
                      if (success) {
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Routine added!'),
                            backgroundColor: CareSoulTheme.success,
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _habitIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('walk')) return Icons.directions_walk_rounded;
    if (t.contains('breakfast') ||
        t.contains('dinner') ||
        t.contains('lunch')) {
      return Icons.restaurant_rounded;
    }
    if (t.contains('nap') || t.contains('sleep')) return Icons.bedtime_rounded;
    if (t.contains('prayer') || t.contains('meditat')) {
      return Icons.self_improvement_rounded;
    }
    if (t.contains('exercise') || t.contains('yoga')) {
      return Icons.fitness_center_rounded;
    }
    if (t.contains('water') || t.contains('drink')) {
      return Icons.water_drop_rounded;
    }
    return Icons.event_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Routines'),
        backgroundColor: const Color(0xFFF59E0B),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: const Color(0xFFF59E0B),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Routine',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      EmptyStateWidget(
                        icon: Icons.directions_walk_rounded,
                        title: 'No Habit Routines',
                        subtitle: 'Add daily routines for the patient.',
                        color: const Color(0xFFF59E0B),
                      ),
                      // Quick presets
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick Add:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: CareSoulTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _presets
                                  .map((p) => ActionChip(
                                        avatar: Text(p['icon'],
                                            style:
                                                const TextStyle(fontSize: 16)),
                                        label: Text(p['title'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        onPressed: () => _showAddDialog(
                                          presetTitle: p['title'],
                                          presetTime: p['time'],
                                          presetDuration: p['duration'],
                                        ),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _habits.length,
                    itemBuilder: (context, index) {
                      final h = _habits[index];
                      final isActive = h['is_active'] ?? true;
                      final duration = h['duration_minutes'] ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(CareSoulTheme.radiusLg),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: isActive ? 0.08 : 0.03),
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
                                          ? const Color(0xFFF59E0B)
                                          : Colors.grey)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _habitIcon(h['title'] ?? ''),
                                  color: isActive
                                      ? const Color(0xFFF59E0B)
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
                                      h['title'] ?? '',
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
                                        Icon(Icons.schedule_rounded,
                                            size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          h['scheduled_time'] ?? '',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (duration > 0) ...[
                                          const SizedBox(width: 12),
                                          Icon(Icons.timer_outlined,
                                              size: 14,
                                              color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$duration min',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      () {
                                        final d = h['days_of_week'] ?? 'everyday';
                                        return d == 'everyday' ? '📅 Everyday' : '📅 $d';
                                      }(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Switch(
                                    value: isActive,
                                    activeThumbColor: const Color(0xFFF59E0B),
                                    onChanged: (val) =>
                                        _toggleActive(h['id'], val),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editHabit(h);
                                      } else if (value == 'delete') {
                                        _deleteHabit(h['id']);
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
                      );
                    },
                  ),
                ),
    );
  }
}

/// Reusable days-of-week selector (copied pattern from reminders_screen).
class _HabitDaysSelector extends StatelessWidget {
  final bool isEveryday;
  final Set<String> selectedDays;
  final List<String> days;
  final void Function(bool everyday, Set<String> days) onChanged;

  const _HabitDaysSelector({
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
            color: Color(0xFF78716C),
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
                activeColor: const Color(0xFFF59E0B),
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
                        color: selected ? Colors.white : Colors.grey[600])),
                selected: selected,
                selectedColor: const Color(0xFFF59E0B),
                checkmarkColor: Colors.white,
                backgroundColor: Colors.grey[100],
                onSelected: (v) {
                  final nd = Set<String>.from(selectedDays);
                  if (v) nd.add(d); else nd.remove(d);
                  onChanged(false, nd);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
