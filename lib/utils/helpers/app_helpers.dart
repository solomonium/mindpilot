import 'dart:async';
import 'dart:io';

import 'package:mindpilot/export.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class AppHelper {
  static bool _listenerAdded = false;

  static void unFocus() {
    WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
  }

  static Rect? getSharePositionOrigin(BuildContext context) {
    try {
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        final size = box.size;
        final position = box.localToGlobal(Offset.zero);
        if (size.width > 0 && size.height > 0) {
          return Rect.fromLTWH(
            position.dx,
            position.dy,
            size.width,
            size.height,
          );
        }
      }
    } catch (_) {}
    try {
      final size = MediaQuery.of(context).size;
      // Fallback: safe, non-zero origin at the bottom-center of the screen
      return Rect.fromLTWH(size.width / 2 - 50, size.height - 100, 100, 100);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setScreenshotProtection(bool enable) async {
    if (!Platform.isAndroid) return;
    try {
      final context = R.N.navKey.currentContext;
      bool isPro = false;
      if (context != null) {
        try {
          isPro = context.read<AppAuthProvider>().isPro;
        } catch (_) {}
      }

      if (enable && !isPro) {
        // Enforce protection only for freemium users
        await ScreenProtector.preventScreenshotOn();

        // Register native screenshot and screen recording listeners dynamically (only once)
        if (!_listenerAdded) {
          _listenerAdded = true;
          ScreenProtector.addListener(
            () {
              final currentContext = R.N.navKey.currentContext;
              if (currentContext != null && currentContext.mounted) {
                final activePro = currentContext.read<AppAuthProvider>().isPro;
                if (!activePro) {
                  currentContext.showInAppNotification(
                    'Screenshots are disabled on Freemium. Upgrade to Pro to enable them!',
                    title: 'Pro Feature Only',
                    type: InAppNotificationType.info,
                  );
                }
              }
            },
            (isRecording) {
              if (isRecording) {
                final currentContext = R.N.navKey.currentContext;
                if (currentContext != null && currentContext.mounted) {
                  final activePro = currentContext
                      .read<AppAuthProvider>()
                      .isPro;
                  if (!activePro) {
                    currentContext.showInAppNotification(
                      'Screen recording is disabled on Freemium. Upgrade to Pro to enable them!',
                      title: 'Pro Feature Only',
                      type: InAppNotificationType.info,
                    );
                  }
                }
              }
            },
          );
        }
      } else {
        // Allow screenshots/recordings for Pro members or when explicitly disabling protection
        await ScreenProtector.preventScreenshotOff();
      }
    } catch (e) {
      safePrint('Error setting screenshot protection: $e');
    }
  }

  static Future<bool> canWatchAdForPremiumUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString('DAILY_AD_UNLOCK_DATE') ?? '';
    int count = prefs.getInt('DAILY_AD_UNLOCK_COUNT') ?? 0;

    if (lastDate != today) {
      count = 0;
      await prefs.setString('DAILY_AD_UNLOCK_DATE', today);
      await prefs.setInt('DAILY_AD_UNLOCK_COUNT', 0);
    }

    return count < 3;
  }

  static Future<void> incrementAdUnlockCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString('DAILY_AD_UNLOCK_DATE') ?? '';
    int count = prefs.getInt('DAILY_AD_UNLOCK_COUNT') ?? 0;

    if (lastDate != today) {
      count = 0;
      await prefs.setString('DAILY_AD_UNLOCK_DATE', today);
    }

    await prefs.setInt('DAILY_AD_UNLOCK_COUNT', count + 1);
  }

  static Future<int> getAdUnlockCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString('DAILY_AD_UNLOCK_DATE') ?? '';
    int count = prefs.getInt('DAILY_AD_UNLOCK_COUNT') ?? 0;

    if (lastDate != today) {
      return 0;
    }
    return count;
  }

  static void showPaywall(BuildContext context, {String? feature, VoidCallback? onAdUnlocked}) {
    AnalyticsService.logPaywallShown(feature ?? 'general');
    AppTheme theme = context.read();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.brandDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Image.asset(
                      R.png.loginBg.png,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, theme.brandDark],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                    ).clickable(() => context.pop()),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFF59E0B),
                          size: 32,
                        ),
                        8.verticalSpace,
                        PrimaryText(
                          text: 'MindPilot Pro',
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    SecondaryText(
                      text: feature != null
                          ? 'The "$feature" feature is exclusive to Pro Members.'
                          : 'Unlock the full potential of your mind with Pro features.',
                      color: Colors.white70,
                      textAlign: TextAlign.center,
                    ),
                    24.verticalSpace,
                    _benefitRow(Icons.bolt, 'Unlimited AI Assistance'),
                    12.verticalSpace,
                    _benefitRow(Icons.analytics, 'Deep Growth Analytics'),
                    12.verticalSpace,
                    _benefitRow(Icons.palette, 'Special Glassmorphism Themes'),
                    12.verticalSpace,
                    _benefitRow(
                      Icons.camera_alt,
                      'Native Screenshots & Screen Recording',
                    ),
                    32.verticalSpace,
                    CustomButton(
                      label: 'Upgrade Now',
                      onPressed: () {
                        context.pop();
                        context.push(const UpgradeScreen());
                      },
                    ),
                    FutureBuilder<int>(
                      future: getAdUnlockCount(),
                      builder: (context, snapshot) {
                        final adCount = snapshot.data ?? 0;
                        final limitReached = adCount >= 3;

                        return Column(
                          children: [
                            16.verticalSpace,
                            SecondaryText(
                              text: '— OR —',
                              fontSize: 12,
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                            16.verticalSpace,
                            if (limitReached) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.errorPrimary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.errorPrimary.withOpacity(0.2)),
                                ),
                                child: SecondaryText(
                                  text: 'Daily ad unlocks limit reached (3/3 used). Upgrade to Pro for unlimited access!',
                                  color: theme.accentTxt,
                                  textAlign: TextAlign.center,
                                  fontSize: 12,
                                ),
                              ),
                            ] else ...[
                              CustomButton(
                                label: 'Watch Ad to Unlock',
                                isGlass: true,
                                prefixIcon: const Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  context.pop();
                                  _watchAdForFeature(context, feature ?? 'feature', onAdUnlocked);
                                },
                              ),
                              8.verticalSpace,
                              SecondaryText(
                                text: '($adCount/3 daily ad unlocks used)',
                                fontSize: 11,
                                color: Colors.white38,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showUpdatePrompt(
    BuildContext context, {
    required String version,
    bool force = false,
  }) {
    AppTheme theme = context.read();
    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (context) => WillPopScope(
        onWillPop: () async => !force,
        child: AlertDialog(
          backgroundColor: theme.brandDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: Image.asset(
                        R.png.loginBg.png,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, theme.brandDark],
                          ),
                        ),
                      ),
                    ),
                    if (!force)
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                        ).clickable(() => Navigator.pop(context)),
                      ),
                    Positioned(
                      bottom: 10,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.system_update_alt,
                            color: Color(0xFF10B981),
                            size: 32,
                          ),
                          8.verticalSpace,
                          PrimaryText(
                            text: 'Update Available',
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SecondaryText(
                        text:
                            'A new version ($version) of MindPilot is ready. Update now for better performance and new AI features.',
                        color: Colors.white70,
                        textAlign: TextAlign.center,
                      ),
                      32.verticalSpace,
                      CustomButton(
                        label: 'Update Now',
                        onPressed: () {
                          // Launch update URL
                          final url = ConfigService().updateUrl;
                          AppHelper.launchURL(url);
                        },
                      ),
                      if (!force) ...[
                        16.verticalSpace,
                        SecondaryText(
                          text: 'Maybe later',
                          fontSize: 13,
                          color: Colors.white38,
                        ).clickable(() => Navigator.pop(context)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void showFeedbackPrompt(BuildContext context) {
    AppTheme theme = context.read();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.brandDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Image.asset(
                      R.png.loginBg.png,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, theme.brandDark],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                    ).clickable(() => Navigator.pop(context)),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.rate_review_rounded,
                          color: Color(0xFF8B5CF6),
                          size: 32,
                        ),
                        8.verticalSpace,
                        PrimaryText(
                          text: 'Your Opinion Matters',
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    SecondaryText(
                      text:
                          'How is your experience with MindPilot so far? We would love to hear your thoughts and ideas on how we can improve for you!',
                      color: Colors.white70,
                      textAlign: TextAlign.center,
                    ),
                    32.verticalSpace,
                    CustomButton(
                      label: 'Share Feedback',
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(const FeedbackScreen());
                      },
                    ),
                    16.verticalSpace,
                    SecondaryText(
                      text: 'Remind me later',
                      fontSize: 13,
                      color: Colors.white38,
                    ).clickable(() => Navigator.pop(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      await url_launcher.launchUrl(
        uri,
        mode: url_launcher.LaunchMode.externalApplication,
      );
    } catch (e) {
      safePrint('Could not launch $url: $e');
    }
  }

  static Widget _benefitRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF10B981), size: 18),
        16.horizontalSpace,
        Expanded(
          child: SecondaryText(text: text, color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }

  static void showAirplaneModePrompt(
    BuildContext context, {
    required VoidCallback onStartSession,
  }) async {
    // Check if the user has already chosen to suppress the prompt
    final prefs = await SharedPreferences.getInstance();
    final bool dontShowAgain =
        prefs.getBool('DONT_SHOW_AIRPLANE_PROMPT') ?? false;

    if (dontShowAgain) {
      onStartSession();
      return;
    }

    if (!context.mounted) return;

    AppTheme theme = context.read();
    bool isChecked = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: theme.brandDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: Image.asset(
                          R.png.loginBg.png,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, theme.brandDark],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 20,
                        right: 20,
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ).clickable(() => Navigator.pop(context)),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.airplanemode_active,
                              color: Color(0xFFF59E0B),
                              size: 32,
                            ),
                            8.verticalSpace,
                            PrimaryText(
                              text: 'Zero Distractions',
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SecondaryText(
                          text:
                              'To get the most out of your focus session and avoid notifications, we highly recommend turning on Airplane Mode.',
                          color: Colors.white70,
                          textAlign: TextAlign.center,
                        ),
                        24.verticalSpace,
                        // Checkbox Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Theme(
                              data: ThemeData(
                                unselectedWidgetColor: Colors.white30,
                              ),
                              child: Checkbox(
                                value: isChecked,
                                activeColor: theme.primaryBase,
                                checkColor: Colors.white,
                                onChanged: (val) {
                                  setState(() {
                                    isChecked = val ?? false;
                                  });
                                },
                              ),
                            ),
                            8.horizontalSpace,
                            SecondaryText(
                              text: "Don't show this again",
                              color: Colors.white70,
                              fontSize: 13,
                            ).clickable(() {
                              setState(() {
                                isChecked = !isChecked;
                              });
                            }),
                          ],
                        ),
                        16.verticalSpace,
                        CustomButton(
                          label: 'Enable Airplane Mode',
                          onPressed: () async {
                            if (isChecked) {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool(
                                'DONT_SHOW_AIRPLANE_PROMPT',
                                true,
                              );
                            }
                            if (context.mounted) Navigator.pop(context);
                            AppSettings.openAppSettings(
                              type: AppSettingsType.wireless,
                            );
                            onStartSession();
                          },
                        ),
                        16.verticalSpace,
                        SecondaryText(
                          text: 'Start Session Anyway',
                          fontSize: 13,
                          color: Colors.white38,
                        ).clickable(() async {
                          if (isChecked) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                              'DONT_SHOW_AIRPLANE_PROMPT',
                              true,
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                          onStartSession();
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static void watchAdForAction(
    BuildContext context, {
    required String promptText,
    required VoidCallback onReward,
  }) {
    AppTheme theme = context.read();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.brandDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.play_circle_fill, color: Color(0xFFF59E0B), size: 24),
            8.horizontalSpace,
            PrimaryText(
              text: 'Unlock with Ad',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ],
        ),
        content: SecondaryText(
          text: promptText,
          color: Colors.white70,
          fontSize: 13,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: SecondaryText(
              text: 'Cancel',
              color: Colors.white38,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Show progress spinner
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                  ),
                ),
              );

              AdService.instance.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  Navigator.pop(context); // Dismiss spinner
                  onReward();
                },
                onAdFailedToShow: () {
                  Navigator.pop(context); // Dismiss spinner
                  context.showInAppNotification(
                    "Ad not ready yet. Please try again in a few seconds.",
                    type: InAppNotificationType.error,
                  );
                },
              );
            },
            child: PrimaryText(
              text: 'Watch Ad',
              color: theme.primaryBase,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static void _watchAdForFeature(BuildContext context, String feature, VoidCallback? onAdUnlocked) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    AdService.instance.showRewardedAd(
      onUserEarnedReward: (ad, reward) async {
        if (context.mounted) {
          Navigator.pop(context); // Dismiss spinner
        }
        
        await incrementAdUnlockCount();

        if (!context.mounted) return;

        if (feature == 'Daily Explanation') {
          await context.read<AppAuthProvider>().rewardExplanationCount();
          if (context.mounted) {
            context.showInAppNotification(
              "Rewarded! You earned 1 more Daily Explanation.",
              type: InAppNotificationType.success,
            );
          }
        } else if (feature == 'Unlimited AI Chat') {
          context.read<ChatProvider>().rewardMessageCount();
          context.showInAppNotification(
            "Rewarded! You earned 1 more chat message.",
            type: InAppNotificationType.success,
          );
        } else if (feature == 'AI Decision Analysis') {
          await context.read<AppAuthProvider>().rewardDecisionCredit();
          if (context.mounted) {
            context.showInAppNotification(
              "Rewarded! You earned 1 more Decision credit.",
              type: InAppNotificationType.success,
            );
          }
        } else {
          context.showInAppNotification(
            "Rewarded! Premium feature unlocked temporarily.",
            type: InAppNotificationType.success,
          );
        }

        if (onAdUnlocked != null) {
          onAdUnlocked();
        }
      },
      onAdFailedToShow: () {
        if (context.mounted) {
          Navigator.pop(context); // Dismiss spinner
          context.showInAppNotification(
            "Ad not ready yet. Please try again in a few seconds.",
            type: InAppNotificationType.error,
          );
        }
      },
    );
  }
}

void safePrint(Object? object) {
  if (kDebugMode) {
    print(object);
  }
}

class TimeTeller {
  static String tellTimeOfTheDay() {
    int hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 16) {
      return 'Good Afternoon';
    } else if (hour >= 16 && hour < 24) {
      return 'Good Evening';
    } else {
      return 'Good Day';
    }
  }
}

mixin FormMixin<T extends StatefulWidget> on State<T> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AutovalidateMode? autoValidateMode;

  void validate(VoidCallback callback, {VoidCallback? orElse}) {
    final FormState? formState = formKey.currentState;

    if (formState != null && formState.validate() != false) {
      FocusScope.of(context).unfocus();
      formState.save();
      callback();
    } else {
      setState(() => autoValidateMode = AutovalidateMode.onUserInteraction);
      orElse?.call();
    }
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  set isLoading(bool isLoading) {
    if (!mounted) return;
    setState(() => _isLoading = isLoading);
  }

  FutureOr load<R>(Future<R> Function() action) async {
    isLoading = true;
    R result = await action();
    isLoading = false;
    return result;
  }
}
