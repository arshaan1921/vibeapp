import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StreakRestoreService {
  static final StreakRestoreService _instance = StreakRestoreService._internal();
  factory StreakRestoreService() => _instance;
  StreakRestoreService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  final Map<String, ProductDetails> _productsMap = {};
  bool _isAvailable = false;
  
  final _processedPurchases = <String>{};

  static const String restore1 = 'high5_restore_1';
  static const String restore5 = 'high5_restore_5';
  static const String restore20 = 'high5_restore_20';

  final Set<String> _productIds = {restore1, restore5, restore20};

  void initialize() async {
    _isAvailable = await _iap.isAvailable();
    if (_isAvailable) {
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (error) => debugPrint("StreakRestore IAP Error: $error"),
      );
      await queryProducts();
    }
  }

  Future<void> queryProducts() async {
    if (!_isAvailable) return;
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
      for (var product in response.productDetails) {
        _productsMap[product.id] = product;
      }
    } catch (e) {
      debugPrint("Error querying streak restore products: $e");
    }
  }

  List<ProductDetails> get products => _productsMap.values.toList();

  Future<void> buyRestore(String productId) async {
    if (!_isAvailable) throw "Billing service is not available.";

    final productDetails = _productsMap[productId];
    if (productDetails == null) {
      await queryProducts();
      if (_productsMap[productId] == null) {
        throw "Product not found.";
      }
    }

    final purchaseParam = PurchaseParam(productDetails: _productsMap[productId]!);
    await _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        if (_productIds.contains(purchase.productID)) {
          bool delivered = await _deliverRestores(purchase);
          if (delivered) {
            await _iap.completePurchase(purchase);
          }
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint("StreakRestore Purchase Error: ${purchase.error}");
      }
    }
  }

  Future<bool> _deliverRestores(PurchaseDetails purchase) async {
    // Prevent duplicate processing
    if (purchase.purchaseID != null && _processedPurchases.contains(purchase.purchaseID)) {
      return true;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    int amount = 0;
    if (purchase.productID == restore1) amount = 1;
    if (purchase.productID == restore5) amount = 5;
    if (purchase.productID == restore20) amount = 20;

    if (amount == 0) return false;

    try {
      // Use RPC if available or a direct update with increment
      // For simplicity in this environment, we'll fetch then update, 
      // though a database-level increment is preferred.
      final profile = await supabase
          .from('profiles')
          .select('purchased_streak_restores')
          .eq('id', user.id)
          .single();
      
      int current = profile['purchased_streak_restores'] ?? 0;
      
      await supabase.from('profiles').update({
        'purchased_streak_restores': current + amount,
      }).eq('id', user.id);

      if (purchase.purchaseID != null) {
        _processedPurchases.add(purchase.purchaseID!);
      }
      return true;
    } catch (e) {
      debugPrint("Error delivering streak restores: $e");
      return false;
    }
  }
}
