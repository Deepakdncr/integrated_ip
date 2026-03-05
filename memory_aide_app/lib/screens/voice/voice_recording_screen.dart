import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class VoiceRecordingScreen extends StatefulWidget {
  const VoiceRecordingScreen({super.key});

  @override
  State<VoiceRecordingScreen> createState() => _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends State<VoiceRecordingScreen> {
  bool _isRecording = false;
  String? _audioPath;
  List<Map<String, dynamic>> _voices = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    setState(() => _isLoading = true);
    _userId = await AuthService.getUserId();
    if (_userId != null) {
      _voices = await ApiService.getVoices(_userId!);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording simulated. Use real device.')));
  }

  Future<void> _stopRecording() async {
    setState(() {
      _isRecording = false;
      _audioPath = 'dummy_path';
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stop recording simulated.')));
  }

  Future<void> _playRecording() async {
    if (_audioPath != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Playback simulated.')));
    }
  }

  Future<void> _uploadVoice() async {
    if (_audioPath == null) return;
    setState(() => _isLoading = true);
    // Simulated upload
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Upload simulated.')));
      setState(() {
        _audioPath = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Profiles')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text('Record Caregiver Voice',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap:
                                _isRecording ? _stopRecording : _startRecording,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor:
                                  _isRecording ? Colors.red : Colors.deepPurple,
                              child: Icon(_isRecording ? Icons.stop : Icons.mic,
                                  color: Colors.white, size: 40),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_audioPath != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                    icon:
                                        const Icon(Icons.play_arrow, size: 36),
                                    onPressed: _playRecording),
                                FilledButton.icon(
                                  onPressed: _uploadVoice,
                                  icon: const Icon(Icons.cloud_upload),
                                  label: const Text('Save Voice'),
                                )
                              ],
                            )
                          ]
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Saved Voices',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold))),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _voices.length,
                      itemBuilder: (context, index) {
                        final v = _voices[index];
                        return ListTile(
                          leading: const CircleAvatar(
                              backgroundColor: Colors.deepPurple,
                              child: Icon(Icons.record_voice_over,
                                  color: Colors.white)),
                          title: Text(v['name']),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await ApiService.deleteVoice(v['id']);
                              _loadVoices();
                            },
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
