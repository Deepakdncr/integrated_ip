import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class DeviceSyncScreen extends StatefulWidget {
  const DeviceSyncScreen({super.key});

  @override
  State<DeviceSyncScreen> createState() => _DeviceSyncScreenState();
}

class _DeviceSyncScreenState extends State<DeviceSyncScreen> {
  Map<String, dynamic>? _device;
  bool _isLoading = true;
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
    setState(() => _isLoading = true);
    final success = await ApiService.syncDevice(_userId!);
    if (success) {
      _loadDevice();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device synchronized.')));
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Sync')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(Icons.router,
                              size: 80,
                              color: _device?['is_online'] == true
                                  ? Colors.green
                                  : Colors.grey),
                          const SizedBox(height: 16),
                          Text('Device ID: ${_device?['device_id']}',
                              style: const TextStyle(fontSize: 18),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text(
                            'Status: ${_device?['is_online'] == true ? 'Online' : 'Offline'}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _device?['is_online'] == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text('Last Sync: ${_device?['last_sync'] ?? '-'}',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _sync,
                            icon: const Icon(Icons.sync),
                            label: const Text('Force Sync Now'),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
