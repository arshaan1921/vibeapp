import 'package:url_launcher/url_launcher.dart';

class LegalLinks {
  static const String privacyPolicyUrl =
      'https://sites.google.com/view/high5-app/privacy-policy';
  static const String termsConditionsUrl =
      'https://sites.google.com/view/high5-app/terms-conditions';

  static Future<void> launchPrivacyPolicy() async {
    final Uri url = Uri.parse(privacyPolicyUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $privacyPolicyUrl');
    }
  }

  static Future<void> launchTermsConditions() async {
    final Uri url = Uri.parse(termsConditionsUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $termsConditionsUrl');
    }
  }
}
