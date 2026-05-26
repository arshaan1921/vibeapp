import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../utils/image_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'onboarding/onboarding.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final bool isSignupFlow;
  
  const EditProfileScreen({
    super.key, 
    this.initialData,
    this.isSignupFlow = false,
  });

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

  bool _isPickingImage = false;

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text("Take Photo"),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Choose from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.gallery);
                },
              ),
              if (_avatarUrl != null || _selectedImage != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text("Remove Photo", style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                      _avatarUrl = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        // Increased delay to 500ms for better Android activity lifecycle handling
        await Future.delayed(const Duration(milliseconds: 500));
        await _cropImage(image.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _cropImage(String path) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: const Color(0xFF0A3321),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFFFFD700),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
            // Removed statusBarColor to let the CustomUCropTheme handle it with fitsSystemWindows
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        final file = File(croppedFile.path);
        setState(() {
          _selectedImage = file;
        });
        
        // Ensure the cropper activity is completely closed and cleaned up 
        // before starting the upload which might trigger more state changes
        await Future.delayed(const Duration(milliseconds: 200));
        await _uploadCroppedImage(file);
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
    }
  }

  Future<void> _uploadCroppedImage(File file) async {
    setState(() => _isUploading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final fileExtension = file.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      
      await Supabase.instance.client.storage.from('avatars').upload(
            fileName,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
          
      final imageUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      if (mounted) {
        setState(() {
          _avatarUrl = imageUrl;
          _selectedImage = null; // We use the URL now
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo uploaded!")),
        );
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload failed. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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

      await Supabase.instance.client.from('profiles').update({
        'name': _nameController.text.trim(),
        'username': username,
        'bio': _bioController.text.trim(),
        'avatar_url': _avatarUrl,
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated!")),
        );
        
        if (widget.isSignupFlow) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        } else {
          Navigator.pop(context, true);
        }
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
        title: Text(widget.isSignupFlow ? "COMPLETE PROFILE" : "EDIT PROFILE"),
        automaticallyImplyLeading: !widget.isSignupFlow,
        leading: widget.isSignupFlow ? null : IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
                            GestureDetector(
                              onTap: () {
                                if (_selectedImage == null && _avatarUrl != null) {
                                  ImageUtils.showImagePreview(context, _avatarUrl);
                                }
                              },
                              child: CircleAvatar(
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
                            ),
                            if (_isUploading)
                              const Positioned.fill(
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                  const SizedBox(height: 32),
                  if (widget.isSignupFlow)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _isLoading ? null : _saveProfile,
                        child: const Text("SAVE & CONTINUE"),
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
