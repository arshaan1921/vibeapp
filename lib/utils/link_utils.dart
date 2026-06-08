import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/profile.dart';

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

class LinkUtils {
  static Future<void> handleLinkClick(BuildContext context, LinkableElement link) async {
    if (link.url.startsWith('@')) {
      final username = link.url.substring(1).toLowerCase();
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('username', username)
            .maybeSingle();

        if (data != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileScreen(userId: data['id'])),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("User @$username not found")),
          );
        }
      } catch (e) {
        debugPrint('ERROR in handleLinkClick: $e');
      }
    } else {
      final Uri url = Uri.parse(link.url);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $url');
      }
    }
  }
}
