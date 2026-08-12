// ignore_for_file: must_be_immutable

import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
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

  // Invite voice sound player — plays invite_voice.wav the moment a new
  // pending invite appears in the Firestore StreamBuilder (the FCM path
  // is unreliable on iOS; Firestore snapshot is the source of truth).
  final AudioPlayer _inviteAudioPlayer = AudioPlayer();
  String? _lastPlayedInviteId; // prevents replaying on every rebuild

  Future<void> _playInviteVoice() async {
    try {
      await _inviteAudioPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
      await _inviteAudioPlayer.stop();
      await _inviteAudioPlayer.setSource(AssetSource('audio/invite_voice.wav'));
      await _inviteAudioPlayer.resume();
    } catch (e) {
      debugPrint('Error playing invite voice: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    AppHelper.setScreenshotProtection(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptPermissions();
      _checkAndPromptUnconfiguredPushNotifications();
      _listenForFeedbackToggle();
      _handlePendingNotification();
      _maybeShowChatFabTooltip();
      _checkClipboardForGroupInvite();
      _checkAndPromptHeardFrom();
    });
  }

  Future<void> _checkAndPromptHeardFrom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      if (!data.containsKey('heardFrom') ||
          data['heardFrom'] == null ||
          data['heardFrom'].toString().trim().isEmpty ||
          data['heardFrom'] == 'Unknown') {
        if (mounted) {
          _showHeardFromDialog();
        }
      }
    } catch (e) {
      debugPrint('Error checking heardFrom: $e');
    }
  }

  void _showHeardFromDialog() {
    final theme = context.read<AppTheme>();
    String? selectedOption;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: theme.brandDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const PrimaryText(text: 'Welcome to MindPilot! 👋'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SecondaryText(
                      text: 'Where did you hear about us?',
                      color: theme.accentTxt.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    16.verticalSpace,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.accentTxt.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.accentTxt.withOpacity(0.1),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedOption,
                          hint: SecondaryText(
                            text: 'Select an option',
                            color: theme.accentTxt.withOpacity(0.4),
                          ),
                          dropdownColor: theme.brandDark,
                          isExpanded: true,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: theme.accentTxt,
                          ),
                          items:
                              [
                                'Google Search',
                                'App Store / Play Store',
                                'Social Media (Instagram/TikTok/Twitter)',
                                'Reddit',
                                'Friend / Recommendation',
                                'Ad / Promotion',
                                'Other',
                              ].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: PrimaryText(
                                    text: value,
                                    fontSize: 14,
                                    color: theme.accentTxt,
                                  ),
                                );
                              }).toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedOption = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryBase,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: selectedOption == null
                        ? null
                        : () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update({'heardFrom': selectedOption});
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                    child: const PrimaryText(
                      text: 'Submit & Proceed',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _maybeShowChatFabTooltip() async {
    final shown = await SharedPrefs.getBool('CHAT_FAB_TOOLTIP_SHOWN') ?? false;
    if (shown || !mounted) return;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    await SharedPrefs.setBool('CHAT_FAB_TOOLTIP_SHOWN', true);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tap ASK anytime for personalized AI guidance'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Got it', onPressed: () {}),
      ),
    );
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
    _inviteAudioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkAndPromptPermissions() async {
    final notificationService = NotificationService();
    final isAllowed = await notificationService.isNotificationsEnabled();
    if (!isAllowed) {
      await notificationService.requestPermissions();
    }
  }

  Future<void> _checkAndPromptUnconfiguredPushNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final String? fcmToken = data?['fcmToken'] as String?;
      final bool promptTriggeredByAdmin =
          data?['promptPushNotification'] == true;

      // Check if global admin prompt timestamp exists
      final settingsDoc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .get();
      final Timestamp? globalPromptTs =
          settingsDoc.data()?['force_push_prompt_timestamp'] as Timestamp?;
      final int lastPrompted =
          await SharedPrefs.getInt('LAST_PUSH_PROMPT_TIME') ?? 0;
      final bool globalPromptDue =
          globalPromptTs != null &&
          globalPromptTs.millisecondsSinceEpoch > lastPrompted;

      final bool isUnconfigured = (fcmToken == null || fcmToken.trim().isEmpty);

      if ((isUnconfigured || promptTriggeredByAdmin || globalPromptDue) &&
          mounted) {
        // Show Push Notification Enable Sheet
        _showEnablePushNotificationSheet(user.uid, promptTriggeredByAdmin);
      }
    } catch (e) {
      debugPrint('Error checking push notification status: $e');
    }
  }

  void _showEnablePushNotificationSheet(String uid, bool isDirectAdminTrigger) {
    final theme = context.read<AppTheme>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return GlassContainer(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          gradient: theme.glassGradient,
          borderRadius: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.primaryBase.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: theme.primaryBase,
                  size: 36,
                ),
              ),
              16.verticalSpace,
              PrimaryText(
                text: 'Enable Push Notifications 🔔',
                color: theme.accentTxt,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
              ),
              8.verticalSpace,
              SecondaryText(
                text:
                    'Stay connected with daily growth insights, Bible quiz alerts, reflection prompts, and streak reminders directly on your phone.',
                color: theme.accentTxt.withOpacity(0.7),
                fontSize: 13,
                textAlign: TextAlign.center,
              ),
              20.verticalSpace,
              CustomButton(
                label: 'Enable Notifications Now',
                onPressed: () async {
                  Navigator.pop(bottomSheetContext);
                  await NotificationService().requestPermissions();
                  await NotificationService().logDeviceToken();
                  await SharedPrefs.setInt(
                    'LAST_PUSH_PROMPT_TIME',
                    DateTime.now().millisecondsSinceEpoch,
                  );

                  if (isDirectAdminTrigger) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .update({'promptPushNotification': false});
                  }

                  if (mounted) {
                    context.showInAppNotification(
                      'Push notifications configured successfully!',
                      type: InAppNotificationType.success,
                    );
                  }
                },
              ),
              10.verticalSpace,
              TextButton(
                onPressed: () async {
                  Navigator.pop(bottomSheetContext);
                  await SharedPrefs.setInt(
                    'LAST_PUSH_PROMPT_TIME',
                    DateTime.now().millisecondsSinceEpoch,
                  );
                },
                child: SecondaryText(
                  text: 'Remind Me Later',
                  color: theme.accentTxt.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> checkAndroidPermissions() async {
    final notificationService = NotificationService();
    if (Platform.isAndroid) {
      final alreadyPrompted =
          await SharedPrefs.getBool('FULL_SCREEN_PROMPT_SHOWN') ?? false;
      if (alreadyPrompted) return;

      bool hasFullScreen = await notificationService.canUseFullScreenIntent();

      if (!hasFullScreen) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: true,
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
                        'To automatically launch your focus sessions at the exact start time (even when your screen is locked or the app is minimized), please enable the following permission:',
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
                                    hasFullScreen
                                        ? 'Permission granted'
                                        : 'Allows alarm to wake screen',
                                    style: TextStyle(
                                      color: hasFullScreen
                                          ? Colors.greenAccent
                                          : const Color(0xFFB8B5D0),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasFullScreen)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.greenAccent,
                                size: 24,
                              )
                            else
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () async {
                                  await notificationService
                                      .openFullScreenIntentSettings();
                                  await Future.delayed(
                                    const Duration(milliseconds: 1000),
                                  );
                                  final res = await notificationService
                                      .canUseFullScreenIntent();
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
                    ],
                  ),
                  actionsAlignment: MainAxisAlignment.spaceBetween,
                  actions: [
                    TextButton(
                      onPressed: () async {
                        await SharedPrefs.setBool(
                          'FULL_SCREEN_PROMPT_SHOWN',
                          true,
                        );
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () async {
                        final screenRes = await notificationService
                            .canUseFullScreenIntent();

                        setState(() {
                          hasFullScreen = screenRes;
                        });

                        if (hasFullScreen) {
                          await SharedPrefs.setBool(
                            'FULL_SCREEN_PROMPT_SHOWN',
                            true,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            context.showInAppNotification(
                              'Permission verified! Alarms will launch automatically.',
                              type: InAppNotificationType.success,
                            );
                          }
                        } else {
                          if (context.mounted) {
                            context.showInAppNotification(
                              'Please configure the permission to enable automatic alarms.',
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
          final data = snapshot.data();
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

  Future<void> _checkClipboardForGroupInvite() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty) return;

      final inviteRegExp = RegExp(
        r'mindpilot-group-invite:([a-zA-Z0-9_-]+):([^\n]*)',
      );
      final match = inviteRegExp.firstMatch(text);
      if (match != null) {
        final groupId = match.group(1);
        final groupName = match.group(2)?.trim();
        if (groupId != null && groupName != null) {
          final lastPrompted = await SharedPrefs.getString(
            'LAST_PROMPTED_CLIPBOARD_INVITE',
          );
          if (lastPrompted == groupId) return;
          await SharedPrefs.setString(
            'LAST_PROMPTED_CLIPBOARD_INVITE',
            groupId,
          );

          // Clear clipboard text to avoid infinite prompting loops
          await Clipboard.setData(const ClipboardData(text: ''));

          if (!mounted) return;
          _showClipboardJoinDialog(groupId, groupName);
        }
      }
    } catch (e) {
      safePrint("Clipboard check error: $e");
    }
  }

  void _showClipboardJoinDialog(String groupId, String groupName) {
    AppTheme theme = context.read<AppTheme>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.brandDark,
          title: const PrimaryText(text: 'Join Quiz Group? 📖'),
          content: SecondaryText(
            text:
                'We found an invite code on your clipboard to join: "$groupName". Would you like to join?',
            color: theme.accentTxt.withOpacity(0.8),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: SecondaryText(
                text: 'Ignore',
                color: theme.accentTxt.withOpacity(0.6),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) {
                    context.showInAppNotification(
                      'Please sign in first to join groups.',
                    );
                    return;
                  }

                  final provider = context.read<GroupQuizProvider>();
                  await provider.directJoinGroup(groupId);
                  provider.listenToGroup(groupId);

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'GroupLobbyScreen'),
                        builder: (_) => GroupLobbyScreen(groupId: groupId),
                      ),
                    );
                  }
                } catch (e) {
                  safePrint("Error joining from clipboard: $e");
                }
              },
              child: PrimaryText(text: 'Join Room', color: theme.primaryBase),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final currentUser = FirebaseAuth.instance.currentUser;
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
                        theme.brandDark.withValues(alpha: 0.2),
                        theme.brandDark.withValues(alpha: 0.6),
                        theme.brandDark,
                      ],
                    ),
                  ),
                ),
              ),
              Scaffold(
                backgroundColor: Colors.transparent,
                extendBody: true,
                floatingActionButton: store.navIndex == 0
                    ? const GlowingChatFab()
                    : null,
                bottomNavigationBar: const BottomNav(),
                body: IndexedStack(
                  index: store.navIndex,
                  children: const [
                    HomeScreen(),
                    FocusSessionScreen(),
                    BibleMainScreen(),
                    DecisionAnalyzerScreen(),
                    ProfileScreen(),
                  ],
                ),
              ),
              if (currentUser != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('group_invitations')
                      .where('recipientUid', isEqualTo: currentUser.uid)
                      .where('status', isEqualTo: 'pending')
                      .limit(1)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final inviteDoc = snapshot.data!.docs.first;
                      final inviteData =
                          inviteDoc.data() as Map<String, dynamic>;
                      final invitationId = inviteDoc.id;
                      final groupId = inviteData['groupId'] ?? '';
                      final groupName = inviteData['groupName'] ?? '';
                      final senderName = inviteData['senderName'] ?? 'A friend';

                      // Play invite sound exactly once per new invite doc.
                      // This Firestore path is the reliable trigger on iOS
                      // (FCM/local-notification sounds are suppressed in foreground).
                      if (_lastPlayedInviteId != invitationId) {
                        _lastPlayedInviteId = invitationId;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _playInviteVoice();
                        });
                      }

                      if (store.navIndex != 0) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          store.navIndex = 0;
                        });
                      }

                      return Positioned.fill(
                        child: _buildBlockingInviteOverlay(
                          context,
                          theme,
                          invitationId,
                          groupId,
                          groupName,
                          senderName,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBlockingInviteOverlay(
    BuildContext context,
    AppTheme theme,
    String invitationId,
    String groupId,
    String groupName,
    String senderName,
  ) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withOpacity(0.95),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Center(
          child: GlassContainer(
            padding: const EdgeInsets.all(28),
            border: Border.all(
              color: theme.primaryBase.withOpacity(0.3),
              width: 1.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_unread_rounded,
                  color: Colors.deepPurpleAccent,
                  size: 50,
                ),
                16.verticalSpace,
                PrimaryText(
                  text: 'Pending Bible Quiz Invite! 📖',
                  color: theme.accentTxt,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  textAlign: TextAlign.center,
                ),
                16.verticalSpace,
                SecondaryText(
                  text:
                      '$senderName has invited you to join the Bible Quiz group "$groupName".',
                  color: theme.accentTxt.withOpacity(0.8),
                  fontSize: 14,
                  textAlign: TextAlign.center,
                ),
                24.verticalSpace,
                CustomButton(
                  label: 'Accept & Join',
                  backgroundColor: theme.primaryBase,
                  textColor: Colors.black,
                  onPressed: () async {
                    final provider = context.read<GroupQuizProvider>();
                    await provider.acceptInvitation(groupId, invitationId);
                    provider.listenToGroup(groupId);
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(
                            name: 'GroupLobbyScreen',
                          ),
                          builder: (_) => GroupLobbyScreen(groupId: groupId),
                        ),
                      );
                    }
                  },
                ),
                12.verticalSpace,
                CustomButton(
                  label: 'Reject Invite',
                  isOutline: true,
                  borderColor: theme.errorPrimary,
                  textColor: theme.errorPrimary,
                  onPressed: () async {
                    await context.read<GroupQuizProvider>().rejectInvitation(
                      groupId,
                      invitationId,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
