import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user.dart';
import '../../services/meme_mania_service.dart';
import '../../services/block_service.dart';
import 'friend_selection_screen.dart';

class CreateMemeScreen extends StatefulWidget {
  const CreateMemeScreen({super.key});

  @override
  State<CreateMemeScreen> createState() => _CreateMemeScreenState();
}

class _CreateMemeScreenState extends State<CreateMemeScreen> {
  final _service = MemeManiaService();
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  
  File? _imageFile;
  List<AppUser> _selectedFriends = [];
  bool _isUploading = false;
  int _currentStep = 0; // 0: Select Image/Caption, 1: Select Friends

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _launchGame() async {
    if (_imageFile == null || _selectedFriends.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      await _service.createMemeGame(
        imageFile: _imageFile!,
        caption: _captionController.text,
        participantIds: _selectedFriends.map((f) => f.id).toList(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meme Battle Started! 😂')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(_currentStep == 0 ? "NEW MEME" : "TAG FRIENDS", style: const TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: Icon(_currentStep == 0 ? Icons.close : Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_currentStep == 0) Navigator.pop(context);
            else setState(() => _currentStep = 0);
          },
        ),
      ),
      body: _currentStep == 0 ? _buildUploadStep() : _buildFriendStep(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildUploadStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // IMAGE UPLOAD AREA
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16181D) : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                image: _imageFile != null
                    ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                    : null,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: _imageFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_rounded, size: 64, color: Color(0xFFF59E0B)),
                        const SizedBox(height: 16),
                        const Text('Select Meme Image', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text('Tap to browse gallery', style: TextStyle(color: Colors.grey.withOpacity(0.8))),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 32),
          // CAPTION EDITOR
          const Text("CAPTION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey)),
          const SizedBox(height: 12),
          TextField(
            controller: _captionController,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: "Add a funny context...",
              filled: true,
              fillColor: isDark ? const Color(0xFF16181D) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildFriendStep() {
    return GameFriendSelectionScreen(
      onContinue: (friends) {
        setState(() => _selectedFriends = friends);
        _launchGame();
      },
    );
  }

  Widget _buildBottomBar() {
    if (_currentStep == 1) return const SizedBox();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: _imageFile == null ? null : () => setState(() => _currentStep = 1),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 8,
            shadowColor: const Color(0xFFF59E0B).withOpacity(0.4),
          ),
          child: const Text("CHOOSE FRIENDS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
      ),
    );
  }
}
