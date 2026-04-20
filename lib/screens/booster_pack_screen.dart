import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/iap_service.dart';

class BoosterPackScreen extends StatefulWidget {
  const BoosterPackScreen({super.key});

  @override
  State<BoosterPackScreen> createState() => _BoosterPackScreenState();
}

class _BoosterPackScreenState extends State<BoosterPackScreen> {
  bool _isLoading = false;

  Future<void> _purchaseBooster(String productId) async {
    setState(() => _isLoading = true);
    try {
      await IAPService().buyProduct(productId);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("BOOSTER PACKS"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<Map<String, ProductDetails>>(
              stream: IAPService().productsStream,
              builder: (context, snapshot) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        "Get More Questions",
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold, 
                          color: isDark ? Colors.white : const Color(0xFF2C4E6E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Daily limit reached? Buy a booster pack to keep vibing!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      _buildBoosterCard(
                        context,
                        id: IAPService.booster10,
                        defaultQuestions: 10,
                        defaultPrice: "₹29",
                        products: snapshot.data,
                      ),
                      const SizedBox(height: 16),
                      _buildBoosterCard(
                        context,
                        id: IAPService.booster25,
                        defaultQuestions: 25,
                        defaultPrice: "₹59",
                        products: snapshot.data,
                      ),
                      const SizedBox(height: 16),
                      _buildBoosterCard(
                        context,
                        id: IAPService.booster100,
                        defaultQuestions: 100,
                        defaultPrice: "₹149",
                        products: snapshot.data,
                      ),
                    ],
                  ),
                );
              }
            ),
    );
  }

  Widget _buildBoosterCard(
    BuildContext context, {
    required String id, 
    required int defaultQuestions, 
    required String defaultPrice,
    Map<String, ProductDetails>? products,
  }) {
    final theme = Theme.of(context);
    final product = products?[id];
    
    // Use store price if available, otherwise use default
    final displayPrice = product?.price ?? defaultPrice;
    final displayTitle = product?.title.split('(').first.trim() ?? "$defaultQuestions Questions";

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _purchaseBooster(id),
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
                    displayTitle,
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Available instantly",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayPrice,
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
