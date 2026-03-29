import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const EditProfileScreen({super.key, this.initialData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _avatarUrl;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _usernameController.text = widget.initialData!['username'] ?? '';
      _bioController.text = widget.initialData!['bio'] ?? '';
      _avatarUrl = widget.initialData!['avatar_url'];
    } else {
      _fetchProfile();
    }
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (data != null && mounted) {
          setState(() {
            _nameController.text = data['name'] ?? '';
            _usernameController.text = data['username'] ?? '';
            _bioController.text = data['bio'] ?? '';
            _avatarUrl = data['avatar_url'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          final storageStatus = await Permission.storage.request();
          if (!storageStatus.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Gallery permission denied")),
              );
            }
            return;
          }
        }
      }

      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim();
    
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username cannot be empty")),
      );
      return;
    }

    final usernameRegex = RegExp(r'^[a-z0-9_]+$');
    if (!usernameRegex.hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username can only contain lowercase letters, numbers, and underscores")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      String? imageUrl = _avatarUrl;

      if (_selectedImage != null) {
        setState(() => _isUploading = true);
        final fileExtension = _selectedImage!.path.split('.').last;
        final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        
        await Supabase.instance.client.storage.from('avatars').upload(
              fileName,
              _selectedImage!,
              fileOptions: const FileOptions(upsert: true),
            );
            
        imageUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(fileName);
        setState(() => _isUploading = false);
      }

      await Supabase.instance.client.from('profiles').update({
        'name': _nameController.text.trim(),
        'username': username,
        'bio': _bioController.text.trim(),
        'avatar_url': imageUrl,
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated!")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("EDIT PROFILE"),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                              backgroundImage: _selectedImage != null
                                  ? FileImage(_selectedImage!)
                                  : (_avatarUrl != null
                                      ? NetworkImage(_avatarUrl!)
                                      : null) as ImageProvider?,
                              child: _selectedImage == null && _avatarUrl == null
                                  ? const Icon(Icons.person,
                                      size: 55, color: Colors.white)
                                  : null,
                            ),
                            if (_isUploading)
                              const Positioned.fill(
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        ),
                        TextButton(
                          onPressed: _isUploading ? null : _pickImage,
                          child: const Text("Change Photo", 
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: "Name",
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      filled: true,
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    inputFormatters: [
                      LowerCaseTextFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: "Username",
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      filled: true,
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bioController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: "Bio",
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      filled: true,
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}
