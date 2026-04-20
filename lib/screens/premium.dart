import 'package:flutter/material.dart';
import '../utils/premium_utils.dart';
import '../services/iap_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isLoading = false;

  Future<void> _upgradePlan(String plan) async {
    setState(() => _isLoading = true);
    try {
      final productId = "${plan}_plan";
      await IAPService().buyProduct(productId);
      // The actual upgrade logic is handled in IAPService._deliverProduct upon success
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("V1BE PREMIUM"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      "Choose Your Plan",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    _buildPlanCard(
                      context,
                      plan: 'green',
                      title: "Green Plan",
                      price: "₹100.00",
                      features: ["50 questions per day", "Green badge", "Green profile ring"],
                    ),
                    const SizedBox(height: 16),
                    _buildPlanCard(
                      context,
                      plan: 'blue',
                      title: "Blue Plan",
                      price: "₹250.00",
                      features: ["Unlimited questions", "Blue badge", "Blue profile ring"],
                    ),
                    const SizedBox(height: 16),
                    _buildPlanCard(
                      context,
                      plan: 'gold',
                      title: "Gold Plan",
                      price: "₹800.00",
                      features: ["Unlimited questions", "Gold badge", "Gold profile ring"],
                      isBestValue: true,
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String plan,
    required String title,
    required String price,
    required List<String> features,
    bool isBestValue = false,
  }) {
    final color = PremiumUtils.getRingColor(plan);

    return Stack(
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                    ),
                    PremiumUtils.buildBadge(plan),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  price,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 18, color: color),
                          const SizedBox(width: 8),
                          Text(f),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _upgradePlan(plan),
                    child: const Text("UPGRADE NOW"),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isBestValue)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "Best Value",
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
