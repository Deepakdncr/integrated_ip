import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';

/// Device sync screen – view IoT device status and force sync.
class DeviceSyncScreen extends StatefulWidget {
  const DeviceSyncScreen({super.key});

  @override
  State<DeviceSyncScreen> createState() => _DeviceSyncScreenState();
}

class _DeviceSyncScreenState extends State<DeviceSyncScreen> {
  Map<String, dynamic>? _device;
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    setState(() => _isLoading = true);
    _userId = await AuthService.getUserId();
    if (_userId != null) {
      _device = await ApiService.getDeviceStatus(_userId!);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _sync() async {
    if (_userId == null) return;
    setState(() => _isSyncing = true);
    final success = await ApiService.syncDevice(_userId!);

    if (mounted) {
      setState(() => _isSyncing = false);
      if (success) {
        _loadDevice();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Device synchronized successfully!'),
              ],
            ),
            backgroundColor: CareSoulTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Sync failed. Check device connection.'),
              ],
            ),
            backgroundColor: CareSoulTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _device?['is_online'] ?? false;
    final deviceId = _device?['device_id'] ?? 'ESP32-001';
    final lastSync = _device?['last_sync'];

    String syncText = 'Never synced';
    if (lastSync != null) {
      syncText = lastSync.toString().split('.').first.replaceAll('T', ' ');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Sync'),
        backgroundColor: const Color(0xFF64748B),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // ── Device Status Card ──
                  Container(
                    width: double.infinity,
                    decoration: CareSoulTheme.cardDecoration,
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        // Device icon with status glow
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                (isOnline ? CareSoulTheme.success : Colors.grey)
                                    .withValues(alpha: 0.1),
                            boxShadow: isOnline
                                ? [
                                    BoxShadow(
                                      color: CareSoulTheme.success
                                          .withValues(alpha: 0.2),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            Icons.router_rounded,
                            size: 64,
                            color:
                                isOnline ? CareSoulTheme.success : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Status
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: (isOnline
                                    ? CareSoulTheme.success
                                    : CareSoulTheme.error)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            isOnline ? '● Online' : '● Offline',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isOnline
                                  ? CareSoulTheme.success
                                  : CareSoulTheme.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Device info rows
                        _infoRow(Icons.memory_rounded, 'Device ID', deviceId),
                        const SizedBox(height: 12),
                        _infoRow(Icons.wifi_rounded, 'WiFi Status',
                            _device?['wifi_status'] ?? 'Unknown'),
                        const SizedBox(height: 12),
                        _infoRow(Icons.schedule_rounded, 'Last Sync', syncText),

                        const SizedBox(height: 32),

                        // Sync button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSyncing ? null : _sync,
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.sync_rounded),
                            label: Text(
                                _isSyncing ? 'Syncing...' : 'Force Sync Now'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── What gets synced info ──
                  Container(
                    decoration: CareSoulTheme.cardDecoration,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: CareSoulTheme.primary, size: 22),
                            SizedBox(width: 8),
                            Text('What Gets Synced',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _syncItem(Icons.medication_rounded,
                            'Medicine reminders & dosages'),
                        _syncItem(Icons.directions_walk_rounded,
                            'Habit routine schedules'),
                        _syncItem(Icons.record_voice_over_rounded,
                            'Voice profiles for announcements'),
                        _syncItem(Icons.volume_up_rounded,
                            'Volume & language settings'),
                        _syncItem(Icons.music_note_rounded, 'Scheduled music'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: CareSoulTheme.textSecondary),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 15,
            color: CareSoulTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CareSoulTheme.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _syncItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: CareSoulTheme.primary),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  fontSize: 14, color: CareSoulTheme.textSecondary)),
        ],
      ),
    );
  }
}
