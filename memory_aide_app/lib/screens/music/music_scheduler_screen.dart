import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

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
    if (result != null &&
        result.files.single.path != null &&
        _patientId != null) {
      setState(() => _isLoading = true);
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();

      final titleCtrl = TextEditingController(text: result.files.single.name);
      final timeCtrl = TextEditingController(text: '17:00');

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Schedule Music'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              TextField(
                  controller: timeCtrl,
                  decoration: const InputDecoration(labelText: 'Time (HH:MM)')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ApiService.uploadMusic(bytes, result.files.single.name,
                    titleCtrl.text, _patientId!, timeCtrl.text);
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      );
      _loadData();
    }
  }

  Future<void> _toggleActive(String id, bool val) async {
    final success = await ApiService.updateMusic(id, {'is_active': val});
    if (success) _loadData();
  }

  Future<void> _delete(String id) async {
    final success = await ApiService.deleteMusic(id);
    if (success) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music Scheduler')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.pink,
        onPressed: _uploadMusic,
        child: const Icon(Icons.music_note),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _music.isEmpty
              ? const Center(
                  child: Text('No music scheduled.',
                      style: TextStyle(fontSize: 18, color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _music.length,
                    itemBuilder: (context, index) {
                      final m = _music[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const CircleAvatar(
                              backgroundColor: Colors.pink,
                              child:
                                  Icon(Icons.music_note, color: Colors.white)),
                          title: Text(m['title'],
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          subtitle: Text('Time: ${m['scheduled_time']}'),
                          trailing: Switch(
                            value: m['is_active'] ?? true,
                            activeThumbColor: Colors.pink,
                            onChanged: (val) => _toggleActive(m['id'], val),
                          ),
                          onLongPress: () => _delete(m['id']),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
