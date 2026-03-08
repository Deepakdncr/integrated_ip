import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../auth/login_screen.dart';

/// Settings screen – volume control (3-level) and language (English/Tamil only).
/// Saves to backend API on change.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _volume = 'medium';
  String _language = 'en';
  bool _isLoading = true;

  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _userId = await AuthService.getUserId();
    if (_userId != null) {
      final data = await ApiService.getSettings(_userId!);
      if (mounted && data != null) {
        setState(() {
          _volume = data['volume'] ?? 'medium';
          _language = data['language'] ?? 'en';
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (_userId == null) return;
    final success = await ApiService.updateSettings(
      _userId!,
      {'volume': _volume, 'language': _language},
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
                                    'Language',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Audio announcement language',
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
                                label: Text('English',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ),
                              ButtonSegment(
                                value: 'ta',
                                label: Text('Tamil',
                                    style: TextStyle(
                                        fontSize: 16,
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

                  const SizedBox(height: 32),

                  // ── Logout Button ──
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded,
                        color: CareSoulTheme.error),
                    label: const Text('Logout',
                        style: TextStyle(
                            color: CareSoulTheme.error,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: CareSoulTheme.error, width: 1.5),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
