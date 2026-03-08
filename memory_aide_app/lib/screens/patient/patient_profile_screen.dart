import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';

/// Patient profile screen – edit name, age, photo, medical notes.
/// Saves data to backend API via REST PUT.
class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _photoUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await ApiService.updatePatient(_userId!, {
      'name': _nameCtrl.text.trim(),
      'age': int.tryParse(_ageCtrl.text.trim()),
      'medical_notes': _notesCtrl.text.trim(),
    });

    if (mounted) {
      setState(() => _isSaving = false);

      if (success) {
        // Show success dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CareSoulTheme.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: CareSoulTheme.success, size: 56),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Profile Saved!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Patient profile updated successfully.',
                  style: TextStyle(
                      fontSize: 15, color: CareSoulTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(180, 48),
                    backgroundColor: CareSoulTheme.success,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Failed to save profile. Try again.'),
              ],
            ),
            backgroundColor: CareSoulTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

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

        if (url != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Photo uploaded successfully!'),
                ],
              ),
              backgroundColor: CareSoulTheme.success,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Profile'),
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: const Icon(Icons.save_rounded, color: Colors.white),
              label: const Text('Save',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Photo Section ──
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: _photoUrl == null
                                  ? CareSoulTheme.primaryGradient
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: CareSoulTheme.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              image: _photoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(
                                          ApiConfig.fileUrl(_photoUrl!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _photoUrl == null
                                ? const Icon(Icons.person_rounded,
                                    size: 60, color: Colors.white)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: CareSoulTheme.primary,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: CareSoulTheme.primary
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Name Field ──
                    Container(
                      decoration: CareSoulTheme.cardDecoration,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  color: CareSoulTheme.primary, size: 22),
                              SizedBox(width: 8),
                              Text('Basic Information',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _nameCtrl,
                            style: const TextStyle(fontSize: 18),
                            decoration: const InputDecoration(
                              labelText: 'Patient Name',
                              prefixIcon: Icon(Icons.badge_outlined, size: 22),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Name is required'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _ageCtrl,
                            style: const TextStyle(fontSize: 18),
                            decoration: const InputDecoration(
                              labelText: 'Age',
                              prefixIcon: Icon(Icons.cake_outlined, size: 22),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Age is required';
                              }
                              if (int.tryParse(v.trim()) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Medical Notes Field ──
                    Container(
                      decoration: CareSoulTheme.cardDecoration,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.medical_information_outlined,
                                  color: CareSoulTheme.primary, size: 22),
                              SizedBox(width: 8),
                              Text('Medical Notes',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notesCtrl,
                            style: const TextStyle(fontSize: 16),
                            decoration: const InputDecoration(
                              hintText:
                                  'Allergies, conditions, doctor notes...',
                              alignLabelWithHint: true,
                            ),
                            maxLines: 5,
                            minLines: 3,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Save Button ──
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
