import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BoosterPackScreen extends StatefulWidget {
  const BoosterPackScreen({super.key});

  @override
  State<BoosterPackScreen> createState() => _BoosterPackScreenState();
}

class _BoosterPackScreenState extends State<BoosterPackScreen> {
  bool _isLoading = false;

  Future<void> _purchaseBooster(int questions, int price) async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Simulate purchase by adding questions to the question_boosters table
      await supabase.from('question_boosters').insert({
        'user_id': user.id,
        'questions_added': questions,
        'questions_used': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully purchased $questions questions!")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text("BOOSTER PACKS"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    "Get More Questions",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C4E6E)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Daily limit reached? Buy a booster pack to keep vibing!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  _buildBoosterCard(
                    context,
                    questions: 10,
                    price: "₹29",
                    onTap: () => _purchaseBooster(10, 29),
                  ),
                  const SizedBox(height: 16),
                  _buildBoosterCard(
                    context,
                    questions: 25,
                    price: "₹59",
                    onTap: () => _purchaseBooster(25, 59),
                  ),
                  const SizedBox(height: 16),
                  _buildBoosterCard(
                    context,
                    questions: 100,
                    price: "₹149",
                    onTap: () => _purchaseBooster(100, 149),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBoosterCard(BuildContext context, {required int questions, required String price, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$questions Questions",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Icon(Icons.bolt_rounded, color: Colors.orange, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
