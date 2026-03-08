import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../widgets/quick_action_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/care_soul_logo.dart';

import '../patient/patient_profile_screen.dart';
import '../prescription/prescription_ocr_screen.dart';
import '../reminders/reminders_screen.dart';
import '../habits/habits_screen.dart';
import '../voice/voice_recording_screen.dart';
import '../music/music_scheduler_screen.dart';
import '../device/device_sync_screen.dart';
import '../settings/settings_screen.dart';

/// Main dashboard – caregiver home screen.
/// Shows Patient Overview, Quick Actions, and Device Status.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _patient;
  Map<String, dynamic>? _device;
  Map<String, dynamic>? _upcomingEvent;
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = await AuthService.getUserId();
    if (userId == null) return;

    _userId = userId;
    final results = await Future.wait([
      ApiService.getPatient(userId),
      ApiService.getDeviceStatus(userId),
      ApiService.getReminders(userId),
      ApiService.getHabits(userId),
      ApiService.getMusic(userId),
    ]);

    if (mounted) {
      setState(() {
        _patient = results[0] as Map<String, dynamic>?;
        _device = results[1] as Map<String, dynamic>?;

        final reminders =
            (results[2] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final habits =
            (results[3] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final music = (results[4] as List?)?.cast<Map<String, dynamic>>() ?? [];

        _upcomingEvent = _getUpcomingEvent(reminders, habits, music);
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _getUpcomingEvent(List<Map<String, dynamic>> reminders,
      List<Map<String, dynamic>> habits, List<Map<String, dynamic>> music) {
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;

    List<Map<String, dynamic>> allEvents = [];

    for (var r in reminders) {
      if (r['is_active'] == false) continue;
      final t = r['time_of_day'] as String?;
      if (t == null) continue;
      allEvents.add({
        'title': r['medicine_name'] ?? 'Medicine',
        'subtitle': r['dosage'] ?? '',
        'time': t,
        'type': 'Medicine',
        'icon': Icons.medication_rounded,
        'color': CareSoulTheme.success,
      });
    }

    for (var h in habits) {
      if (h['is_active'] == false) continue;
      final t = h['scheduled_time'] as String?;
      if (t == null) continue;
      allEvents.add({
        'title': h['title'] ?? 'Habit',
        'subtitle': 'Routine',
        'time': t,
        'type': 'Habit',
        'icon': Icons.directions_walk_rounded,
        'color': const Color(0xFFF59E0B),
      });
    }

    for (var m in music) {
      if (m['is_active'] == false) continue;
      final t = m['scheduled_time'] as String?;
      if (t == null) continue;
      allEvents.add({
        'title': m['title'] ?? 'Music',
        'subtitle': 'Audio Playback',
        'time': t,
        'type': 'Music',
        'icon': Icons.music_note_rounded,
        'color': const Color(0xFFEC4899),
      });
    }

    if (allEvents.isEmpty) return null;

    allEvents
        .sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));

    for (var e in allEvents) {
      final parts = (e['time'] as String).split(':');
      if (parts.length == 2) {
        final evMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        if (evMinutes >= currentMinutes) {
          return e;
        }
      }
    }
    return allEvents.first;
  }

  void _syncDevice() async {
    if (_userId == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Syncing device...'),
          ],
        ),
        backgroundColor: CareSoulTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
    final success = await ApiService.syncDevice(_userId!);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Device synced successfully!'),
              ],
            ),
            backgroundColor: CareSoulTheme.success,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync failed. Check device connection.'),
            backgroundColor: CareSoulTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CareSoulLogo(size: 80),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: CareSoulTheme.primary),
              const SizedBox(height: 16),
              Text('Loading dashboard...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final isOnline = _device?['is_online'] ?? false;
    final photoUrl = _patient?['photo_url'];
    final lastSync = _device?['last_sync'];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 22),
            SizedBox(width: 8),
            Text('CareSoul'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => _loadData()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: CareSoulTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Patient Overview Card ──
              _buildPatientCard(photoUrl, isOnline),
              const SizedBox(height: 20),

              // ── Up Next Card ──
              if (_upcomingEvent != null) ...[
                _buildUpcomingCard(),
                const SizedBox(height: 24),
              ],

              // ── Quick Actions Header ──
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: CareSoulTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Quick Actions Grid ──
              _buildQuickActionsGrid(),
              const SizedBox(height: 28),

              // ── Device Status Card ──
              _buildDeviceCard(isOnline, lastSync),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientCard(String? photoUrl, bool isOnline) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PatientProfileScreen()),
      ).then((_) => _loadData()),
      child: Container(
        decoration: CareSoulTheme.cardDecoration,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Patient photo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: CareSoulTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: CareSoulTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: photoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(ApiConfig.fileUrl(photoUrl)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: photoUrl == null
                    ? const Icon(Icons.person_rounded,
                        size: 40, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _patient?['name'] ?? 'Set Patient Name',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: CareSoulTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Age: ${_patient?['age'] ?? '--'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    StatusBadge(isOnline: isOnline),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CareSoulTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: CareSoulTheme.primary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingCard() {
    final event = _upcomingEvent;
    if (event == null) return const SizedBox.shrink();

    return Container(
      decoration: CareSoulTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.stars_rounded, color: event['color'], size: 22),
                const SizedBox(width: 8),
                Text(
                  'Up Next',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: event['color'],
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: event['color'].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 16, color: event['color']),
                      const SizedBox(width: 6),
                      Text(
                        event['time'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: event['color'],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: event['color'].withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(event['icon'], color: event['color'], size: 36),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['title'],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: CareSoulTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event['subtitle'],
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: [
        QuickActionCard(
          icon: Icons.medication_rounded,
          label: 'Add Medicine',
          color: const Color(0xFF0891B2),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RemindersScreen()),
          ),
        ),
        QuickActionCard(
          icon: Icons.directions_walk_rounded,
          label: 'Habit Routine',
          color: const Color(0xFFF59E0B),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HabitsScreen()),
          ),
        ),
        QuickActionCard(
          icon: Icons.mic_rounded,
          label: 'Record Voice',
          color: const Color(0xFF7C3AED),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VoiceRecordingScreen()),
          ),
        ),
        QuickActionCard(
          icon: Icons.document_scanner_rounded,
          label: 'Upload Prescription',
          color: const Color(0xFF2563EB),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrescriptionOcrScreen()),
          ),
        ),
        QuickActionCard(
          icon: Icons.music_note_rounded,
          label: 'Music',
          color: const Color(0xFFEC4899),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MusicSchedulerScreen()),
          ),
        ),
        QuickActionCard(
          icon: Icons.devices_rounded,
          label: 'Device Sync',
          color: const Color(0xFF64748B),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeviceSyncScreen()),
          ).then((_) => _loadData()),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(bool isOnline, dynamic lastSync) {
    String syncText = 'Never synced';
    if (lastSync != null) {
      syncText =
          'Last: ${lastSync.toString().split('.').first.replaceAll('T', ' ')}';
    }

    return Container(
      decoration: CareSoulTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Device icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isOnline
                    ? CareSoulTheme.success.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.router_rounded,
                color: isOnline ? CareSoulTheme.success : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Device',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: CareSoulTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _device?['device_id'] ?? 'ESP32-001',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    syncText,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _syncDevice,
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Sync'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
