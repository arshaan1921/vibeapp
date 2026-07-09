import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/zaylo_service.dart';
import '../widgets/zaylo_widgets.dart';

class ZayloInterestsScreen extends StatefulWidget {
  final List<String> initialInterests;
  const ZayloInterestsScreen({super.key, required this.initialInterests});

  @override
  State<ZayloInterestsScreen> createState() => _ZayloInterestsScreenState();
}

class _ZayloInterestsScreenState extends State<ZayloInterestsScreen> {
  final List<String> _availableInterests = [
    'Gaming', 'Anime', 'Movies', 'Technology', 'Sports',
    'Travel', 'Fitness', 'Music', 'Food', 'Fashion'
  ];
  late List<String> _selectedInterests;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedInterests = List.from(widget.initialInterests);
  }

  Future<void> _toggleInterest(String interest) async {
    if (_isSaving) return;

    final newInterests = List<String>.from(_selectedInterests);
    if (newInterests.contains(interest)) {
      newInterests.remove(interest);
    } else {
      if (newInterests.length >= 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can select up to 10 interests')),
        );
        return;
      }
      newInterests.add(interest);
    }

    setState(() {
      _selectedInterests = newInterests;
      _isSaving = true;
    });

    try {
      await zayloService.updatePreference('interests', newInterests);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences Updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update interests: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Interests', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
            Text(
              'Select up to 10 interests to find better matches.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _availableInterests.map((interest) {
                return ZayloInterestChip(
                  label: interest,
                  isSelected: _selectedInterests.contains(interest),
                  onTap: () => _toggleInterest(interest),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
