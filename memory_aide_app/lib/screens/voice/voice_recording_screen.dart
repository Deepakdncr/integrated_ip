import 'dart:io' show Directory, File;
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
    // _userId = await AuthService.getUserId();
    // _patientId = await AuthService.getPatientId();
    _userId = 'test_user'; // Hardcoded for ESP32 integration
    _patientId = 'test_user';
    
    _voices = await ApiService.getVoices(_userId!);
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

      // Use high-quality WAV for mobile – the backend will transcode to optimized MP3
      final path = kIsWeb ? '' : '${Directory.systemTemp.path}/recording.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav, 
          sampleRate: 44100, 
          numChannels: 1,
        ),
        path: path,
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
        debugPrint('[Voice] Recording saved to: $path');
        _recordedBlobUrl = path;
        setState(() {
          _isRecording = false;
          _hasRecording = true;
        });
      } else {
        debugPrint('[Voice] Recording path is NULL or empty!');
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
        // Use DeviceFileSource for mobile recordings
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
    bool isEveryday = true;
    Set<String> selectedDays = {};
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Save Voice Recording',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 17),
                  decoration: const InputDecoration(
                    labelText: 'Recording Name',
                    hintText: 'e.g. Mom\'s Voice',
                    prefixIcon: Icon(Icons.label_outlined, size: 22),
                  ),
                ),
                const SizedBox(height: 16),
                _VoiceDaysSelector(
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
                    onPressed: () => Navigator.pop(ctx, {
                      'name': nameCtrl.text.trim(),
                      'daysStr': isEveryday
                          ? 'everyday'
                          : (selectedDays.isEmpty
                              ? 'everyday'
                              : selectedDays.join(',')),
                    }),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
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

    if (result == null || result['name'].isEmpty) return;
    final name = result['name'];
    final daysStr = result['daysStr'];

    setState(() => _isLoading = true);

    bool success = false;

    if (kIsWeb && _recordedBlobUrl != null) {
      debugPrint('[Voice] Uploading blob from web: $_recordedBlobUrl');
      success = await ApiService.uploadVoiceFromBlobUrl(
          _recordedBlobUrl!, name, _patientId!, timeStr, daysStr);
    } else if (_recordedBlobUrl != null) {
      debugPrint('[Voice] Uploading file from mobile: $_recordedBlobUrl');
      success = await ApiService.uploadVoiceFromFilePath(
          _recordedBlobUrl!, name, _patientId!, timeStr, daysStr);
      
      // Clean up the temp file after attempt
      try {
        final file = File(_recordedBlobUrl!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('[Voice] Temp file deleted.');
        }
      } catch (e) {
        debugPrint('[Voice] Cleanup error: $e');
      }
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

  void _editVoice(Map<String, dynamic> v) {
    final nameCtrl = TextEditingController(text: v['name'] ?? '');
    final timeStr = v['scheduled_time'] ?? '08:00';
    int hour = int.tryParse(timeStr.split(':')[0]) ?? 8;
    int minute = int.tryParse(timeStr.split(':')[1]) ?? 0;
    TimeOfDay selectedTime = TimeOfDay(hour: hour, minute: minute);
    final daysRaw = v['days_of_week'] ?? 'everyday';
    bool isEveryday = daysRaw == 'everyday';
    Set<String> selectedDays = isEveryday ? {} : daysRaw.toString().split(',').toSet();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(children: [
            Icon(Icons.edit_rounded, color: CareSoulTheme.primary, size: 28),
            SizedBox(width: 12),
            Text('Edit Voice Profile', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                    labelText: 'Recording Name',
                    prefixIcon: const Icon(Icons.label_outlined, size: 22),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: selectedTime);
                  if (t != null) setDialogState(() => selectedTime = t);
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                      labelText: 'Broadcast Time',
                      prefixIcon: const Icon(Icons.schedule_rounded, size: 22),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(selectedTime.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 16),
              _VoiceDaysSelector(
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
            ]),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)))),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final t = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                  final d = isEveryday ? 'everyday' : (selectedDays.isEmpty ? 'everyday' : selectedDays.join(','));
                  
                  setState(() => _isLoading = true);
                  final success = await ApiService.updateVoice(v['id'], {
                    'name': nameCtrl.text.trim(),
                    'scheduled_time': t,
                    'days_of_week': d,
                  });
                  
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  if (success) {
                    _loadVoices();
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Voice profile updated!'), backgroundColor: CareSoulTheme.success));
                  } else {
                    setState(() => _isLoading = false);
                  }
                },
                style: FilledButton.styleFrom(
                    backgroundColor: CareSoulTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
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
                          const SizedBox(height: 20),
                          // Preview button – full width
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _playRecordedPreview,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Preview Recording'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF7C3AED),
                                side: const BorderSide(color: Color(0xFF7C3AED)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Discard + Save row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _hasRecording = false;
                                      _recordedBlobUrl = null;
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey[700],
                                    side: BorderSide(color: Colors.grey[300]!),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Discard',
                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: _uploadVoice,
                                  icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                                  label: const Text('Save Voice Profile'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: CareSoulTheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
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
                        final id = v['id'];
                        final isActive = v['is_active'] ?? true;
                        final daysStr = v['days_of_week'] ?? 'everyday';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isActive
                                    ? CareSoulTheme.primary.withValues(alpha: 0.12)
                                    : Colors.grey.withValues(alpha: 0.15),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: (isActive ? CareSoulTheme.primary : Colors.grey)
                                    .withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Compact Leading
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isActive ? CareSoulTheme.primary : Colors.grey)
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.mic_none_rounded,
                                    color: isActive ? CareSoulTheme.primary : Colors.grey,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
                                // Main Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              v['name'] ?? 'Voice Profile',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                                color: isActive ? CareSoulTheme.textPrimary : Colors.grey,
                                              ),
                                            ),
                                          ),
                                          // Play button next to title to save horizontal space in trailing
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: Icon(
                                              _playingVoiceId == id
                                                  ? Icons.stop_circle_rounded
                                                  : Icons.play_circle_filled_rounded,
                                              color: _playingVoiceId == id
                                                  ? Colors.red
                                                  : CareSoulTheme.primary,
                                              size: 26,
                                            ),
                                            onPressed: () async {
                                              if (_playingVoiceId == id) {
                                                await _audioPlayer.stop();
                                                setState(() => _playingVoiceId = null);
                                              } else {
                                                try {
                                                  await _audioPlayer.stop();
                                                  setState(() => _playingVoiceId = id);
                                                  final url = ApiConfig.fileUrl(v['file_url']);
                                                  await _audioPlayer.play(UrlSource(url));
                                                  _audioPlayer.onPlayerComplete.listen((_) {
                                                    if (mounted) setState(() => _playingVoiceId = null);
                                                  });
                                                } catch (e) {
                                                  if (mounted) setState(() => _playingVoiceId = null);
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.schedule_rounded, size: 13, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            v['scheduled_time'] ?? '08:00',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(width: 10),
                                          Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              daysStr == 'everyday' ? 'Everyday' : daysStr,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Compact Trailing Actions
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_horiz_rounded, color: Colors.grey[400], size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _editVoice(v);
                                        } else if (value == 'delete') {
                                          _deleteVoice(id, v['name'] ?? 'Voice');
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(children: [
                                            Icon(Icons.edit_note_rounded, color: Colors.blue[600], size: 18),
                                            const SizedBox(width: 8),
                                            const Text('Edit', style: TextStyle(fontSize: 14)),
                                          ]),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(children: [
                                            Icon(Icons.delete_sweep_rounded, color: Colors.red[600], size: 18),
                                            const SizedBox(width: 8),
                                            const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 14)),
                                          ]),
                                        ),
                                      ],
                                    ),
                                    Transform.scale(
                                      scale: 0.7,
                                      child: Switch(
                                        value: isActive,
                                        activeColor: CareSoulTheme.primary,
                                        onChanged: (val) async {
                                          final success = await ApiService.updateVoice(id, {'is_active': val});
                                          if (success) _loadVoices();
                                        },
                                      ),
                                    ),
                                  ],
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

class _VoiceDaysSelector extends StatelessWidget {
  final bool isEveryday;
  final Set<String> selectedDays;
  final List<String> days;
  final void Function(bool everyday, Set<String> days) onChanged;

  const _VoiceDaysSelector({
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
                activeColor: const Color(0xFF7C3AED),
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
                selectedColor: const Color(0xFF7C3AED),
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
