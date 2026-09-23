import 'dart:io';
import 'package:in_app_review/in_app_review.dart';
import 'package:mindpilot/export.dart';

class InAppReviewService {
  static final InAppReviewService _instance = InAppReviewService._internal();
  factory InAppReviewService() => _instance;
  InAppReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  static const String _appleAppStoreId = '6770153795';

  /// Triggers the native Google Play / Apple App Store In-App Review dialog directly within the app.
  /// If the native in-app review API is not available or quota-limited, it can fall back to opening the store listing.
  Future<bool> requestReview({bool fallbackToStore = false}) async {
    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (isAvailable) {
        safePrint('InAppReviewService: Requesting native in-app review dialog...');
        await _inAppReview.requestReview();
        return true;
      } else if (fallbackToStore) {
        safePrint('InAppReviewService: In-app review unavailable, opening store listing...');
        await openStoreListing();
        return true;
      }
    } catch (e) {
      safePrint('InAppReviewService Error: $e');
      if (fallbackToStore) {
        await openStoreListing();
      }
    }
    return false;
  }

  /// Opens the official store listing (Google Play or Apple App Store).
  Future<void> openStoreListing() async {
    try {
      if (Platform.isIOS) {
        await _inAppReview.openStoreListing(appStoreId: _appleAppStoreId);
      } else {
        await _inAppReview.openStoreListing();
      }
    } catch (e) {
      safePrint('InAppReviewService openStoreListing Error: $e');
      final fallbackUrl = ConfigService().updateUrl;
      AppHelper.launchURL(fallbackUrl);
    }
  }
}
