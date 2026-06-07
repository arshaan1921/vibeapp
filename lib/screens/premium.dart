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
        title: const Text("HIGH5 PREMIUM"),
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
                    const SizedBox(height: 16),
                    _buildRestoreFeaturesInfo(),
                    const SizedBox(height: 24),
                    _buildPlanCard(
                      context,
                      plan: 'green',
                      title: "Green Plan",
                      price: "₹100.00 / month",
                      features: [
                        "50 questions per day",
                        "100 AI chats per day ❤️",
                        "3 streak restores per month 🔥",
                        "72 hour restore window",
                        "Green verified badge",
                        "Green profile ring"
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPlanCard(
                      context,
                      plan: 'blue',
                      title: "Blue Plan",
                      price: "₹250.00 / 3 months",
                      features: [
                        "Unlimited questions",
                        "300 AI chats per day ❤️",
                        "10 streak restores per month 🔥",
                        "Priority streak support",
                        "Blue verified badge",
                        "Blue profile ring"
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPlanCard(
                      context,
                      plan: 'gold',
                      title: "Yellow Plan",
                      price: "₹800.00 / 1 year",
                      features: [
                        "Unlimited questions",
                        "1000 AI chats per day ❤️",
                        "Unlimited streak restores 🔥",
                        "Future streak protection",
                        "Yellow verified badge",
                        "Yellow profile ring"
                      ],
                      isBestValue: true,
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRestoreFeaturesInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.local_fire_department, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                "STREAK RESTORES",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRestoreFeatureRow("Free", "1 restore/month • 72h window"),
          _buildRestoreFeatureRow("Green", "3 restores/month • 72h window"),
          _buildRestoreFeatureRow("Blue", "10 restores/month • Priority Support"),
          _buildRestoreFeatureRow("Yellow", "Unlimited restores • Priority Support"),
        ],
      ),
    );
  }

  Widget _buildRestoreFeatureRow(String plan, String details) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(plan, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(details, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
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
                    PremiumUtils.buildBadge(plan, size: 22),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  price,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ...features.map((f) {
                  final isAiFeature = f.contains("AI chats");
                  final isStreakFeature = f.contains("streak restores") || f.contains("streak support") || f.contains("streak protection");
                  final isBadgeFeature = f.contains("verified badge");
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          isBadgeFeature ? Icons.verified_rounded : Icons.check_circle, 
                          size: 18, 
                          color: isStreakFeature ? Colors.orange : color
                        ),
                        const SizedBox(width: 8),
                        if (isAiFeature)
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(f.replaceAll("❤️", "").trim()),
                                const SizedBox(width: 4),
                                Icon(Icons.auto_awesome, size: 16, color: color),
                              ],
                            ),
                          )
                        else if (isStreakFeature)
                          Expanded(
                            child: Text(
                              f.replaceAll("🔥", "").trim(),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          )
                        else
                          Text(f),
                      ],
                    ),
                  );
                }),
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
