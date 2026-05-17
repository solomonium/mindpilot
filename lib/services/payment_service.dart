import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mindpilot/export.dart';

class PaymentService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  static const String monthlyPlanId = 'mindpilot_pro_monthly';
  static const String yearlyPlanId = 'mindpilot_pro_yearly';

  static void initialize() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        safePrint('Purchase stream error: $error');
      },
    );
  }

  static Future<void> buyPro(String productId) async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      safePrint('Store not available');
      return;
    }

    final ProductDetailsResponse response = await _iap.queryProductDetails({
      productId,
    });
    if (response.notFoundIDs.isNotEmpty) {
      safePrint('Product not found: $productId');
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  static void _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show loading
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          safePrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          _deliverProduct(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  static void _deliverProduct(PurchaseDetails purchaseDetails) {
    // Here we update Firestore to set userType to 'Pro Member'
    // This connects the global store payment to your existing database system
    safePrint('Delivering Pro access for ${purchaseDetails.productID}');
    // Logic to update AuthProvider/Firestore goes here
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
