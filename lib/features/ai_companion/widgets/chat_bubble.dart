import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../screens/profile.dart';
import '../models/ai_message.dart';

class ChatBubble extends StatelessWidget {
  final AiMessage message;

  const ChatBubble({super.key, required this.message});

  Future<void> _handleUsernameTap(BuildContext context, String username) async {
    try {
      final cleanUsername = username.startsWith('@') ? username.substring(1) : username;
      final supabase = Supabase.instance.client;
      final data = await supabase.from('profiles').select('id').eq('username', cleanUsername).maybeSingle();

      if (data != null && context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: data['id'])));
      }
    } catch (_) {}
  }

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
                    if (link.url.startsWith('@')) {
                      _handleUsernameTap(context, link.url);
                    } else {
                      final uri = Uri.parse(link.url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
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

class UserLinkifier extends Linkifier {
  const UserLinkifier();

  @override
  List<LinkifyElement> parse(List<LinkifyElement> elements, LinkifyOptions options) {
    final list = <LinkifyElement>[];
    final regex = RegExp(r"@[a-zA-Z0-9_]+", multiLine: true);

    for (var element in elements) {
      if (element is TextElement) {
        final matches = regex.allMatches(element.text);
        if (matches.isEmpty) {
          list.add(element);
        } else {
          int lastIndex = 0;
          for (var match in matches) {
            if (match.start > lastIndex) {
              list.add(TextElement(element.text.substring(lastIndex, match.start)));
            }
            list.add(LinkableElement(match.group(0)!, match.group(0)!));
            lastIndex = match.end;
          }
          if (lastIndex < element.text.length) {
            list.add(TextElement(element.text.substring(lastIndex)));
          }
        }
      } else {
        list.add(element);
      }
    }
    return list;
  }
}
