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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRemainingCount();
  }

  Future<void> _loadRemainingCount() async {
    if (!mounted) return;
    try {
      // Force refresh by bypassing any potential local state
      // Always fetches latest profile data from Supabase
      final count = await _repository.getRemainingAiMessages();
      debugPrint('AI Remaining Messages (Fetched): $count');

      if (mounted) {
        setState(() {
          _remainingMessages = count;
        });
      }
    } catch (e) {
      debugPrint("Error loading AI count: $e");
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadMessages(),
      _loadRemainingCount(),
    ]);
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
      await _repository.saveMessage(companionId: _companion.id, message: text, sender: 'user');
      final memories = await _repository.getMemories(_companion.id);

      final aiReply = await _aiService.getAiResponse(
        companion: _companion,
        memories: memories,
        userMessage: text,
        history: _messages.length > 10 
            ? _messages.sublist(_messages.length - 10).map((m) => {'sender': m.sender, 'message': m.message}).toList()
            : _messages.map((m) => {'sender': m.sender, 'message': m.message}).toList(),
      );

      await _repository.registerAiUsage();
      final freshCount = await _repository.getRemainingAiMessages();
      debugPrint('AI Remaining Messages (Post-Usage): $freshCount');

      if (mounted) {
        setState(() {
          _remainingMessages = freshCount;
        });
      }

      await _repository.saveMessage(companionId: _companion.id, message: aiReply, sender: 'ai');

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
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  void _showAiLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limit Reached'),
        content: const Text("You've reached your AI chat limit for today."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('LATER')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BoosterPackScreen()));
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
        titleSpacing: 0,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _openSettings(),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: _companion.avatarUrl != null ? NetworkImage(_companion.avatarUrl!) : null,
                    child: _companion.avatarUrl == null ? const Icon(Icons.auto_awesome, size: 20) : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_companion.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111111))),
                  Text(
                    'Online • $_remainingMessages messages left',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF111111)), onPressed: _openSettings),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Personality Indicators
            if (_companion.personalities.isNotEmpty)
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _companion.personalities.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _companion.personalities[index],
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => ChatBubble(message: _messages[index]),
                      ),
                    ),
            ),
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${_companion.name} is thinking...', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                ),
              ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditAiCompanionScreen(companion: _companion)),
    );
    if (result == 'deleted' && mounted) {
      widget.onDeleted?.call();
    } else if (result is AiCompanion && mounted) {
      setState(() => _companion = result);
      _loadRemainingCount(); // Refresh count when returning from settings
    } else if (mounted) {
      _loadRemainingCount(); // Refresh count anyway in case something changed
    }
  }

  Widget _buildMessageInput() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Message...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sendMessage,
              icon: Icon(Icons.arrow_upward_rounded, color: theme.colorScheme.primary),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
