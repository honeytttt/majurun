import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Payment service for handling in-app purchases and subscriptions
class PaymentService extends ChangeNotifier {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isPro = false;
  bool _isLoading = false;
  String? _error;

  // Product IDs - configure these in App Store Connect and Google Play Console
  static const String _monthlyProductId = 'majurun_pro_monthly';
  static const String _yearlyProductId = 'majurun_pro_yearly';
  static const Set<String> _productIds = {_monthlyProductId, _yearlyProductId};

  bool get isAvailable => _isAvailable;
  bool get isPro => _isPro;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ProductDetails> get products => _products;

  ProductDetails? get monthlyProduct =>
      _products.where((p) => p.id == _monthlyProductId).firstOrNull;

  ProductDetails? get yearlyProduct =>
      _products.where((p) => p.id == _yearlyProductId).firstOrNull;

  /// Initialize the payment service
  Future<void> initialize() async {
    // Check if IAP is available on this device
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('In-app purchases not available');
      return;
    }

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (error) {
        debugPrint('Purchase stream error: $error');
        _error = error.toString();
        notifyListeners();
      },
    );

    // Load products
    await loadProducts();

    // Check existing subscription status
    await checkSubscriptionStatus();
  }

  /// Load available products from store
  Future<void> loadProducts() async {
    if (!_isAvailable) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _iap.queryProductDetails(_productIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      _error = response.error?.message;
    } catch (e) {
      debugPrint('Error loading products: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Purchase a subscription
  Future<bool> purchaseSubscription(ProductDetails product) async {
    if (!_isAvailable) {
      _error = 'In-app purchases not available';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        _error = 'Purchase failed to initiate';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      return true; // Purchase flow started, result will come via stream
    } catch (e) {
      debugPrint('Purchase error: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Handle purchase updates from the stream
  void _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _isLoading = true;
          notifyListeners();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Verify receipt server-side and grant entitlement via Cloud Function.
          await _verifyAndDeliver(purchase);

          // Complete the purchase
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }

          _isLoading = false;
          notifyListeners();
          break;

        case PurchaseStatus.error:
          _error = purchase.error?.message ?? 'Purchase failed';
          _isLoading = false;
          notifyListeners();

          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          _isLoading = false;
          notifyListeners();

          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
      }
    }
  }

  /// Verify receipt server-side via Cloud Function and grant entitlement.
  /// The Cloud Function is the ONLY trusted writer of isPro=true in Firestore.
  /// Returns true if the server confirmed and granted the entitlement.
  Future<bool> _verifyAndDeliver(PurchaseDetails purchase) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('verifySubscription');

      final result = await callable.call(<String, dynamic>{
        'productId': purchase.productID,
        'platform': Platform.isIOS ? 'ios' : 'android',
        // iOS uses the base64 receipt; Android uses the purchase token.
        'receiptData': Platform.isIOS
            ? purchase.verificationData.serverVerificationData
            : null,
        'purchaseToken': Platform.isAndroid
            ? purchase.verificationData.serverVerificationData
            : null,
      });

      final success = result.data['success'] == true;
      if (success) {
        _isPro = true;
        notifyListeners();
      }
      return success;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('verifySubscription function error: ${e.code} — ${e.message}');
      _error = e.message ?? 'Verification failed';
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('verifySubscription error: $e');
      _error = 'Verification failed';
      notifyListeners();
      return false;
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      _error = 'In-app purchases not available';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Restore purchases error: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check current subscription status from Firestore
  Future<void> checkSubscriptionStatus() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _isPro = false;
      notifyListeners();
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();

      if (data == null) {
        _isPro = false;
        notifyListeners();
        return;
      }

      final isPro = data['isPro'] as bool? ?? false;
      final expiryTimestamp = data['subscriptionExpiry'] as Timestamp?;

      if (!isPro || expiryTimestamp == null) {
        _isPro = false;
      } else {
        // Check if subscription has expired
        final expiry = expiryTimestamp.toDate();
        _isPro = expiry.isAfter(DateTime.now());

        // If expired, update Firestore
        if (!_isPro) {
          await _firestore.collection('users').doc(userId).update({
            'isPro': false,
          });
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error checking subscription: $e');
    }
  }

  /// Clear any errors
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
