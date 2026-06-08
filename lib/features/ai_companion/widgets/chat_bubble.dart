import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../screens/profile.dart';
import '../../../utils/link_utils.dart';
import '../models/ai_message.dart';

class ChatBubble extends StatelessWidget {
  final AiMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: message.message));
            HapticFeedback.lightImpact();
          },
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: isUser 
                  ? theme.colorScheme.primary 
                  : (theme.brightness == Brightness.light ? Colors.black.withOpacity(0.04) : Colors.white.withOpacity(0.08)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Linkify(
                  text: message.message,
                  linkifiers: const [
                    UrlLinkifier(),
                    EmailLinkifier(),
                    UserLinkifier(),
                  ],
                  onOpen: (link) async {
                    await LinkUtils.handleLinkClick(context, link);
                  },
                  style: TextStyle(
                    color: isUser ? Colors.white : theme.textTheme.bodyLarge?.color,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  linkStyle: TextStyle(
                    color: isUser ? Colors.white.withOpacity(0.9) : (theme.brightness == Brightness.dark ? Colors.lightBlueAccent : theme.colorScheme.primary),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: (isUser ? Colors.white : theme.textTheme.bodySmall?.color)?.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}
