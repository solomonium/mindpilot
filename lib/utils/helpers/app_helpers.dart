import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mindpilot/export.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class AppHelper {
  static void unFocus() {
    WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
  }

  static void showPaywall(BuildContext context, {String? feature}) {
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
                    32.verticalSpace,
                    CustomButton(
                      label: 'Upgrade Now',
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(const UpgradeScreen());
                      },
                    ),
                    16.verticalSpace,
                    SecondaryText(
                      text: 'Monthly & Yearly plans available',
                      fontSize: 11,
                      color: Colors.white38,
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

  static void showUpdatePrompt(BuildContext context, {required String version, bool force = false}) {
    AppTheme theme = context.read();
    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (context) => WillPopScope(
        onWillPop: () async => !force,
        child: AlertDialog(
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
                        text: 'A new version ($version) of MindPilot is ready. Update now for better performance and new AI features.',
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

  static Future<void> launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
    } catch (e) {
      safePrint('Could not launch $url: $e');
    }
  }

  static Widget _benefitRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF10B981), size: 18),
        16.horizontalSpace,
        SecondaryText(text: text, color: Colors.white, fontSize: 13),
      ],
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
