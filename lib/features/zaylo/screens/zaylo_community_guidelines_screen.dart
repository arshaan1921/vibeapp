import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZayloCommunityGuidelinesScreen extends StatelessWidget {
  const ZayloCommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Community Guidelines', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGuideline(
              'Respect Others',
              'Treat everyone with kindness and respect. We are a community of diverse individuals.',
              Icons.favorite_rounded,
            ),
            _buildGuideline(
              'No Harassment',
              'Harassment, bullying, or intimidation of any kind is strictly prohibited.',
              Icons.gavel_rounded,
            ),
            _buildGuideline(
              'No Nudity',
              'Posting or showing sexual content or nudity is not allowed and will result in a permanent ban.',
              Icons.visibility_off_rounded,
            ),
            _buildGuideline(
              'No Hate Speech',
              'We do not tolerate hate speech based on race, religion, gender, or orientation.',
              Icons.do_not_disturb_on_rounded,
            ),
            _buildGuideline(
              'No Spam',
              'Do not use Zaylo for advertising or spamming users with repetitive content.',
              Icons.mark_email_read_rounded,
            ),
            _buildGuideline(
              'No Illegal Content',
              'Any illegal activities or content are strictly forbidden and will be reported to authorities.',
              Icons.warning_rounded,
            ),
            _buildGuideline(
              'Report Abuse',
              'Use the report button if you encounter anyone violating these rules. Help us keep Zaylo safe!',
              Icons.report_gmailerrorred_rounded,
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'By using Zaylo, you agree to follow these guidelines.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideline(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.purpleAccent, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
