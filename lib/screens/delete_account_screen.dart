import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _pendingRequest;

  // Reusing Telegram Config from report_problem_screen.dart
  static const String _botToken = "8637680343:AAF7GFChAKkZquMj_Ptm_NDMSgVp4PnAryA";
  static const String _chatId = "5519527890";
  static const String _telegramUrl = "https://api.telegram.org/bot$_botToken/sendMessage";

  @override
  void initState() {
    super.initState();
    _fetchExistingRequest();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchExistingRequest() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('delete_requests')
          .select()
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .maybeSingle();

      setState(() {
        _pendingRequest = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching delete request: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRequest() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a reason.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final now = DateTime.now();
      final deleteAt = now.add(const Duration(hours: 72));

      await Supabase.instance.client.from('delete_requests').insert({
        'user_id': user.id,
        'reason': reason,
        'status': 'pending',
        'created_at': now.toIso8601String(),
        'delete_at': deleteAt.toIso8601String(),
      });

      // Send Telegram notification
      await _sendTelegramNotification(
        "🚨 DELETE ACCOUNT REQUEST\n\n"
        "User ID: ${user.id}\n"
        "Reason: $reason\n"
        "Time: ${now.toLocal()}"
      );

      await _fetchExistingRequest();
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

  Future<void> _cancelRequest() async {
    if (_pendingRequest == null) return;

    setState(() => _isSubmitting = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final now = DateTime.now();

      await Supabase.instance.client
          .from('delete_requests')
          .update({
            'status': 'cancelled',
            'cancelled_at': now.toIso8601String(),
          })
          .eq('id', _pendingRequest!['id']);

      // Send Telegram notification
      await _sendTelegramNotification(
        "❌ DELETE REQUEST CANCELLED\n\n"
        "User ID: ${user.id}\n"
        "Reason: ${_pendingRequest!['reason']}\n"
        "Cancelled At: ${now.toLocal()}"
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Your deletion request has been cancelled.")),
        );
      }

      await _fetchExistingRequest();
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

  Future<void> _sendTelegramNotification(String message) async {
    try {
      await http.post(
        Uri.parse(_telegramUrl),
        body: {
          "chat_id": _chatId,
          "text": message,
        },
      );
    } catch (e) {
      debugPrint("Telegram notification failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "DELETE ACCOUNT",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: _pendingRequest != null 
                    ? _buildConfirmationUI() 
                    : _buildRequestForm(),
              ),
            ),
    );
  }

  Widget _buildRequestForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Reason for leaving",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reasonController,
          maxLines: 6,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: "Tell us why you want to delete your account...",
            hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    "SUBMIT DELETE REQUEST",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.hourglass_empty_rounded, size: 80, color: Colors.orange),
          const SizedBox(height: 24),
          const Text(
            "Request Pending",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            "Your account will be deleted in 72 hours. You can cancel this request before deletion.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : _cancelRequest,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                    )
                  : const Text(
                      "CANCEL REQUEST",
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
