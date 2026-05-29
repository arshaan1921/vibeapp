import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../repository/ai_companion_repository.dart';
import 'ai_chat_screen.dart';

class CreateAiCompanionScreen extends StatefulWidget {
  const CreateAiCompanionScreen({super.key});

  @override
  State<CreateAiCompanionScreen> createState() => _CreateAiCompanionScreenState();
}

class _CreateAiCompanionScreenState extends State<CreateAiCompanionScreen> {
  final PageController _pageController = PageController();
  final _repository = AiCompanionRepository();
  final ImagePicker _picker = ImagePicker();
  
  int _currentStep = 0;
  bool _isLoading = false;
  File? _selectedImage;

  // Form Data
  String _name = '';
  String _purpose = '';
  List<String> _selectedPersonalities = [];
  String _communicationStyle = '';
  String _relationshipTone = '';
  String? _avatarUrl;

  final List<String> _purposes = [
    'Friend 👋',
    'Girlfriend ❤️',
    'Boyfriend 💙',
    'Emotional Support 😌',
    'Motivator 🎯',
    'Funny Bestie 😂',
  ];

  final List<String> _personalities = [
    'Sweet', 'Caring', 'Funny', 'Savage', 'Romantic',
    'Protective', 'Calm', 'Confident', 'Introvert', 'Extrovert'
  ];

  final List<String> _styles = [
    'Cute texting',
    'Casual texting',
    'Deep conversations',
    'Short replies',
    'Long detailed replies',
    'Gen Z style',
    'Formal',
  ];

  final List<String> _tones = [
    'Friendly only',
    'Slightly flirty',
    'Romantic',
    'Deep emotional',
  ];

  void _nextStep() {
    if (_currentStep < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    try {
      String? uploadedUrl;
      if (_selectedImage != null) {
        uploadedUrl = await _repository.uploadAvatar(_selectedImage!);
      }

      final companion = await _repository.createCompanion({
        'name': _name,
        'purpose': _purpose,
        'personalities': _selectedPersonalities,
        'communication_style': _communicationStyle,
        'relationship_tone': _relationshipTone,
        'avatar_url': uploadedUrl ?? _avatarUrl,
      });

      if (mounted) {
        Navigator.pop(context, companion);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating companion: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create AI Companion'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _prevStep,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                LinearProgressIndicator(
                  value: (_currentStep + 1) / 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildNameStep(),
                      _buildPurposeStep(),
                      _buildPersonalityStep(),
                      _buildStyleStep(),
                      _buildToneStep(),
                      _buildAvatarStep(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isLoading ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: ElevatedButton(
            onPressed: _canGoNext() ? _nextStep : null,
            child: Text(_currentStep == 5 ? 'CREATE COMPANION' : 'NEXT'),
          ),
        ),
      ),
    );
  }

  bool _canGoNext() {
    switch (_currentStep) {
      case 0: return _name.trim().isNotEmpty;
      case 1: return _purpose.isNotEmpty;
      case 2: return _selectedPersonalities.isNotEmpty;
      case 3: return _communicationStyle.isNotEmpty;
      case 4: return _relationshipTone.isNotEmpty;
      case 5: return true;
      default: return false;
    }
  }

  Widget _buildStepContainer({required String title, required String subtitle, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 32),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildNameStep() {
    return _buildStepContainer(
      title: 'What do you want to call your companion?',
      subtitle: 'Give your AI a special name.',
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Enter name (e.g. Luna, Zara)',
          border: OutlineInputBorder(),
        ),
        onChanged: (val) => setState(() => _name = val),
      ),
    );
  }

  Widget _buildPurposeStep() {
    return _buildStepContainer(
      title: 'What is their purpose?',
      subtitle: 'Choose how they will relate to you.',
      child: ListView.builder(
        itemCount: _purposes.length,
        itemBuilder: (context, index) {
          final p = _purposes[index];
          final isSelected = _purpose == p;
          return _buildSelectableTile(p, isSelected, () => setState(() => _purpose = p));
        },
      ),
    );
  }

  Widget _buildPersonalityStep() {
    return _buildStepContainer(
      title: 'What is their personality?',
      subtitle: 'Select multiple traits.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _personalities.map((p) {
          final isSelected = _selectedPersonalities.contains(p);
          return FilterChip(
            label: Text(p),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedPersonalities.add(p);
                } else {
                  _selectedPersonalities.remove(p);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStyleStep() {
    return _buildStepContainer(
      title: 'Communication Style',
      subtitle: 'How should they talk to you?',
      child: ListView.builder(
        itemCount: _styles.length,
        itemBuilder: (context, index) {
          final s = _styles[index];
          final isSelected = _communicationStyle == s;
          return _buildSelectableTile(s, isSelected, () => setState(() => _communicationStyle = s));
        },
      ),
    );
  }

  Widget _buildToneStep() {
    return _buildStepContainer(
      title: 'Relationship Tone',
      subtitle: 'Set the vibe of your relationship.',
      child: ListView.builder(
        itemCount: _tones.length,
        itemBuilder: (context, index) {
          final t = _tones[index];
          final isSelected = _relationshipTone == t;
          return _buildSelectableTile(t, isSelected, () => setState(() => _relationshipTone = t));
        },
      ),
    );
  }

  Widget _buildAvatarStep() {
    return _buildStepContainer(
      title: 'Companion Avatar',
      subtitle: 'Upload an image or use default.',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.upload),
            label: const Text('Upload Image'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableTile(String text, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
              width: 2,
            ),
            color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.05) : null,
          ),
          child: Row(
            children: [
              Expanded(child: Text(text, style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
              if (isSelected) Icon(Icons.check_circle, color: Theme.of(context).primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
