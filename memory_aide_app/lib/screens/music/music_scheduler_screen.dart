import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../widgets/empty_state.dart';

/// Music scheduler screen – upload and schedule music for the patient.
/// Works on both web (bytes) and mobile (file path). No auth required.
class MusicSchedulerScreen extends StatefulWidget {
  const MusicSchedulerScreen({super.key});

  @override
  State<MusicSchedulerScreen> createState() => _MusicSchedulerScreenState();
}

class _MusicSchedulerScreenState extends State<MusicSchedulerScreen> {
  List<Map<String, dynamic>> _music = [];
  bool _isLoading = true;
  final String _userId = 'test_user';
  final String _patientId = 'test_user';
  bool _isEverydayDefault = true;
  Set<String> _selectedDaysDefault = {};

  static const _kDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _music = await ApiService.getMusic(_userId);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _uploadMusic() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.audio);

    if (result == null) return;

    final file = result.files.single;

    final titleCtrl = TextEditingController(text: file.name);
    TimeOfDay selectedTime = const TimeOfDay(hour: 17, minute: 0);
    bool isEveryday = true;
    Set<String> selectedDays = {};

    if (!mounted) return;

    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.music_note_rounded,
                  color: Color(0xFFEC4899), size: 28),
              SizedBox(width: 10),
              Text('Schedule Music',
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
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title_rounded, size: 22),
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
                    labelText: 'Play Time',
                    prefixIcon: Icon(Icons.schedule_rounded, size: 22),
                  ),
                  child: Text(
                    selectedTime.format(context),
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MusicDaysSelector(
                isEveryday: isEveryday,
                selectedDays: selectedDays,
                days: _kDays,
                onChanged: (everyday, d) {
                  setDialogState(() {
                    isEveryday = everyday;
                    selectedDays = d;
                  });
                },
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
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.upload_rounded, size: 20),
                    label: const Text('Upload'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (shouldUpload == true) {
      setState(() => _isLoading = true);
      final timeStr =
          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      final daysStr = isEveryday
          ? 'everyday'
          : (selectedDays.isEmpty ? 'everyday' : selectedDays.join(','));

      bool success = false;
      final pickedBytes = file.bytes;
      final pickedPath = file.path;

      if (pickedBytes != null) {
        // Web: use bytes directly
        success = await ApiService.uploadMusic(
            pickedBytes, file.name, titleCtrl.text.trim(), _patientId, timeStr, daysStr);
      } else if (pickedPath != null) {
        // Mobile: use file path
        success = await ApiService.uploadMusicFromFilePath(
            pickedPath, titleCtrl.text.trim(), _patientId, timeStr, daysStr);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Music uploaded and scheduled!'),
              backgroundColor: CareSoulTheme.success,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload failed. Check backend connection.'),
              backgroundColor: CareSoulTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(String id, bool val) async {
    final success = await ApiService.updateMusic(id, {'is_active': val});
    if (success) _loadData();
  }

  Future<void> _deleteMusic(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Music',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Remove this scheduled music?',
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
      final success = await ApiService.deleteMusic(id);
      if (success) _loadData();
    }
  }

  void _editMusic(Map<String, dynamic> m) {
    final titleCtrl = TextEditingController(text: m['title'] ?? '');
    final timeStr = m['scheduled_time'] ?? '17:00';
    int hour = int.tryParse(timeStr.split(':')[0]) ?? 17;
    int minute = int.tryParse(timeStr.split(':')[1]) ?? 0;
    TimeOfDay selectedTime = TimeOfDay(hour: hour, minute: minute);
    final daysRaw = m['days_of_week'] ?? 'everyday';
    bool isEveryday = daysRaw == 'everyday';
    Set<String> selectedDays = isEveryday ? {} : daysRaw.toString().split(',').toSet();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.edit_rounded, color: Color(0xFFEC4899), size: 28),
            SizedBox(width: 10),
            Text('Edit Music', style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, style: const TextStyle(fontSize: 17),
                decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title_rounded, size: 22))),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: selectedTime);
                  if (t != null) setDialogState(() => selectedTime = t);
                },
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Play Time', prefixIcon: Icon(Icons.schedule_rounded, size: 22)),
                  child: Text(selectedTime.format(context), style: const TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(height: 16),
              _MusicDaysSelector(isEveryday: isEveryday, selectedDays: selectedDays, days: _kDays,
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
                  final success = await ApiService.updateMusic(m['id'], {
                    'title': titleCtrl.text.trim(),
                    'scheduled_time': t,
                    'days_of_week': d,
                  });
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  if (success) { _loadData(); ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Music updated!'), backgroundColor: CareSoulTheme.success)); }
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEC4899), padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Save'),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Scheduler'),
        backgroundColor: const Color(0xFFEC4899),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadMusic,
        backgroundColor: const Color(0xFFEC4899),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Music',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _music.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.music_note_rounded,
                  title: 'No Music Scheduled',
                  subtitle:
                      'Upload audio files to play on the IoT device\nat scheduled times.',
                  buttonLabel: 'Upload Music',
                  onAction: _uploadMusic,
                  color: const Color(0xFFEC4899),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _music.length,
                    itemBuilder: (context, index) {
                      final m = _music[index];
                      final isActive = m['is_active'] ?? true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(CareSoulTheme.radiusLg),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFFEC4899).withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEC4899)
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
                                          ? const Color(0xFFEC4899)
                                          : Colors.grey)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: isActive
                                      ? const Color(0xFFEC4899)
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
                                      m['title'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 18,
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
                                          'Plays at ${m['scheduled_time'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_rounded,
                                            size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          () {
                                            final d = m['days_of_week'] ?? 'everyday';
                                            return d == 'everyday' ? '📅 Everyday' : '📅 $d';
                                          }(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Switch(
                                    value: isActive,
                                    activeThumbColor: const Color(0xFFEC4899),
                                    onChanged: (val) =>
                                        _toggleActive(m['id'], val),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editMusic(m);
                                      } else if (value == 'delete') {
                                        _deleteMusic(m['id']);
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

class _MusicDaysSelector extends StatelessWidget {
  final bool isEveryday;
  final Set<String> selectedDays;
  final List<String> days;
  final void Function(bool everyday, Set<String> days) onChanged;

  const _MusicDaysSelector({
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
            color: Color(0xFF6B7280),
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
                activeColor: const Color(0xFFEC4899),
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
                selectedColor: const Color(0xFFEC4899),
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
