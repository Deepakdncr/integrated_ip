import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _photoUrl;
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    _userId = await AuthService.getUserId();
    if (_userId == null) return;

    final data = await ApiService.getPatient(_userId!);

    if (mounted) {
      setState(() {
        if (data != null) {
          _nameCtrl.text = data['name'] ?? '';
          _ageCtrl.text = data['age']?.toString() ?? '';
          _notesCtrl.text = data['medical_notes'] ?? '';
          _photoUrl = data['photo_url'];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_userId == null) return;
    setState(() => _isLoading = true);

    final success = await ApiService.updatePatient(_userId!, {
      'name': _nameCtrl.text,
      'age': int.tryParse(_ageCtrl.text),
      'medical_notes': _notesCtrl.text,
    });

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Profile saved' : 'Failed to save')),
      );
      if (success) Navigator.pop(context);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && _userId != null) {
      setState(() => _isLoading = true);
      final bytes = await image.readAsBytes();
      final url =
          await ApiService.uploadPatientPhoto(_userId!, bytes, image.name);

      if (mounted) {
        setState(() {
          if (url != null) _photoUrl = url;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: CareSoulTheme.accent,
                          backgroundImage: _photoUrl != null
                              ? NetworkImage(ApiConfig.fileUrl(_photoUrl!))
                              : null,
                          child: _photoUrl == null
                              ? const Icon(Icons.person,
                                  size: 60, color: Colors.white)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            backgroundColor: CareSoulTheme.primary,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt,
                                  color: Colors.white),
                              onPressed: _pickImage,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Patient Name'),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _ageCtrl,
                    decoration: const InputDecoration(labelText: 'Age'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _notesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Medical Notes'),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _saveProfile,
                    child: const Text('Save Profile'),
                  )
                ],
              ),
            ),
    );
  }
}
