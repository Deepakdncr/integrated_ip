import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../auth/login_screen.dart';
import '../device/device_sync_screen.dart';

/// Settings screen – volume control, language (English/Tamil), and synthetic voice selection.
/// Saves to backend API on change.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _volume = 'medium';
  String _language = 'en';
  String _voiceId = 'default';
  bool _isLoading = true;

  String? _userId;

  // Available synthetic voices (Indian accent options)
  static const List<Map<String, String>> _syntheticVoices = [
    {
      'id': 'default',
      'name': 'Priya',
      'description': 'Indian Female · Warm & Clear',
      'flag': '🇮🇳',
    },
    {
      'id': 'indian_male',
      'name': 'Raj',
      'description': 'Indian Male · Deep & Friendly',
      'flag': '🇮🇳',
    },
    {
      'id': 'south_indian',
      'name': 'Kavya',
      'description': 'South Indian Female · Gentle',
      'flag': '🇮🇳',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _userId = 'test_user'; // Map to ESP32 test_user
    if (_userId != null) {
      final data = await ApiService.getSettings(_userId!);
      if (mounted && data != null) {
        setState(() {
          _volume = data['volume'] ?? 'medium';
          _language = data['language'] ?? 'en';
          _voiceId = data['voice_id'] ?? 'default';
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (_userId == null) return;
    final success = await ApiService.updateSettings(
      _userId!,
      {'volume': _volume, 'language': _language, 'voice_id': _voiceId},
    );
    if (mounted) {
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
              Text(success
                  ? 'Settings saved & synced to device'
                  : 'Failed to save settings'),
            ],
          ),
          backgroundColor:
              success ? CareSoulTheme.success : CareSoulTheme.error,
        ),
      );
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: CareSoulTheme.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // Volume icon based on level
  IconData _volumeIcon(String level) {
    switch (level) {
      case 'low':
        return Icons.volume_down_rounded;
      case 'high':
        return Icons.volume_up_rounded;
      default:
        return Icons.volume_mute_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Volume Control Section ──
                  Container(
                    decoration: CareSoulTheme.cardDecoration,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: CareSoulTheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _volumeIcon(_volume),
                                color: CareSoulTheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Device Volume',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Announcement volume on IoT device',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CareSoulTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 3-level volume control
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'low',
                                label: Text('Low',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                icon: Icon(Icons.volume_down_rounded),
                              ),
                              ButtonSegment(
                                value: 'medium',
                                label: Text('Medium',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                icon: Icon(Icons.volume_mute_rounded),
                              ),
                              ButtonSegment(
                                value: 'high',
                                label: Text('High',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                icon: Icon(Icons.volume_up_rounded),
                              ),
                            ],
                            selected: {_volume},
                            onSelectionChanged: (set) {
                              setState(() => _volume = set.first);
                              _saveSettings();
                            },
                            style: ButtonStyle(
                              minimumSize:
                                  WidgetStateProperty.all(const Size(0, 52)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Language Section ──
                  Container(
                    decoration: CareSoulTheme.cardDecoration,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.language_rounded,
                                color: Color(0xFF2563EB),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Announcement Language',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Language used for IoT voice announcements',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CareSoulTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Language – English & Tamil only
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'en',
                                label: Text('🇬🇧  English',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ),
                              ButtonSegment(
                                value: 'ta',
                                label: Text('🇮🇳  Tamil',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                            selected: {_language},
                            onSelectionChanged: (set) {
                              setState(() => _language = set.first);
                              _saveSettings();
                            },
                            style: ButtonStyle(
                              minimumSize:
                                  WidgetStateProperty.all(const Size(0, 52)),
                            ),
                          ),
                        ),

                        if (_language == 'ta') ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: Color(0xFF2563EB), size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'தமிழ் மொழியில் மருந்து மற்றும் பழக்க அறிவிப்புகள் வழங்கப்படும்.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1D4ED8),
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Synthetic Voice Selection ──
                  Container(
                    decoration: CareSoulTheme.cardDecoration,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.record_voice_over_rounded,
                                color: Color(0xFF7C3AED),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Synthetic Voice',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'TTS voice for reminders & habits',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CareSoulTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Voice options
                        ..._syntheticVoices.map((voice) {
                          final isSelected = _voiceId == voice['id'];
                          return GestureDetector(
                            onTap: () {
                              setState(() => _voiceId = voice['id']!);
                              _saveSettings();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.08)
                                    : Colors.grey.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF7C3AED)
                                      : Colors.grey.withValues(alpha: 0.2),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(voice['flag']!,
                                      style: const TextStyle(fontSize: 24)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          voice['name']!,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? const Color(0xFF7C3AED)
                                                : CareSoulTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          voice['description']!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isSelected
                                                ? const Color(0xFF7C3AED)
                                                    .withValues(alpha: 0.8)
                                                : CareSoulTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded,
                                        color: Color(0xFF7C3AED), size: 22)
                                  else
                                    Icon(Icons.radio_button_unchecked_rounded,
                                        color: Colors.grey.withValues(alpha: 0.4),
                                        size: 22),
                                ],
                              ),
                            ),
                          );
                        }),

                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Color(0xFF7C3AED), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'All voices use Indian-accent gTTS synthesis on the backend server.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF5B21B6),
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Device Sync Section ──
                  Container(
                    decoration: CareSoulTheme.cardDecoration,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64748B)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.devices_rounded,
                                color: Color(0xFF64748B),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'IoT Device Sync',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Force sync ESP32 hardware',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CareSoulTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DeviceSyncScreen()),
                          ).then((_) => _loadSettings()),
                          icon: const Icon(Icons.sync_rounded, size: 20),
                          label: const Text('Open Device Sync', 
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF64748B),
                            minimumSize: const Size(0, 52),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── App Info Section ──
                  Container(
                    decoration: CareSoulTheme.cardDecoration,
                    padding: const EdgeInsets.all(24),
                    child: const Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: CareSoulTheme.textSecondary, size: 20),
                            SizedBox(width: 10),
                            Text('App Version',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: CareSoulTheme.textSecondary)),
                            Spacer(),
                            Text('2.0.0',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Logout Button ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, color: CareSoulTheme.error),
                      label: const Text(
                        'Logout Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: CareSoulTheme.error,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: CareSoulTheme.error, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(CareSoulTheme.radiusLg),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
