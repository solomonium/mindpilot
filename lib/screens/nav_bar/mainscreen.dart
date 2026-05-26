// ignore_for_file: must_be_immutable

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:mindpilot/export.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool firstSwipe = true;
  StreamSubscription<DocumentSnapshot>? _feedbackSubscription;
  bool _lastFeedbackFlag = false;

  @override
  void initState() {
    super.initState();
    AppHelper.setScreenshotProtection(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptPermissions();
      _listenForFeedbackToggle();
      _handlePendingNotification();
    });
  }

  void _handlePendingNotification() {
    final payload = NotificationService().consumePendingPayload();
    if (payload != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        NotificationService().handleNotificationClick(payload);
      });
    }
  }

  @override
  void dispose() {
    _feedbackSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAndPromptPermissions() async {
    final notificationService = NotificationService();
    final isAllowed = await notificationService.isNotificationsEnabled();
    if (!isAllowed) {
      await notificationService.requestPermissions();
    }

    if (Platform.isAndroid) {
      bool hasFullScreen = await notificationService.canUseFullScreenIntent();
      bool hasOverlay = await notificationService.canDrawOverlays();

      if (!hasFullScreen || !hasOverlay) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  backgroundColor: const Color(0xFF13111C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.alarm_on_rounded,
                        color: Colors.deepPurpleAccent,
                        size: 40,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Optimize Alarm Experience',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'To automatically launch your focus sessions at the exact start time (even when your screen is locked or the app is minimized), please enable the following permissions:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Full screen permission row
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF221F35),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.deepPurpleAccent,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Full Screen Alarms',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasFullScreen ? 'Permission granted' : 'Allows alarm to wake screen',
                                    style: TextStyle(
                                      color: hasFullScreen ? Colors.greenAccent : const Color(0xFFB8B5D0),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasFullScreen)
                              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 24)
                            else
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                onPressed: () async {
                                  await notificationService.openFullScreenIntentSettings();
                                  await Future.delayed(const Duration(milliseconds: 1000));
                                  final res = await notificationService.canUseFullScreenIntent();
                                  setState(() {
                                    hasFullScreen = res;
                                  });
                                },
                                child: const Text(
                                  'Configure',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Overlay permission row
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF221F35),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.picture_in_picture_rounded,
                              color: Colors.deepPurpleAccent,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Display Over Other Apps',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasOverlay ? 'Permission granted' : 'Bypasses background activity blocks',
                                    style: TextStyle(
                                      color: hasOverlay ? Colors.greenAccent : const Color(0xFFB8B5D0),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasOverlay)
                              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 24)
                            else
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                onPressed: () async {
                                  await notificationService.openOverlaySettings();
                                  await Future.delayed(const Duration(milliseconds: 1000));
                                  final res = await notificationService.canDrawOverlays();
                                  setState(() {
                                    hasOverlay = res;
                                  });
                                },
                                child: const Text(
                                  'Configure',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actionsAlignment: MainAxisAlignment.spaceBetween,
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Not Now',
                        style: TextStyle(
                          color: Color(0xFFB8B5D0),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      ),
                      onPressed: () async {
                        final screenRes = await notificationService.canUseFullScreenIntent();
                        final overlayRes = await notificationService.canDrawOverlays();
                        
                        setState(() {
                          hasFullScreen = screenRes;
                          hasOverlay = overlayRes;
                        });

                        if (hasFullScreen && hasOverlay) {
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            context.showInAppNotification(
                              'Permissions verified! Alarms will launch automatically.',
                              type: InAppNotificationType.success,
                            );
                          }
                        } else {
                          if (context.mounted) {
                            context.showInAppNotification(
                              'Please configure both permissions to enable automatic alarms.',
                              type: InAppNotificationType.error,
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Verify & Start',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      }
    }
  }

  void _listenForFeedbackToggle() {
    _feedbackSubscription = FirebaseFirestore.instance
        .collection('app_config')
        .doc('settings')
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>?;
      final showFeedback = data?['showFeedbackCard'] ?? false;

      // Only trigger on a false -> true transition
      if (showFeedback && !_lastFeedbackFlag) {
        _lastFeedbackFlag = true;
        AppHelper.showFeedbackPrompt(context);
      } else {
        _lastFeedbackFlag = showFeedback;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        final homeProvider = context.read<HomeProvider>();
        if (homeProvider.navIndex != 0) {
          homeProvider.navIndex = 0;
        } else {
          SystemNavigator.pop();
        }
      },
      child: Consumer<HomeProvider>(
        builder: (context, store, child) {
          return Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.6,
                  child: Image.asset(R.png.loginBg.png, fit: BoxFit.cover),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.brandDark.withOpacity(0.2),
                        theme.brandDark.withOpacity(0.6),
                        theme.brandDark,
                      ],
                    ),
                  ),
                ),
              ),
              Scaffold(
                backgroundColor: Colors.transparent,
                extendBody: true,
                floatingActionButton: const GlowingChatFab(),
                bottomNavigationBar: const BottomNav(),
                body: IndexedStack(
                  index: store.navIndex,
                  children: const [
                    HomeScreen(),
                    FocusSessionScreen(),
                    DecisionAnalyzerScreen(),
                    JournalEntriesScreen(),
                    ProfileScreen(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
