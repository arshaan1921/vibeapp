import 'package:flutter/material.dart';
import '../models/ai_companion.dart';
import '../models/ai_message.dart';
import '../repository/ai_companion_repository.dart';
import '../../../services/ai_companion_service.dart';
import '../widgets/chat_bubble.dart';
import 'edit_ai_companion_screen.dart';
import '../../../screens/booster_pack_screen.dart';
import '../../../screens/premium.dart';

class AiChatScreen extends StatefulWidget {
  final AiCompanion companion;
  final VoidCallback? onDeleted;

  const AiChatScreen({super.key, required this.companion, this.onDeleted});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _repository = AiCompanionRepository();
  final _aiService = AiCompanionService();

  List<AiMessage> _messages = [];
  bool _isLoading = true;
  bool _isTyping = false;
  int _remainingMessages = 0;
  late AiCompanion _companion;

  @override
  void initState() {
    super.initState();
    _companion = widget.companion;
    _loadMessages();
    _loadRemainingCount();
  }

  Future<void> _loadRemainingCount() async {
    try {
      final count = await _repository.getRemainingAiMessages();
      if (mounted) {
        setState(() {
          _remainingMessages = count;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await _repository.getMessages(_companion.id);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // 1. Check message limit (Using new RPC system)
    final bool canSend = await _repository.canSendAiMessage();
    if (!canSend) {
      _showAiLimitReachedDialog();
      return;
    }

    _messageController.clear();
    final userMsg = AiMessage(
      id: '',
      userId: _companion.userId,
      companionId: _companion.id,
      message: text,
      sender: 'user',
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      // Save user message
      await _repository.saveMessage(
        companionId: _companion.id,
        message: text,
        sender: 'user',
      );

      // Get memories for context
      final memories = await _repository.getMemories(_companion.id);

      // Get AI response
      final aiReply = await _aiService.getAiResponse(
        companion: _companion,
        memories: memories,
        userMessage: text,
        history: _messages.length > 10 
            ? _messages.sublist(_messages.length - 10).map((m) => {'sender': m.sender, 'message': m.message}).toList()
            : _messages.map((m) => {'sender': m.sender, 'message': m.message}).toList(),
      );

      // 2. Register usage ONLY after successful AI reply
      await _repository.registerAiUsage();
      _loadRemainingCount();

      // Save AI message
      await _repository.saveMessage(
        companionId: _companion.id,
        message: aiReply,
        sender: 'ai',
      );

      final aiMsg = AiMessage(
        id: '',
        userId: _companion.userId,
        companionId: _companion.id,
        message: aiReply,
        sender: 'ai',
        createdAt: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _messages.add(aiMsg);
          _isTyping = false;
          // Optimistically update count
          _companion = AiCompanion(
            id: _companion.id,
            userId: _companion.userId,
            name: _companion.name,
            purpose: _companion.purpose,
            personalities: _companion.personalities,
            communicationStyle: _companion.communicationStyle,
            relationshipTone: _companion.relationshipTone,
            avatarUrl: _companion.avatarUrl,
            createdAt: _companion.createdAt,
            dailyMessageCount: _companion.dailyMessageCount + 1,
            isPremium: _companion.isPremium,
            messageLimit: _companion.messageLimit,
            lastResetDate: _companion.lastResetDate,
          );
        });
        _scrollToBottom();
      }

      // TODO: Background task to extract and save memories from the conversation
      _extractMemories(text, aiReply);

    } catch (e) {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  void _extractMemories(String userMsg, String aiReply) {
    // Basic logic to see if user shared something personal
    // In a real app, you might use AI to extract these
    // For now, it's a placeholder for the memory system
  }

  void _showAiLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Daily Limit Reached'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("You've reached your AI chat limit for today. ❤️"),
            const SizedBox(height: 16),
            const Text("Unlock more chats with a booster pack or upgrade your plan!", style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('MAYBE LATER', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BoosterPackScreen()),
              );
            },
            child: const Text('GET BOOSTERS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(_companion.name),
            Text(
              'AI Messages Left: $_remainingMessages',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditAiCompanionScreen(companion: _companion),
                ),
              );
              
              if (result == 'deleted' && mounted) {
                widget.onDeleted?.call();
              } else if (result is AiCompanion && mounted) {
                setState(() {
                  _companion = result;
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: _companion.avatarUrl != null
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(_companion.avatarUrl!),
                    )
                  : const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => ChatBubble(message: _messages[index]),
                  ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Typing...', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Say something...',
                border: InputBorder.none,
                fillColor: Colors.transparent,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            onPressed: _sendMessage,
            icon: Icon(Icons.send, color: theme.primaryColor),
          ),
        ],
      ),
    );
  }
}
