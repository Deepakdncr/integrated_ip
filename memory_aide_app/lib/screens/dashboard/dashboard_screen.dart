import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../widgets/quick_action_card.dart';
import '../../widgets/status_badge.dart';

import '../patient/patient_profile_screen.dart';
import '../prescription/prescription_ocr_screen.dart';
import '../reminders/reminders_screen.dart';
import '../habits/habits_screen.dart';
import '../voice/voice_recording_screen.dart';
import '../music/music_scheduler_screen.dart';
import '../device/device_sync_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _patient;
  Map<String, dynamic>? _device;
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
    final patient = await ApiService.getPatient(userId);
    final device = await ApiService.getDeviceStatus(userId);

    if (mounted) {
      setState(() {
        _patient = patient;
        _device = device;
        _isLoading = false;
      });
    }
  }

  void _syncDevice() async {
    if (_userId == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Syncing device...')));
    final success = await ApiService.syncDevice(_userId!);
    if (success) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isOnline = _device?['is_online'] ?? false;
    final photoUrl = _patient?['photo_url'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('CareSoul Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // patient overview card
              GestureDetector(
                onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PatientProfileScreen()))
                    .then((_) => _loadData()),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: CareSoulTheme.accent,
                          backgroundImage: photoUrl != null
                              ? NetworkImage(ApiConfig.fileUrl(photoUrl))
                              : null,
                          child: photoUrl == null
                              ? const Icon(Icons.person,
                                  size: 40, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _patient?['name'] ?? 'Unknown Patient',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('Age: ${_patient?['age'] ?? '--'}',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 16)),
                              const SizedBox(height: 8),
                              StatusBadge(isOnline: isOnline),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text('Quick Actions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  QuickActionCard(
                    icon: Icons.medication,
                    label: 'Medicines',
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RemindersScreen())),
                  ),
                  QuickActionCard(
                    icon: Icons.directions_walk,
                    label: 'Habits',
                    color: Colors.orange,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HabitsScreen())),
                  ),
                  QuickActionCard(
                    icon: Icons.camera_alt,
                    label: 'Scan Prescription',
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PrescriptionOcrScreen())),
                  ),
                  QuickActionCard(
                    icon: Icons.mic,
                    label: 'Record Voice',
                    color: Colors.deepPurple,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VoiceRecordingScreen())),
                  ),
                  QuickActionCard(
                    icon: Icons.music_note,
                    label: 'Music',
                    color: Colors.pink,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MusicSchedulerScreen())),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // sync card
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.router,
                            color: Colors.blueGrey, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Device Sync',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600)),
                            if (_device?['last_sync'] != null)
                              Text(
                                  'Last: ${_device!['last_sync'].toString().split('.').first.replaceAll('T', ' ')}',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 13)),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          _syncDevice();
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DeviceSyncScreen()));
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Sync Now'),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
