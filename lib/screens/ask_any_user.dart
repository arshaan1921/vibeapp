import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/premium_utils.dart';
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
  final List<String> _forbiddenWords = ["hate", "kill", "die", "ugly"];
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
      final res = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', selectedUserId!)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          usernameController.text = res['username'] ?? "";
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    usernameController.dispose();
    questionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Daily Limit Reached"),
        content: const Text("You have reached today's question limit. Upgrade to premium for unlimited questions."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            child: const Text("Upgrade to Premium"),
          ),
        ],
      ),
    );
  }

  Future<void> _sendQuestion() async {
    final text = questionController.text.trim();
    if (text.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a question or attach an image")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Fetch user profile to check plan
      final profile = await supabase.from('profiles').select('premium_plan').eq('id', currentUser.id).single();
      final plan = profile['premium_plan'] ?? 'free';

      // 1. Check permissions / limits
      final bool canAsk = await supabase.rpc('can_ask_question', params: {'uid': currentUser.id});

      if (!canAsk) {
        // Only show warning for green and free users
        if (mounted && (plan == 'free' || plan == 'green')) {
          _showLimitReachedDialog();
        }
        setState(() => _isLoading = false);
        return;
      }

      // Resolve selectedUserId if needed
      if (selectedUserId == null && usernameController.text.isNotEmpty) {
        final res = await supabase
            .from('profiles')
            .select('id')
            .eq('username', usernameController.text.trim())
            .maybeSingle();
        if (res != null) {
          selectedUserId = res['id'];
        }
      }

      if (selectedUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Select a user")),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Forbidden words check
      bool hasForbiddenWord = _forbiddenWords.any((word) => text.toLowerCase().contains(word));
      if (hasForbiddenWord) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Be Kind"),
              content: const Text("Please keep V 1 B E positive. Your message contains words that are not allowed."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
              ],
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      String? imageUrl;

      // 2. Upload Image if exists
      if (_selectedImage != null) {
        final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
        final path = "questions/$fileName";
        
        await supabase.storage
            .from('question-images')
            .upload(path, _selectedImage!);

        imageUrl = supabase.storage
            .from('question-images')
            .getPublicUrl(path);
      }

      // 3. Register question / use booster
      final int dailyRemaining = await supabase.rpc('get_remaining_questions', params: {'uid': currentUser.id});
      if (dailyRemaining > 0) {
        await supabase.rpc('register_question', params: {'uid': currentUser.id});
      } else {
        await supabase.rpc('use_booster', params: {'uid': currentUser.id});
      }

      // 4. Insert question
      await supabase.from('questions').insert({
        'from_user': isAnonymous ? null : currentUser.id, 
        'to_user': selectedUserId, 
        'text': text,
        'is_anonymous': isAnonymous,
        'image_url': imageUrl,
      });

      // 5. Trigger push notification
      try {
        final session = supabase.auth.currentSession;
        final accessToken = session?.accessToken;

        if (accessToken != null) {
          await supabase.functions.invoke(
            'supabase-functions-new-send-push-notification',
            body: {
              "user_id": selectedUserId,
              "title": "New Question 👀",
              "body": "Someone asked you a question on V1BE",
              "data": {
                "type": "question"
              }
            },
            headers: {
              "Authorization": "Bearer $accessToken",
            },
          );
        }
      } catch (e) {
        debugPrint("Push failed: $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Question sent")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("ASK A QUESTION"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ask a Question",
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.userId == null)
                TextField(
                  controller: usernameController,
                  style: TextStyle(color: textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: "Username",
                    hintStyle: TextStyle(color: textTheme.bodySmall?.color),
                    fillColor: theme.cardColor,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.group_rounded, color: theme.iconTheme.color),
                      onPressed: () async {
                        final res = await Supabase.instance.client
                            .from('profiles')
                            .select('id, username')
                            .limit(10);

                        if (!mounted) return;

                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (_) {
                            final users = List<Map<String, dynamic>>.from(res);
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  leading: const CircleAvatar(
                                    radius: 18,
                                    child: Icon(Icons.person, size: 20),
                                  ),
                                  title: Text(
                                    users[index]['username'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      usernameController.text = users[index]['username'];
                                      selectedUserId = users[index]['id'];
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                )
              else
                TextField(
                  controller: usernameController,
                  readOnly: true,
                  style: TextStyle(color: textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: "Username",
                    hintStyle: TextStyle(color: textTheme.bodySmall?.color),
                    fillColor: theme.cardColor,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: questionController,
                minLines: 4,
                maxLines: null,
                style: TextStyle(color: textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: "Type your question...",
                  hintStyle: TextStyle(color: textTheme.bodySmall?.color),
                  fillColor: theme.cardColor,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // ATTACH IMAGE BUTTON
              TextButton.icon(
                onPressed: _isLoading ? null : _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text("Attach Image"),
                style: TextButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  padding: EdgeInsets.zero,
                ),
              ),

              // IMAGE PREVIEW
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Stack(
                    children: [
                      Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _removeImage,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Ask anonymously", 
                    style: TextStyle(
                      fontSize: 14,
                      color: textTheme.bodyMedium?.color,
                    ),
                  ),
                  Switch(
                    value: isAnonymous,
                    onChanged: (val) => setState(() => isAnonymous = val),
                    activeColor: theme.primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendQuestion,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("SEND QUESTION", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
