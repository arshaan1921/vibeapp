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
          : SafeArea(
              child: StreamBuilder<Map<String, ProductDetails>>(
                  stream: IAPService().productsStream,
                  builder: (context, snapshot) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            "Get More Vibes",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0A3321),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Daily limit reached? Buy a booster pack to keep vibing and chatting! ❤️",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
                          ),
                          const SizedBox(height: 32),
                          _buildBoosterCard(
                            context,
                            id: IAPService.booster10,
                            defaultTitle: "10 Questions + 50 AI Chats",
                            defaultPrice: "₹29",
                            products: snapshot.data,
                          ),
                          const SizedBox(height: 16),
                          _buildBoosterCard(
                            context,
                            id: IAPService.booster25,
                            defaultTitle: "25 Questions + 150 AI Chats",
                            defaultPrice: "₹59",
                            products: snapshot.data,
                          ),
                          const SizedBox(height: 16),
                          _buildBoosterCard(
                            context,
                            id: IAPService.booster100,
                            defaultTitle: "100 Questions + 500 AI Chats",
                            defaultPrice: "₹149",
                            products: snapshot.data,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  }),
            ),
    );
  }

  Widget _buildBoosterCard(
    BuildContext context, {
    required String id,
    required String defaultTitle,
    required String defaultPrice,
    Map<String, ProductDetails>? products,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final product = products?[id];

    // Use store price if available, otherwise use default
    final displayPrice = product?.price ?? defaultPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: InkWell(
        onTap: () => _purchaseBooster(id),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 22.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      defaultTitle,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.titleLarge?.color,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: Color(0xFFFFD700),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Available instantly",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                displayPrice,
                style: const TextStyle(
                  fontSize: 20,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
