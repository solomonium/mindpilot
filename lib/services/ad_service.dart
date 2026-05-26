import 'package:mindpilot/export.dart';

class AdService {
  static final AdService instance = AdService._internal();
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;
  int _loadAttempts = 0;

  // Automatically toggles between Google Test Ad Units (development) and your Production Ad Units (release)
  String get rewardedAdUnitId {
    if (kDebugMode) {
      // 🧪 Google's Official Test Ad Unit IDs (Safe for Emulator, Simulator, and Local debug testing)
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'ca-app-pub-3940256099942544/5224354917';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'ca-app-pub-3940256099942544/1712485313';
      }
    } else {
      // 💰 Your Production Ad Unit IDs (Active when compiled for App Store / Play Store release)
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'ca-app-pub-2538400635781158/1840139396';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'ca-app-pub-2538400635781158/1617155417';
      }
    }
    throw UnsupportedError("Unsupported platform for AdMob");
  }

  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      
      // Register test device IDs in code so production code serves safe test ads on your development devices
      RequestConfiguration configuration = RequestConfiguration(
        testDeviceIds: [
          "CF555EA552E95B2EE4ADF55493C74ED4", // Android Test Device ID
          "d6ed4fee-ed4a-42d7-951e-10ca1ad1abe1", // iOS Test Device ID
        ],
      );
      await MobileAds.instance.updateRequestConfiguration(configuration);
      
      loadRewardedAd();
    } catch (e) {
      safePrint('AdService: Failed to initialize MobileAds: $e');
    }
  }

  void loadRewardedAd() {
    if (_isRewardedAdLoading || _rewardedAd != null) return;
    _isRewardedAdLoading = true;
    safePrint('AdService: Starting to load RewardedAd (Attempt #${_loadAttempts + 1})...');

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          safePrint('AdService: RewardedAd loaded successfully');
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          _loadAttempts = 0; // Reset load attempts on success
          _setupAdCallbacks(ad);
        },
        onAdFailedToLoad: (error) {
          safePrint('AdService: RewardedAd failed to load: $error');
          _rewardedAd = null;
          _isRewardedAdLoading = false;
          _loadAttempts++;
          
          if (_loadAttempts < 6) {
            final delaySeconds = _loadAttempts * 5;
            safePrint('AdService: Retrying ad load in $delaySeconds seconds...');
            Future.delayed(Duration(seconds: delaySeconds), () {
              loadRewardedAd();
            });
          }
        },
      ),
    );
  }

  void _setupAdCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        safePrint('AdService: Ad dismissed by user');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Load next ad proactively
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        safePrint('AdService: Ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Load next ad proactively
      },
    );
  }

  Future<void> showRewardedAd({
    required OnUserEarnedRewardCallback onUserEarnedReward,
    required VoidCallback onAdFailedToShow,
  }) async {
    if (_rewardedAd == null) {
      safePrint('AdService: Rewarded ad not ready, trying to load...');
      onAdFailedToShow();
      loadRewardedAd();
      return;
    }

    try {
      await _rewardedAd!.show(onUserEarnedReward: onUserEarnedReward);
    } catch (e) {
      safePrint('AdService: Error during showing: $e');
      onAdFailedToShow();
    }
  }
}
