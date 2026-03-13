import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';

/// Voice recording screen – manage caregiver voice profiles.
/// Uses the `record` package for real audio recording on web & mobile.
class VoiceRecordingScreen extends StatefulWidget {
  const VoiceRecordingScreen({super.key});

  @override
  State<VoiceRecordingScreen> createState() => _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends State<VoiceRecordingScreen>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _hasRecording = false;
  List<Map<String, dynamic>> _voices = [];
  bool _isLoading = true;
  String? _userId;
  String? _patientId;
  late AnimationController _pulseController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingVoiceId;

  // Recording
  final AudioRecorder _recorder = AudioRecorder();

  String? _recordedBlobUrl; // For web playback of local recording

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _loadVoices();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadVoices() async {
    setState(() => _isLoading = true);
    _userId = await AuthService.getUserId();
    _patientId = await AuthService.getPatientId();
    if (_userId != null) {
      _voices = await ApiService.getVoices(_userId!);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Record as WAV (widely supported). On web, the browser picks the codec.
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: '', // empty path for in-memory / stream recording on web
      );

      setState(() => _isRecording = true);
      _pulseController.repeat(reverse: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.mic, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Recording... Tap to stop'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 30),
          ),
        );
      }
    } catch (e) {
      debugPrint('Start recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      debugPrint('Recording stopped. Path: $path');

      if (path != null && path.isNotEmpty) {
        // On web, `path` is a blob URL (blob:http://...).
        // On mobile, `path` is a file system path.
        // In both cases, store it for playback and upload.
        _recordedBlobUrl = path;

        setState(() {
          _isRecording = false;
          _hasRecording = true;
        });
      } else {
        setState(() => _isRecording = false);
      }

      _pulseController.stop();
      _pulseController.reset();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        if (_hasRecording) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Recording saved! You can preview or upload it.'),
                ],
              ),
              backgroundColor: CareSoulTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
      setState(() => _isRecording = false);
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  Future<void> _playRecordedPreview() async {
    if (_recordedBlobUrl == null) return;
    try {
      await _audioPlayer.stop();
      if (kIsWeb) {
        // On web, play the blob URL directly
        await _audioPlayer.play(UrlSource(_recordedBlobUrl!));
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordedBlobUrl!));
      }
    } catch (e) {
      debugPrint('Preview play error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not play preview: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _uploadVoice() async {
    if (!_hasRecording) return;
    if (_patientId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Missing patient ID')));
      return;
    }

    // Set alarm time
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Select Alarm Time',
    );
    if (time == null) return;
    if (!mounted) return;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    // Show name dialog
    final nameCtrl = TextEditingController(text: 'Voice Recording');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Name this recording',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(fontSize: 17),
          decoration: const InputDecoration(
            labelText: 'Recording Name',
            hintText: 'e.g. Mom\'s Voice',
            prefixIcon: Icon(Icons.label_outlined, size: 22),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    setState(() => _isLoading = true);

    bool success = false;

    if (kIsWeb && _recordedBlobUrl != null) {
      // On web, upload blob via special method
      success = await ApiService.uploadVoiceFromBlobUrl(
          _recordedBlobUrl!, name, _patientId!, timeStr);
    } else if (_recordedBlobUrl != null) {
      // Mobile - read file and upload
      success = await ApiService.uploadVoiceFromFilePath(
          _recordedBlobUrl!, name, _patientId!, timeStr);
    }

    if (mounted) {
      setState(() {
        _hasRecording = false;
        _recordedBlobUrl = null;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(success ? 'Voice uploaded!' : 'Upload failed'),
            ],
          ),
          backgroundColor:
              success ? CareSoulTheme.success : CareSoulTheme.error,
        ),
      );

      if (success) _loadVoices();
    }
  }

  Future<void> _deleteVoice(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Voice',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remove "$name"?', style: const TextStyle(fontSize: 16)),
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
      await ApiService.deleteVoice(id);
      _loadVoices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Profiles'),
        backgroundColor: const Color(0xFF7C3AED),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Recording Card ──
                  Container(
                    decoration: CareSoulTheme.cardDecoration,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const Text(
                          'Record Caregiver Voice',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: CareSoulTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Record voice for medicine announcements',
                          style: TextStyle(
                            fontSize: 14,
                            color: CareSoulTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Record button
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) => Container(
                            padding: EdgeInsets.all(_isRecording
                                ? 8 + (_pulseController.value * 6)
                                : 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_isRecording
                                      ? Colors.red
                                      : const Color(0xFF7C3AED))
                                  .withValues(alpha: 0.1),
                            ),
                            child: child,
                          ),
                          child: GestureDetector(
                            onTap:
                                _isRecording ? _stopRecording : _startRecording,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _isRecording
                                      ? [Colors.red[400]!, Colors.red[700]!]
                                      : [
                                          const Color(0xFF7C3AED),
                                          const Color(0xFF5B21B6)
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isRecording
                                            ? Colors.red
                                            : const Color(0xFF7C3AED))
                                        .withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isRecording
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isRecording
                              ? 'Recording... Tap to stop'
                              : _hasRecording
                                  ? 'Recording ready!'
                                  : 'Tap to start recording',
                          style: TextStyle(
                            fontSize: 15,
                            color: _isRecording
                                ? Colors.red
                                : CareSoulTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        if (_hasRecording) ...[
                          const SizedBox(height: 16),
                          // Preview button
                          OutlinedButton.icon(
                            onPressed: _playRecordedPreview,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Preview Recording'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7C3AED),
                              side: const BorderSide(color: Color(0xFF7C3AED)),
                              minimumSize: const Size(220, 46),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _uploadVoice,
                            icon: const Icon(Icons.cloud_upload_rounded),
                            label: const Text('Save Voice Profile'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              minimumSize: const Size(220, 50),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Saved Voices ──
                  const Text(
                    'Saved Voice Profiles',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: CareSoulTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_voices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.record_voice_over_rounded,
                              size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No recordings yet',
                            style: TextStyle(
                                fontSize: 15, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(
                      _voices.length,
                      (index) {
                        final v = _voices[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.record_voice_over_rounded,
                                  color: Color(0xFF7C3AED)),
                            ),
                            title: Text(v['name'] ?? 'Voice',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16)),
                            subtitle: v['scheduled_time'] != null
                                ? Text('⏰ ${v['scheduled_time']}',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey[600]))
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _playingVoiceId == v['id']
                                        ? Icons.stop_rounded
                                        : Icons.play_arrow_rounded,
                                    color: _playingVoiceId == v['id']
                                        ? Colors.red
                                        : CareSoulTheme.primary,
                                  ),
                                  onPressed: () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    if (_playingVoiceId == v['id']) {
                                      await _audioPlayer.stop();
                                      setState(() => _playingVoiceId = null);
                                    } else {
                                      try {
                                        await _audioPlayer.stop();
                                        setState(
                                            () => _playingVoiceId = v['id']);
                                        final url =
                                            ApiConfig.fileUrl(v['file_url']);
                                        debugPrint('Playing voice from: $url');
                                        await _audioPlayer.play(UrlSource(url));
                                        _audioPlayer.onPlayerComplete
                                            .listen((_) {
                                          if (mounted) {
                                            setState(
                                                () => _playingVoiceId = null);
                                          }
                                        });
                                      } catch (e) {
                                        debugPrint('Play error: $e');
                                        if (mounted) {
                                          setState(
                                              () => _playingVoiceId = null);
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Could not play: ${e.toString().substring(0, 50)}'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                                Switch(
                                  value: v['is_active'] ?? true,
                                  activeThumbColor: CareSoulTheme.primary,
                                  onChanged: (val) async {
                                    final success =
                                        await ApiService.updateVoice(
                                            v['id'], {'is_active': val});
                                    if (success) _loadVoices();
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded,
                                      color: Colors.red[400]),
                                  onPressed: () => _deleteVoice(
                                      v['id'], v['name'] ?? 'Voice'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
