import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../../widgets/empty_state.dart';

/// Music scheduler screen – upload and schedule music for the patient.
/// Works on both web and mobile (no dart:io dependency).
class MusicSchedulerScreen extends StatefulWidget {
  const MusicSchedulerScreen({super.key});

  @override
  State<MusicSchedulerScreen> createState() => _MusicSchedulerScreenState();
}

class _MusicSchedulerScreenState extends State<MusicSchedulerScreen> {
  List<Map<String, dynamic>> _music = [];
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
    if (_userId != null) {
      _music = await ApiService.getMusic(_userId!);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _uploadMusic() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.audio);

    if (result == null || _patientId == null) return;

    final file = result.files.single;

    // Get bytes from the file (works on both web and mobile)
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read file. Try a different file.'),
            backgroundColor: CareSoulTheme.error,
          ),
        );
      }
      return;
    }

    final titleCtrl = TextEditingController(text: file.name);
    TimeOfDay selectedTime = const TimeOfDay(hour: 17, minute: 0);

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
          content: Column(
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
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Upload'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
              ),
            ),
          ],
        ),
      ),
    );

    if (shouldUpload == true) {
      setState(() => _isLoading = true);
      final timeStr =
          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      final success = await ApiService.uploadMusic(
          bytes, file.name, titleCtrl.text.trim(), _patientId!, timeStr);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Music uploaded!'),
              backgroundColor: CareSoulTheme.success,
            ),
          );
        }
        _loadData();
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
                                  GestureDetector(
                                    onTap: () => _deleteMusic(m['id']),
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
