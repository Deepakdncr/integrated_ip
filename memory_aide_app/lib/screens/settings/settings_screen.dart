import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

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
    setState(() => _isLoading = true);
    final success = await ApiService.updateSettings(
        _userId!, {'volume': _volume, 'language': _language});
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success ? 'Saved' : 'Failed')));
    }
  }

  void _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Device Volume',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'low', label: Text('Low')),
                    ButtonSegment(value: 'medium', label: Text('Medium')),
                    ButtonSegment(value: 'high', label: Text('High')),
                  ],
                  selected: {_volume},
                  onSelectionChanged: (set) {
                    setState(() => _volume = set.first);
                    _saveSettings();
                  },
                ),
                const SizedBox(height: 32),
                const Text('Language',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'es', child: Text('Spanish')),
                    DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _language = v);
                      _saveSettings();
                    }
                  },
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 48),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label:
                      const Text('Logout', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red)),
                )
              ],
            ),
    );
  }
}
