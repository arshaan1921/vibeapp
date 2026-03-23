import 'package:flutter/material.dart';
import '../../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      "title": "Ask Anything",
      "text": "Ask questions anonymously or with identity.",
      "icon": "Icons.question_answer",
    },
    {
      "title": "Share Your Vibe",
      "text": "Share your profile and let friends ask.",
      "icon": "Icons.share",
    },
    {
      "title": "Stay Safe",
      "text": "Block or report abuse anytime.",
      "icon": "Icons.security",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          index == 0
                              ? Icons.question_answer
                              : index == 1
                                  ? Icons.share
                                  : Icons.security,
                          size: 100,
                          color: const Color(0xFF2C4E6E),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          _pages[index]["title"]!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C4E6E),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _pages[index]["text"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C4E6E),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      } else {
                        tabIndexNotifier.value = 3; // Navigate to Profile tab
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const MainScaffold()),
                          (route) => false,
                        );
                      }
                    },
                    child: Text(_currentPage == _pages.length - 1 ? "CONTINUE" : "NEXT"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
