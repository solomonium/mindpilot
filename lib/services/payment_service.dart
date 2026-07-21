import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:mindpilot/export.dart';

class PaymentService {
  static bool _isConfigured = false;
  static bool get isConfigured => _isConfigured;

  // Entitlement ID mapped to RevenueCat
  static String get entitlementId => dotenv.env['REVENUECAT_ENTITLEMENT_ID'] ?? 'pro';

  // ValueNotifiers to allow UI screens to listen to payment states
  static final ValueNotifier<bool> isPurchasing = ValueNotifier<bool>(false);
  static final ValueNotifier<bool?> purchasedOrRestored = ValueNotifier<bool?>(null);

  static Future<void> initialize() async {
    try {
      String? apiKey;
      if (Platform.isAndroid) {
        apiKey = dotenv.env['REVENUECAT_ANDROID_API_KEY'];
      } else if (Platform.isIOS) {
        apiKey = dotenv.env['REVENUECAT_IOS_API_KEY'];
      }

      if (apiKey == null || apiKey.isEmpty || apiKey == 'your_android_api_key_here' || apiKey == 'your_ios_api_key_here') {
        safePrint('RevenueCat API Key is missing or placeholders used. Skipping configuration.');
        return;
      }

      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      _isConfigured = true;
      await Purchases.setLogLevel(LogLevel.debug);
      safePrint('RevenueCat successfully configured');

      // Sync subscription status safely in background on launch
      unawaited(syncSubscriptionStatus().catchError((e) {
        safePrint('Error syncing RevenueCat subscription: $e');
      }));
    } catch (e) {
      safePrint('Error initializing RevenueCat: $e');
    }
  }

  static Future<List<Package>> fetchOfferings() async {
    if (!_isConfigured) {
      safePrint('PaymentService: Purchases SDK not configured. Cannot fetch offerings.');
      return [];
    }
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        final packages = offerings.current!.availablePackages;
        
        safePrint('🎉 DEBUG REVENUECAT FETCH: Found ${packages.length} packages in current offering:');
        for (var package in packages) {
          final p = package.storeProduct;
          safePrint('  - Package Type: ${package.packageType} | Product ID: ${p.identifier} | Price: ${p.priceString} | Title: ${p.title}');
        }
        
        return packages;
      }
    } catch (e) {
      safePrint('Error fetching offerings: $e');
    }
    return [];
  }

  static Future<bool> buyPackage(Package package) async {
    if (!_isConfigured) {
      safePrint('PaymentService: Purchases SDK not configured. Cannot buy package.');
      return false;
    }
    isPurchasing.value = true;
    purchasedOrRestored.value = null;
    try {
      PurchaseResult result = await Purchases.purchasePackage(package);
      CustomerInfo customerInfo = result.customerInfo;
      final bool active = customerInfo.entitlements.all[entitlementId]?.isActive == true;
      if (active) {
        await _deliverProAccess(true);
        purchasedOrRestored.value = true;
        return true;
      }
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        safePrint('RevenueCat Purchase Error: $e');
      }
      purchasedOrRestored.value = false;
    } catch (e) {
      safePrint('Purchase Error: $e');
      purchasedOrRestored.value = false;
    } finally {
      isPurchasing.value = false;
    }
    return false;
  }

  static Future<bool> buyProduct(StoreProduct product) async {
    if (!_isConfigured) {
      safePrint('PaymentService: Purchases SDK not configured. Cannot buy product.');
      return false;
    }
    isPurchasing.value = true;
    purchasedOrRestored.value = null;
    try {
      PurchaseResult result = await Purchases.purchaseStoreProduct(product);
      CustomerInfo customerInfo = result.customerInfo;
      final bool active =
          customerInfo.entitlements.all[entitlementId]?.isActive == true;
      if (active) {
        await _deliverProAccess(true);
        purchasedOrRestored.value = true;
        return true;
      }
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        safePrint('RevenueCat Product Purchase Error: $e');
      }
      purchasedOrRestored.value = false;
    } catch (e) {
      safePrint('Product Purchase Error: $e');
      purchasedOrRestored.value = false;
    } finally {
      isPurchasing.value = false;
    }
    return false;
  }

  static Future<bool> restorePurchases() async {
    if (!_isConfigured) {
      safePrint('PaymentService: Purchases SDK not configured. Cannot restore purchases.');
      return false;
    }
    isPurchasing.value = true;
    purchasedOrRestored.value = null;
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      final bool active = customerInfo.entitlements.all[entitlementId]?.isActive == true;
      await _deliverProAccess(active);
      purchasedOrRestored.value = active;
      return active;
    } catch (e) {
      safePrint('Restore purchases error: $e');
      purchasedOrRestored.value = false;
    } finally {
      isPurchasing.value = false;
    }
    return false;
  }

  static Future<void> syncSubscriptionStatus() async {
    if (!_isConfigured) {
      safePrint('PaymentService: Purchases SDK not configured. Skipping sync.');
      return;
    }
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Identify user with RevenueCat if logged in
      await Purchases.logIn(uid);

      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      final bool active = customerInfo.entitlements.all[entitlementId]?.isActive == true;
      await _deliverProAccess(active);
    } catch (e) {
      safePrint('Error syncing subscription status: $e');
    }
  }

  static Future<void> _deliverProAccess(bool active) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final targetUserType = active ? 'Pro Member' : 'Freemium';
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'userType': targetUserType,
        });
        safePrint('Firestore updated userType to $targetUserType for $uid');
      }
    } catch (e) {
      safePrint('Error updating Firestore userType: $e');
    }
  }
}
