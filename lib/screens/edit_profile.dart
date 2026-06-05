import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  final _instagramController = TextEditingController();
  final _twitterController = TextEditingController();
  final _facebookController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _snapchatController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _telegramController = TextEditingController();
  final _gmailController = TextEditingController();
  bool _showSocialLinks = true;
  bool _showGmail = false;
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
      _instagramController.text = widget.initialData!['instagram_handle'] ?? '';
      _twitterController.text = widget.initialData!['twitter_handle'] ?? '';
      _facebookController.text = widget.initialData!['facebook_handle'] ?? '';
      _linkedinController.text = widget.initialData!['linkedin_handle'] ?? '';
      _youtubeController.text = widget.initialData!['youtube_handle'] ?? '';
      _tiktokController.text = widget.initialData!['tiktok_handle'] ?? '';
      _snapchatController.text = widget.initialData!['snapchat_handle'] ?? '';
      _whatsappController.text = widget.initialData!['whatsapp_handle'] ?? '';
      _telegramController.text = widget.initialData!['telegram_handle'] ?? '';
      _gmailController.text = widget.initialData!['gmail_address'] ?? '';
      _showSocialLinks = widget.initialData!['show_social_links'] ?? true;
      _showGmail = widget.initialData!['show_gmail'] ?? false;
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
            _instagramController.text = data['instagram_handle'] ?? '';
            _twitterController.text = data['twitter_handle'] ?? '';
            _facebookController.text = data['facebook_handle'] ?? '';
            _linkedinController.text = data['linkedin_handle'] ?? '';
            _youtubeController.text = data['youtube_handle'] ?? '';
            _tiktokController.text = data['tiktok_handle'] ?? '';
            _snapchatController.text = data['snapchat_handle'] ?? '';
            _whatsappController.text = data['whatsapp_handle'] ?? '';
            _telegramController.text = data['telegram_handle'] ?? '';
            _gmailController.text = data['gmail_address'] ?? '';
            _showSocialLinks = data['show_social_links'] ?? true;
            _showGmail = data['show_gmail'] ?? false;
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
    _instagramController.dispose();
    _twitterController.dispose();
    _facebookController.dispose();
    _linkedinController.dispose();
    _youtubeController.dispose();
    _tiktokController.dispose();
    _snapchatController.dispose();
    _whatsappController.dispose();
    _telegramController.dispose();
    _gmailController.dispose();
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

      final gmail = _gmailController.text.trim();
      if (gmail.isNotEmpty) {
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(gmail)) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please enter a valid email address")),
          );
          return;
        }
      }

      final youtube = _youtubeController.text.trim();
      if (youtube.isNotEmpty) {
        // Validate format: @username or youtube.com/@username or https://www.youtube.com/@username
        final youtubeRegex = RegExp(r'^(@[a-zA-Z0-9_\-\.]+|(https?:\/\/)?(www\.)?youtube\.com\/@[a-zA-Z0-9_\-\.]+)$');
        if (!youtubeRegex.hasMatch(youtube)) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please enter a valid YouTube channel (@handle or URL)")),
          );
          return;
        }
      }

      await Supabase.instance.client.from('profiles').update({
        'name': _nameController.text.trim(),
        'username': username,
        'bio': _bioController.text.trim(),
        'avatar_url': _avatarUrl,
        'instagram_handle': _instagramController.text.trim(),
        'twitter_handle': _twitterController.text.trim(),
        'facebook_handle': _facebookController.text.trim(),
        'linkedin_handle': _linkedinController.text.trim(),
        'youtube_handle': _youtubeController.text.trim(),
        'tiktok_handle': _tiktokController.text.trim(),
        'snapchat_handle': _snapchatController.text.trim(),
        'whatsapp_handle': _whatsappController.text.trim(),
        'telegram_handle': _telegramController.text.trim(),
        'gmail_address': gmail,
        'show_social_links': _showSocialLinks,
        'show_gmail': _showGmail,
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

  Widget _buildSocialLinksSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.link, size: 20),
            SizedBox(width: 8),
            Text(
              "SOCIAL LINKS",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSocialField(
          controller: _instagramController,
          label: "Instagram",
          icon: FontAwesomeIcons.instagram,
          isDark: isDark,
          hint: "username or URL",
        ),
        const SizedBox(height: 12),
        _buildSocialField(
          controller: _twitterController,
          label: "X (Twitter)",
          icon: FontAwesomeIcons.xTwitter,
          isDark: isDark,
          hint: "username or URL",
        ),
        const SizedBox(height: 12),
        _buildSocialField(
          controller: _facebookController,
          label: "Facebook",
          icon: FontAwesomeIcons.facebook,
          isDark: isDark,
          hint: "username or URL",
        ),
        const SizedBox(height: 12),
        _buildSocialField(
          controller: _linkedinController,
          label: "LinkedIn",
          icon: FontAwesomeIcons.linkedin,
          isDark: isDark,
          hint: "username or URL",
        ),
        const SizedBox(height: 12),
        _buildSocialField(
          controller: _youtubeController,
          label: "YouTube Channel",
          icon: FontAwesomeIcons.youtube,
          isDark: isDark,
          hint: "@MrBeast or https://youtube.com/@MrBeast",
        ),
        const SizedBox(height: 12),
        _buildSocialField(
          controller: _tiktokController,
          label: "TikTok",
          icon: FontAwesomeIcons.tiktok,
          isDark: isDark,
          hint: "username or URL",
        ),
        const SizedBox(height: 12),
        _buildSocialField(
          controller: _snapchatController,
          label: "Snapchat",
          icon: FontAwesomeIcons.snapchat,
          isDark: isDark,
          hint: "username or URL",
        ),
        const SizedBox(height: 12),
        _buildSocialField(
          controller: _whatsappController,
          label: "WhatsApp",
          icon: FontAwesomeIcons.whatsapp,
          isDark: isDark,
          hint: "phone number or link",
        ),
        const SizedBox(height: 12),
        _buildSocialField(
          controller: _telegramController,
          label: "Telegram",
          icon: FontAwesomeIcons.telegram,
          isDark: isDark,
          hint: "username or link",
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Show social links publicly", 
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          value: _showSocialLinks,
          onChanged: (val) => setState(() => _showSocialLinks = val),
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildContactInfoSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.contact_mail_outlined, size: 20),
            SizedBox(width: 8),
            Text(
              "CONTACT INFORMATION",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSocialField(
          controller: _gmailController,
          label: "Gmail",
          icon: FontAwesomeIcons.envelope,
          isDark: isDark,
          hint: "example@gmail.com",
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Show contact information publicly", 
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          value: _showGmail,
          onChanged: (val) => setState(() => _showGmail = val),
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildSocialField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: isDark ? Colors.white70 : Colors.black54),
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        filled: true,
        isDense: true,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
        ),
      ),
    );
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
                  _buildSocialLinksSection(isDark),
                  const SizedBox(height: 32),
                  _buildContactInfoSection(isDark),
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
