import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'premium.dart';

class AskAnyUserScreen extends StatefulWidget {
  final String? userId;
  const AskAnyUserScreen({super.key, this.userId});

  @override
  State<AskAnyUserScreen> createState() => _AskAnyUserScreenState();
}

class _AskAnyUserScreenState extends State<AskAnyUserScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController questionController = TextEditingController();
  bool isAnonymous = false;
  String? selectedUserId;
  bool _isLoading = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      selectedUserId = widget.userId;
      _fetchUsername();
    }
  }

  Future<void> _fetchUsername() async {
    try {
      final res = await Supabase.instance.client.from('profiles').select('username').eq('id', selectedUserId!).maybeSingle();
      if (res != null && mounted) setState(() => usernameController.text = res['username'] ?? "");
    } catch (_) {}
  }

  @override
  void dispose() {
    usernameController.dispose();
    questionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<void> _sendQuestion() async {
    final text = questionController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      if (selectedUserId == null && usernameController.text.isNotEmpty) {
        String input = usernameController.text.trim().replaceFirst('@', '');
        final res = await supabase.from('profiles').select('id').eq('username', input).maybeSingle();
        if (res != null) selectedUserId = res['id'];
      }

      if (selectedUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final bool canAsk = await supabase.rpc('can_ask_question', params: {'uid': currentUser.id});
      if (!canAsk) {
        setState(() => _isLoading = false);
        // Show dialog...
        return;
      }

      String? imageUrl;
      if (_selectedImage != null) {
        final path = "questions/${DateTime.now().millisecondsSinceEpoch}.jpg";
        await supabase.storage.from('question-images').upload(path, _selectedImage!);
        imageUrl = supabase.storage.from('question-images').getPublicUrl(path);
      }

      await supabase.rpc('register_question', params: {'uid': currentUser.id});
      await supabase.from('questions').insert({
        'from_user': isAnonymous ? null : currentUser.id, 
        'to_user': selectedUserId, 
        'text': text,
        'is_anonymous': isAnonymous,
        'image_url': imageUrl,
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error sending question: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text("Ask a Question")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: usernameController,
              readOnly: widget.userId != null,
              decoration: const InputDecoration(hintText: "Username", prefixText: "@"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: questionController,
              minLines: 5,
              maxLines: null,
              decoration: const InputDecoration(hintText: "Type your question here..."),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                  label: const Text("Add Image"),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
                if (_selectedImage != null) ...[
                  const SizedBox(width: 12),
                  Stack(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_selectedImage!, height: 44, width: 44, fit: BoxFit.cover)),
                      Positioned(right: -8, top: -8, child: IconButton(icon: const Icon(Icons.cancel, size: 16), onPressed: () => setState(() => _selectedImage = null))),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text("Ask Anonymously"),
              value: isAnonymous,
              onChanged: (v) => setState(() => isAnonymous = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendQuestion,
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("SEND QUESTION"),
            ),
          ],
        ),
      ),
    );
  }
}
