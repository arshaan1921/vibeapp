import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  final Map<String, ProductDetails> _productsMap = {};
  bool _isAvailable = false;
  
  final _productsController = StreamController<Map<String, ProductDetails>>.broadcast();
  Stream<Map<String, ProductDetails>> get productsStream => _productsController.stream;

  static const String greenPlan = 'green_plan';
  static const String bluePlan = 'blue_plan';
  static const String goldPlan = 'gold_plan';
  
  static const String booster10 = 'booster_10';
  static const String booster25 = 'booster_25';
  static const String booster100 = 'booster_100';

  final Set<String> _subIds = {greenPlan, bluePlan, goldPlan};
  final Set<String> _boosterIds = {booster10, booster25, booster100};

  void initialize() async {
    _isAvailable = await _iap.isAvailable();
    if (_isAvailable) {
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (error) => debugPrint("IAP Error: $error"),
      );
      // Query both types on startup
      await queryProducts();
    }
  }

  Future<void> queryProducts() async {
    if (!_isAvailable) return;
    try {
      // Fetch subscriptions and one-time products separately for better compatibility
      final ProductDetailsResponse subResponse = await _iap.queryProductDetails(_subIds);
      final ProductDetailsResponse boosterResponse = await _iap.queryProductDetails(_boosterIds);

      for (var product in subResponse.productDetails) {
        _productsMap[product.id] = product;
      }
      for (var product in boosterResponse.productDetails) {
        _productsMap[product.id] = product;
      }
      
      _productsController.add(_productsMap);
      
      if (subResponse.notFoundIDs.isNotEmpty || boosterResponse.notFoundIDs.isNotEmpty) {
        debugPrint("IDs not found: ${subResponse.notFoundIDs} ${boosterResponse.notFoundIDs}");
      }
    } catch (e) {
      debugPrint("Error querying products: $e");
    }
  }

  Future<void> buyProduct(String productId) async {
    if (!_isAvailable) throw "Billing service is not available on this device.";

    final productDetails = _productsMap[productId];
    if (productDetails == null) {
      // Try one last time to fetch
      await queryProducts();
      final retryDetails = _productsMap[productId];
      if (retryDetails == null) {
        throw "Product '$productId' is not found in Google Play. Please check if it's 'Active' in the console.";
      }
    }

    final purchaseParam = PurchaseParam(productDetails: _productsMap[productId]!);
    
    if (_subIds.contains(productId)) {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      // Force consumable for boosters
      await _iap.buyConsumable(purchaseParam: purchaseParam);
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        bool delivered = await _deliverProduct(purchase);
        if (delivered) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint("Purchase Error: ${purchase.error}");
      }
    }
  }

  Future<bool> _deliverProduct(PurchaseDetails purchase) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    try {
      if (_subIds.contains(purchase.productID)) {
        String plan = purchase.productID.split('_')[0];
        int months = plan == 'gold' ? 12 : (plan == 'blue' ? 3 : 1);
        final expiresAt = DateTime.now().add(Duration(days: months * 30));
        await supabase.from('profiles').update({
          'premium_plan': plan,
          'premium_expires_at': expiresAt.toIso8601String(),
        }).eq('id', user.id);
      } else {
        int questions = 0;
        if (purchase.productID == booster10) questions = 10;
        else if (purchase.productID == booster25) questions = 25;
        else if (purchase.productID == booster100) questions = 100;

        if (questions > 0) {
          await supabase.from('question_boosters').insert({
            'user_id': user.id,
            'questions_added': questions,
            'questions_used': 0,
          });
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
