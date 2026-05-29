import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../models/ai_companion.dart';
import '../repository/ai_companion_repository.dart';

class EditAiCompanionScreen extends StatefulWidget {
  final AiCompanion companion;

  const EditAiCompanionScreen({super.key, required this.companion});

  @override
  State<EditAiCompanionScreen> createState() => _EditAiCompanionScreenState();
}

class _EditAiCompanionScreenState extends State<EditAiCompanionScreen> {
  final _repository = AiCompanionRepository();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late String _purpose;
  late List<String> _selectedPersonalities;
  late String _communicationStyle;
  late String _relationshipTone;
  String? _avatarUrl;
  File? _selectedImage;
  bool _isLoading = false;

  final List<String> _purposes = [
    'Friend 👋', 'Girlfriend ❤️', 'Boyfriend 💙',
    'Emotional Support 😌', 'Motivator 🎯', 'Funny Bestie 😂',
  ];

  final List<String> _personalities = [
    'Sweet', 'Caring', 'Funny', 'Savage', 'Romantic',
    'Protective', 'Calm', 'Confident', 'Introvert', 'Extrovert'
  ];

  final List<String> _styles = [
    'Cute texting', 'Casual texting', 'Deep conversations',
    'Short replies', 'Long detailed replies', 'Gen Z style', 'Formal',
  ];

  final List<String> _tones = [
    'Friendly only', 'Slightly flirty', 'Romantic', 'Deep emotional',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.companion;
    _nameController = TextEditingController(text: c.name);
    _purpose = c.purpose;
    _selectedPersonalities = List.from(c.personalities);
    _communicationStyle = c.communicationStyle;
    _relationshipTone = c.relationshipTone;
    _avatarUrl = c.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Avatar',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Crop Avatar'),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _selectedImage = File(croppedFile.path);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      String? uploadedUrl = _avatarUrl;
      if (_selectedImage != null) {
        uploadedUrl = await _repository.uploadAvatar(_selectedImage!);
      }

      final updatedCompanion = await _repository.updateCompanion(widget.companion.id, {
        'name': _nameController.text.trim(),
        'purpose': _purpose,
        'personalities': _selectedPersonalities,
        'communication_style': _communicationStyle,
        'relationship_tone': _relationshipTone,
        'avatar_url': uploadedUrl,
      });

      if (mounted) {
        Navigator.pop(context, updatedCompanion);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCompanion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Companion?'),
        content: const Text('Are you sure you want to delete your AI Companion? This will also clear your chat history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _repository.deleteCompanion(widget.companion.id);
        if (mounted) {
          Navigator.pop(context, 'deleted');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit AI Companion')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickAndCropImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _selectedImage != null 
                                  ? FileImage(_selectedImage!) 
                                  : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null) as ImageProvider?,
                              child: _selectedImage == null && _avatarUrl == null 
                                  ? const Icon(Icons.person, size: 60, color: Colors.grey) 
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text('Companion Name', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 24),
                    const Text('Purpose', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _purpose,
                      items: _purposes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) => setState(() => _purpose = val!),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    const Text('Personality Traits', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _personalities.map((p) {
                        final isSelected = _selectedPersonalities.contains(p);
                        return FilterChip(
                          label: Text(p),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              selected ? _selectedPersonalities.add(p) : _selectedPersonalities.remove(p);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text('Communication Style', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _communicationStyle,
                      items: _styles.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _communicationStyle = val!),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    const Text('Relationship Tone', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _relationshipTone,
                      items: _tones.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setState(() => _relationshipTone = val!),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: _saveChanges,
                      child: const Text('SAVE CHANGES'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _deleteCompanion,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Center(child: Text('DELETE COMPANION')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
