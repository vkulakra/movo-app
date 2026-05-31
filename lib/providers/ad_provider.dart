import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Manages the ad-free purchase state and in-app purchase flow.
///
/// Stores the "ads removed" flag locally via SharedPreferences — no
/// account, login, or backend required. Purchases are restored via
/// [InAppPurchase.restorePurchases] on app start.
class AdProvider extends ChangeNotifier {
  static const String _adsRemovedKey = 'ads_removed';

  /// The product ID for the "Remove Ads" one-time purchase.
  /// Must match the product created in Google Play Console.
  static const String removeAdsProductId = 'remove_ads';

  bool _adsRemoved = false;
  bool _isLoading = true;
  ProductDetails? _removeAdsProduct;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  String? _errorMessage;

  /// Whether the user has purchased the ad-free upgrade.
  bool get adsRemoved => _adsRemoved;

  /// Whether the AdProvider is still initializing.
  bool get isLoading => _isLoading;

  /// The product details for the "Remove Ads" product (if available).
  ProductDetails? get removeAdsProduct => _removeAdsProduct;

  /// Whether the product is available for purchase (loaded from store).
  bool get isProductAvailable => _removeAdsProduct != null;

  /// The formatted price of the "Remove Ads" product (e.g. "$2.99").
  String get productPrice => _removeAdsProduct?.price ?? '';

  /// A descriptive error message, or null if no error.
  String? get errorMessage => _errorMessage;

  /// Initialize: load local state, set up purchase listener, query products.
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Load persisted state from local storage (no account needed)
      final prefs = await SharedPreferences.getInstance();
      _adsRemoved = prefs.getBool(_adsRemovedKey) ?? false;

      // 2. Set up purchase stream listener
      _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (error) {
          _errorMessage = 'Purchase error: $error';
          notifyListeners();
        },
      );

      // 3. Query the "Remove Ads" product from the store
      final response = await InAppPurchase.instance
          .queryProductDetails({removeAdsProductId});

      if (response.productDetails.isNotEmpty) {
        _removeAdsProduct = response.productDetails.first;
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize purchases: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Initiate the purchase of the "Remove Ads" upgrade.
  Future<bool> purchaseRemoveAds() async {
    if (_removeAdsProduct == null) {
      _errorMessage = 'Product not available. Please try again later.';
      notifyListeners();
      return false;
    }

    try {
      final purchaseParam = PurchaseParam(
        productDetails: _removeAdsProduct!,
      );
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      return true;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancelled') || msg.contains('canceled') ||
          msg.contains('user_cancelled')) {
        // User cancelled the purchase dialog — not an error, just log it
        debugPrint('Purchase cancelled by user.');
      } else {
        _errorMessage = 'Purchase failed. Please try again.';
        notifyListeners();
      }
      return false;
    }
  }

  /// Restore past purchases (e.g. after reinstall or on a new device).
  Future<void> restorePurchases() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      _errorMessage = 'Restore failed: $e';
      notifyListeners();
    }
  }

  /// Handle purchase updates from the store stream.
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID != removeAdsProductId) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Fire-and-forget with error handling to avoid unhandled Future rejection
        _setAdsRemoved(true).catchError((e) {
          debugPrint('Failed to persist ads removed state: $e');
        });
      }

      if (purchase.status == PurchaseStatus.error) {
        _errorMessage = purchase.error?.message ?? 'Purchase error';
        notifyListeners();
      }

      // Complete/acknowledge the purchase so the store doesn't refund
      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  /// Persist the "ads removed" flag to SharedPreferences.
  Future<void> _setAdsRemoved(bool value) async {
    _adsRemoved = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adsRemovedKey, value);
    notifyListeners();
  }

  /// Clear the error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
