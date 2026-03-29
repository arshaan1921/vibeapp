import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class ReportProblemScreen extends StatefulWidget {
  final String? reportedUserId;
  const ReportProblemScreen({super.key, this.reportedUserId});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  File? _selectedImage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<void> _submitReport() async {
    final reportText = _controller.text.trim();
    if (reportText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a description.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("User not authenticated");
      }

      String? imageUrl;

      if (_selectedImage != null) {
        try {
          final fileName = "report_${DateTime.now().millisecondsSinceEpoch}.png";
          await supabase.storage
              .from('report_screenshots')
              .upload(fileName, _selectedImage!);

          imageUrl = supabase.storage
              .from('report_screenshots')
              .getPublicUrl(fileName);
        } catch (e) {
          debugPrint("Screenshot upload failed: $e");
        }
      }

      final reportData = {
        'user_id': user.id,
        'message': reportText,
        'screenshot_url': imageUrl,
        'reported_user_id': widget.reportedUserId,
      };

      await supabase.from('reports').insert(reportData);

      try {
        const botToken = "8637680343:AAF7GFChAKkZquMj_Ptm_NDMSgVp4PnAryA";
        const chatId = "5519527890";
        const telegramUrl = "https://api.telegram.org/bot$botToken/sendMessage";

        final typeLabel = widget.reportedUserId != null ? "👤 User Report" : "🚨 Support Report";
        final message = "$typeLabel\n\n"
            "Reporter ID: ${user.id}\n"
            "${widget.reportedUserId != null ? "Reported User ID: ${widget.reportedUserId}\n" : ""}"
            "\nMessage:\n$reportText\n\n"
            "Screenshot:\n${imageUrl ?? "No screenshot attached"}";

        await http.post(
          Uri.parse(telegramUrl),
          body: {
            "chat_id": chatId,
            "text": message,
          },
        );
      } catch (e) {
        debugPrint("Telegram notification failed: $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report submitted successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUserReport = widget.reportedUserId != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isUserReport ? "REPORT USER" : "REPORT A PROBLEM"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUserReport ? "Why are you reporting this user?" : "Describe the problem",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                maxLines: 6,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: isUserReport ? "Please provide details about the violation..." : "Describe the problem...",
                  hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                  fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.attach_file, size: 20),
                label: const Text("Attach Screenshot"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.blueAccent : theme.primaryColor,
                  side: BorderSide(color: isDark ? Colors.blueAccent : theme.primaryColor),
                ),
              ),
              if (_selectedImage != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  child: Image.file(_selectedImage!, height: 120),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text("SUBMIT REPORT"),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
