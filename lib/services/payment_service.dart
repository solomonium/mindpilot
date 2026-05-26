import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:mindpilot/export.dart';

class PaymentService {
  // Entitlement ID mapped to RevenueCat
  static String get entitlementId => dotenv.env['REVENUECAT_ENTITLEMENT_ID'] ?? 'pro';

  // ValueNotifiers to allow UI screens to listen to payment states
  static final ValueNotifier<bool> isPurchasing = ValueNotifier<bool>(false);
  static final ValueNotifier<bool?> purchasedOrRestored = ValueNotifier<bool?>(null);

  static Future<void> initialize() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);

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
      safePrint('RevenueCat successfully configured');

      // Sync subscription status on launch
      await syncSubscriptionStatus();
    } catch (e) {
      safePrint('Error initializing RevenueCat: $e');
    }
  }

  static Future<List<Package>> fetchOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        return offerings.current!.availablePackages;
      }
    } catch (e) {
      safePrint('Error fetching offerings: $e');
    }
    return [];
  }

  static Future<bool> buyPackage(Package package) async {
    isPurchasing.value = true;
    purchasedOrRestored.value = null;
    try {
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);
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
    isPurchasing.value = true;
    purchasedOrRestored.value = null;
    try {
      CustomerInfo customerInfo = await Purchases.purchaseStoreProduct(product);
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
