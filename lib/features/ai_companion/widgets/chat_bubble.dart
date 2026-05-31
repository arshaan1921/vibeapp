import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../screens/public_profile.dart';
import '../models/ai_message.dart';

class ChatBubble extends StatelessWidget {
  final AiMessage message;

  const ChatBubble({super.key, required this.message});

  Future<void> _handleUsernameTap(BuildContext context, String username) async {
    try {
      // Remove @ if present
      final cleanUsername = username.startsWith('@') ? username.substring(1) : username;
      
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('profiles')
          .select('id')
          .eq('username', cleanUsername)
          .maybeSingle();

      if (data != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PublicProfileScreen(userId: data['id']),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User @$cleanUsername not found')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error finding user')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: message.message));
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Text copied'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 1),
              width: 150,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isUser ? theme.primaryColor : theme.cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 0),
              bottomRight: Radius.circular(isUser ? 0 : 16),
            ),
            border: isUser ? null : Border.all(color: theme.dividerColor),
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Linkify(
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
                text: message.message,
                linkifiers: [
                  const EmailLinkifier(),
                  const UrlLinkifier(),
                  _PhoneNumberLinkifier(),
                  _UsernameLinkifier(),
                ],
                style: TextStyle(
                  color: isUser ? Colors.white : theme.textTheme.bodyLarge?.color,
                  fontSize: 15,
                ),
                linkStyle: TextStyle(
                  color: isUser ? Colors.white.withOpacity(0.9) : theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  color: isUser ? Colors.white70 : Colors.grey,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}

class _UsernameLinkifier extends Linkifier {
  @override
  List<LinkifyElement> parse(List<LinkifyElement> elements, LinkifyOptions options) {
    final list = <LinkifyElement>[];
    final regex = RegExp(r'@[a-zA-Z0-9_.]+');

    for (final element in elements) {
      if (element is TextElement) {
        final matches = regex.allMatches(element.text);
        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            list.add(TextElement(element.text.substring(lastIndex, match.start)));
          }
          list.add(LinkableElement(match.group(0)!, match.group(0)!));
          lastIndex = match.end;
        }
        if (lastIndex < element.text.length) {
          list.add(TextElement(element.text.substring(lastIndex)));
        }
      } else {
        list.add(element);
      }
    }
    return list;
  }
}

class _PhoneNumberLinkifier extends Linkifier {
  @override
  List<LinkifyElement> parse(List<LinkifyElement> elements, LinkifyOptions options) {
    final list = <LinkifyElement>[];
    final regex = RegExp(r'\+?[0-9]{10,15}');

    for (final element in elements) {
      if (element is TextElement) {
        final matches = regex.allMatches(element.text);
        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            list.add(TextElement(element.text.substring(lastIndex, match.start)));
          }
          list.add(LinkableElement(match.group(0)!, 'tel:${match.group(0)!}'));
          lastIndex = match.end;
        }
        if (lastIndex < element.text.length) {
          list.add(TextElement(element.text.substring(lastIndex)));
        }
      } else {
        list.add(element);
      }
    }
    return list;
  }
}
