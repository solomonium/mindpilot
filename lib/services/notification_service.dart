import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:mindpilot/export.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final serverTitle = message.notification?.title ?? message.data['title'];
  final serverBody = message.notification?.body ?? message.data['body'];
  if (serverTitle == null && serverBody == null) {
    print('Silent background message received (no title/body). Skipping.');
    return;
  }

  final isEnabled =
      await SharedPrefs.getBool('PUSH_NOTIFICATIONS_ENABLED') ?? false;
  final type = message.data['type'] ?? 'update';

  if (!isEnabled && type != 'insight' && type != 'admin_alert') {
    return;
  }

  final dbHelper = DatabaseHelper();
  final title = serverTitle ?? 'MindPilot';
  final body = serverBody ?? '';

  // Debug log for Admin
  print('--- [FCM BACKGROUND PAYLOAD] ---');
  print('Data: ${message.data}');
  print('-------------------------------');

  await dbHelper.insertNotification({
    'title': title,
    'body': body,
    'type': type,
    'date': DateTime.now().toIso8601String(),
    'isRead': 0,
    'author': message.data['author'],
    'source': message.data['source'],
  });

  final broadcastId = message.data['broadcastId'];
  if (broadcastId != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('LAST_BROADCAST_ID', broadcastId);
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _inviteAudioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;
  StreamSubscription? _playerCompleteSubscription;
  bool _inviteAudioInitialized = false;

  String? _pendingPayload;

  void setPendingPayload(String? payload) {
    _pendingPayload = payload;
  }

  String? consumePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return payload;
  }

  static const MethodChannel _permissionChannel = MethodChannel(
    'com.mindpilot.app/permissions',
  );

  Future<bool> canUseFullScreenIntent() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? result = await _permissionChannel.invokeMethod<bool>(
        'canUseFullScreenIntent',
      );
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> openFullScreenIntentSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _permissionChannel.invokeMethod<void>(
        'openFullScreenIntentSettings',
      );
    } catch (_) {}
  }

  Future<bool> canDrawOverlays() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? result = await _permissionChannel.invokeMethod<bool>(
        'canDrawOverlays',
      );
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> openOverlaySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _permissionChannel.invokeMethod<void>('openOverlaySettings');
    } catch (_) {}
  }

  /// Initializes the invite audio player with proper iOS playback session.
  Future<void> _ensureInviteAudioInitialized() async {
    if (_inviteAudioInitialized) return;
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
            options: {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      _inviteAudioInitialized = true;
    } catch (e) {
      safePrint('Error initializing invite audio context: $e');
    }
  }

  /// Plays the invite_voice.wav directly via AudioPlayer so it works
  /// reliably on iOS even when the app is in the foreground
  /// (iOS suppresses custom notification sounds for foreground apps).
  Future<void> playInviteVoiceSound() async {
    try {
      await _ensureInviteAudioInitialized();
      await _inviteAudioPlayer.stop();
      await _inviteAudioPlayer.setSource(AssetSource('audio/invite_voice.wav'));
      await _inviteAudioPlayer.resume();
    } catch (e) {
      safePrint('Error playing invite voice sound: $e');
    }
  }

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        handleNotificationClick(details.payload);
      },
    );

    try {
      final NotificationAppLaunchDetails? notificationAppLaunchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (notificationAppLaunchDetails != null &&
          notificationAppLaunchDetails.didNotificationLaunchApp) {
        final NotificationResponse? notificationResponse =
            notificationAppLaunchDetails.notificationResponse;
        if (notificationResponse != null &&
            notificationResponse.payload != null) {
          setPendingPayload(notificationResponse.payload);
        }
      }
    } catch (_) {}

    tz.initializeTimeZones();
    try {
      final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    if (Platform.isAndroid) {
      const AndroidNotificationChannel generalChannel =
          AndroidNotificationChannel(
            'mindpilot_notifications',
            'General Notifications',
            description: 'Used for important updates and insights',
            importance: Importance.max,
          );

      const AndroidNotificationChannel taskChannel = AndroidNotificationChannel(
        'task_alarm_channel_v5',
        'Task Alarms',
        description: 'Alarms for scheduled tasks',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

      const AndroidNotificationChannel focusChannel = AndroidNotificationChannel(
        'focus_complete_channel_v2',
        'Focus Session Completion',
        description: 'Alarms when a focus session finishes',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

      const AndroidNotificationChannel inviteChannel = AndroidNotificationChannel(
        'group_invite_channel_v1',
        'Group Invitations',
        description: 'Notifications for Bible quiz group invitations',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('invite_voice'),
        enableVibration: true,
      );

      const AndroidNotificationChannel gameStartChannel = AndroidNotificationChannel(
        'group_game_start_channel_v1',
        'Group Game Starts',
        description: 'Notifications for Bible quiz game starts',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('quiz_started'),
        enableVibration: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidPlugin?.createNotificationChannel(generalChannel);
      await androidPlugin?.createNotificationChannel(taskChannel);
      await androidPlugin?.createNotificationChannel(focusChannel);
      await androidPlugin?.createNotificationChannel(inviteChannel);
      await androidPlugin?.createNotificationChannel(gameStartChannel);
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    try {
      await _fcm.subscribeToTopic('all_users');
    } catch (_) {}

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _processMessage(message, isForeground: true);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _processMessage(message, isForeground: false, wasTapped: true);
    });

    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _processMessage(initialMessage, isForeground: false, wasTapped: true);
    }

    _startForegroundAlarmChecker();

    logDeviceToken();

    _fcm.onTokenRefresh.listen((token) {
      _syncTokenToProvider(token);
    });
  }







  void _syncTokenToProvider(String token) {
    final context = R.N.navKey.currentContext;
    if (context != null) {
      try {
        context.read<AppAuthProvider>().updateFcmToken(token);
      } catch (_) {}
    }
  }

  void _startForegroundAlarmChecker() {
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final now = DateTime.now();
        final tasks = await DatabaseHelper().getTasks();

        for (var task in tasks) {
          final startTime = task['startTime'] as String?;
          final isDone = (task['isDone'] == 1 || task['isDone'] == true);
          final taskId = task['id'] as int?;

          if (startTime != null && !isDone && taskId != null) {
            try {
              final DateFormat format = DateFormat('hh:mm a');
              final DateTime parsedTime = format.parse(startTime);

              var startDt = DateTime(
                now.year,
                now.month,
                now.day,
                parsedTime.hour,
                parsedTime.minute,
              );

              if (startDt.isBefore(now.subtract(const Duration(hours: 1)))) {
                startDt = startDt.add(const Duration(days: 1));
              }

              final alarmTime = startDt.subtract(const Duration(minutes: 2));
              final diff = now.difference(alarmTime).inSeconds;

              if (diff >= 0 && diff < 120) {
                if (!_playedAlarms.contains(taskId)) {
                  _playedAlarms.add(taskId);
                  playAlarmSound();

                  final duration = (task['durationMinutes'] as int?) ?? 25;
                  final payload =
                      'focus_session|$duration|${startDt.toIso8601String()}';
                  showForegroundNotification(
                    'Task Starting Soon',
                    'Your task "${task['title']}" starts in 2 minutes.',
                    payload,
                  );
                }
              }

              final startDiff = now.difference(startDt).inSeconds;
              if (startDiff >= 0 && startDiff < 15) {
                if (!_launchedTasks.contains(taskId)) {
                  _launchedTasks.add(taskId);

                  final duration = (task['durationMinutes'] as int?) ?? 25;

                  R.N.navKey.currentState?.push(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'FocusSessionScreen'),
                      builder: (_) => FocusSessionScreen(
                        initialDuration: duration,
                        autoStart: true,
                        scheduledStartTime: startDt,
                      ),
                    ),
                  );
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    });
  }

  final Set<int> _playedAlarms = {};
  final Set<int> _launchedTasks = {};

  Future<void> logDeviceToken() async {
    try {
      if (Platform.isIOS) {
        String? apnsToken;
        for (int i = 0; i < 10; i++) {
          apnsToken = await _fcm.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
        if (apnsToken == null) {
          safePrint("APNs token is null on iOS. Cannot fetch FCM token.");
          return;
        }
      }
      final token = await _fcm.getToken().timeout(const Duration(seconds: 15));
      if (token != null) {
        safePrint("Successfully retrieved FCM token: $token");
        _syncTokenToProvider(token);
      }
    } catch (e) {
      safePrint("Error retrieving FCM Token: $e");
    }
  }

  void _processMessage(
    RemoteMessage message, {
    bool isForeground = false,
    bool wasTapped = false,
  }) {
    final context = R.N.navKey.currentContext;
    if (context == null) return;

    final serverTitle = message.notification?.title ?? message.data['title'];
    final serverBody = message.notification?.body ?? message.data['body'];
    if (serverTitle == null && serverBody == null) {
      safePrint("Silent foreground message received (no title/body). Skipping.");
      return;
    }

    final isEnabled = context.read<AppProvider>().pushNotificationsEnabled;
    final type = message.data['type'] ?? 'update';

    if (!isEnabled && type != 'insight' && type != 'feedback' && type != 'group_invite' && type != 'group_game_start' && type != 'group_member_joined' && type != 'admin_alert') {
      return;
    }

    // Debug log for Admin
    safePrint('--- [FCM FOREGROUND PAYLOAD] ---');
    safePrint('Data: ${message.data}');
    safePrint('-------------------------------');

    final title = serverTitle ?? 'MindPilot';
    final body = serverBody ?? '';

    context.read<NotificationProvider>().addNotification({
      'title': title,
      'body': body,
      'type': type,
      'author': message.data['author'],
      'source': message.data['source'],
    }, broadcastId: message.data['broadcastId']);

    if (isForeground && type == 'feedback') {
      AppHelper.showFeedbackPrompt(context);
      return;
    }

    String payload = type;
    if (type == 'group_invite') {
      final groupId = message.data['groupId'] ?? '';
      final groupName = message.data['groupName'] ?? '';
      final invitationId = message.data['invitationId'] ?? '';
      payload = 'group_invite|$groupId|$groupName|$invitationId';
    } else if (type == 'group_game_start') {
      final groupId = message.data['groupId'] ?? '';
      payload = 'group_game_start|$groupId';
    } else if (type == 'group_member_joined') {
      final memberName = message.data['memberName'] ?? 'Someone';
      final groupName  = message.data['groupName'] ?? '';
      payload = 'group_member_joined|$memberName|$groupName';
    }

    // Play invite sound directly via AudioPlayer on iOS foreground
    // (iOS suppresses custom notification sounds when the app is active,
    // so we mirror what quiz_started does — use AudioPlayer directly).
    if (isForeground && type == 'group_invite') {
      playInviteVoiceSound();
    }

    if (isForeground && (isEnabled || type == 'group_invite' || type == 'group_member_joined' || type == 'admin_alert')) {
      showForegroundNotification(title, body, payload);
    }

    if (wasTapped) {
      handleNotificationClick(payload);
    }
  }

  Future<void> showForegroundNotification(
    String title,
    String body,
    String type,
  ) async {
    final isInvite = type.startsWith('group_invite');
    final isGameStart = type.startsWith('group_game_start');

    final androidDetails = AndroidNotificationDetails(
      isInvite ? 'group_invite_channel_v1' : (isGameStart ? 'group_game_start_channel_v1' : 'mindpilot_notifications'),
      isInvite ? 'Group Invitations' : (isGameStart ? 'Group Game Starts' : 'General Notifications'),
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: isInvite
          ? const RawResourceAndroidNotificationSound('invite_voice')
          : (isGameStart
              ? const RawResourceAndroidNotificationSound('quiz_started')
              : null),
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: isInvite ? 'invite_voice.wav' : (isGameStart ? 'quiz_started.wav' : null),
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: details,
      payload: type,
    );
  }

  Future<void> playAlarmSound() async {
    if (_isAlarmPlaying) return;
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );

      _isAlarmPlaying = true;
      int playCount = 0;

      _playerCompleteSubscription?.cancel();
      _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((
        _,
      ) async {
        playCount++;
        if (playCount < 5) {
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.resume();
        } else {
          await _audioPlayer.stop();
          _isAlarmPlaying = false;
          _playerCompleteSubscription?.cancel();
        }
      });

      await _audioPlayer.setSource(AssetSource('audio/alarm.mp3'));
      await _audioPlayer.resume();
    } catch (_) {
      _isAlarmPlaying = false;
      _playerCompleteSubscription?.cancel();
    }
  }

  Future<void> stopAlarmSound() async {
    try {
      await _audioPlayer.stop();
      _isAlarmPlaying = false;
      _playerCompleteSubscription?.cancel();
    } catch (_) {}
  }

  void handleNotificationClick(String? payload) {
    if (payload == null) return;

    if (payload.startsWith('focus_session|')) {
      playAlarmSound();
    }

    if (payload == 'update') {
      final context = R.N.navKey.currentContext;
      if (context != null) {
        context.push(const NotificationScreen());
      }
    } else if (payload == 'feedback') {
      final context = R.N.navKey.currentContext;
      if (context != null) {
        AppHelper.showFeedbackPrompt(context);
      }
    } else if (payload.startsWith('focus_session|')) {
      final context = R.N.navKey.currentContext;
      if (context != null) {
        final parts = payload.split('|');
        final duration = int.tryParse(parts[1]) ?? 30;
        final startDt = parts.length > 2 ? DateTime.tryParse(parts[2]) : null;

        context.push(
          FocusSessionScreen(
            initialDuration: duration,
            autoStart: true,
            scheduledStartTime: startDt,
          ),
        );
      }
    } else if (payload == 'daily_mood_check_in') {
      final context = R.N.navKey.currentContext;
      if (context != null) {
        context.push(const DailyMoodCheckInScreen());
      }
    } else if (payload == 'daily_bible_quiz') {
      final context = R.N.navKey.currentContext;
      if (context != null) {
        context.read<HomeProvider>().navIndex = 2;
      }
    } else if (payload.startsWith('meeting_rating|')) {
      // payload format: meeting_rating|eventId
      final context = R.N.navKey.currentContext;
      if (context != null) {
        final eventId = payload.split('|').length > 1 ? payload.split('|')[1] : '';
        safePrint('Meeting rating requested for event: $eventId');
        // Navigate to Daily Hub so user sees the meeting productivity section
        context.read<HomeProvider>().navIndex = 0;
      }
    } else if (payload.startsWith('group_invite|')) {
      final parts = payload.split('|');
      if (parts.length > 3) {
        final groupId = parts[1];
        final groupName = parts[2];
        final invitationId = parts[3];
        _showJoinGroupDialog(groupId, groupName, invitationId);
      }
    } else if (payload.startsWith('group_game_start|')) {
      final parts = payload.split('|');
      if (parts.length > 1) {
        final groupId = parts[1];
        final context = R.N.navKey.currentContext;
        if (context != null) {
          context.read<HomeProvider>().navIndex = 2; // Bible / Group Quiz tab
          Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: 'GroupLobbyScreen'),
              builder: (_) => GroupLobbyScreen(groupId: groupId),
            ),
          );
        }
      }
    } else if (payload.startsWith('group_member_joined|')) {
      // Creator gets a banner; no navigation needed (they're in the lobby)
      final parts = payload.split('|');
      final memberName = parts.length > 1 ? parts[1] : 'Someone';
      final groupName  = parts.length > 2 ? parts[2] : '';
      final context = R.N.navKey.currentContext;
      if (context != null && context.mounted) {
        context.showInAppNotification(
          '🎉 $memberName has joined${groupName.isNotEmpty ? ' "$groupName"' : ' your group'}!',
          type: InAppNotificationType.success,
        );
      }
    }
  }

  void _showJoinGroupDialog(String groupId, String groupName, String invitationId) {
    final context = R.N.navKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final theme = context.read<AppTheme>();
        return Material(
          type: MaterialType.transparency,
          child: AlertDialog(
            backgroundColor: theme.brandDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const PrimaryText(text: 'Group Invitation 📖'),
            content: SecondaryText(
              text: 'You have been invited to join the Bible Quiz group: "$groupName". Do you want to accept?',
              color: theme.accentTxt.withValues(alpha: 0.8),
            ),
            actions: <Widget>[
              TextButton(
                child: SecondaryText(text: 'Reject', color: theme.errorPrimary),
                onPressed: () async {
                  final provider = context.read<GroupQuizProvider>();
                  Navigator.of(dialogContext).pop();
                  try {
                    await provider.rejectInvitation(groupId, invitationId);
                    final navCtx = R.N.navKey.currentContext;
                    if (navCtx != null && navCtx.mounted) {
                      navCtx.showInAppNotification('Invitation rejected.');
                    }
                  } catch (e) {
                    safePrint("Error rejecting: $e");
                  }
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryBase,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const PrimaryText(text: 'Accept & Join', color: Colors.black, fontWeight: FontWeight.bold),
                onPressed: () async {
                  final provider = context.read<GroupQuizProvider>();
                  Navigator.of(dialogContext).pop();
                  try {
                    await provider.acceptInvitation(groupId, invitationId);
                    provider.listenToGroup(groupId);
                    
                    final navCtx = R.N.navKey.currentContext;
                    if (navCtx != null && navCtx.mounted) {
                      Navigator.of(navCtx).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'GroupLobbyScreen'),
                          builder: (_) => GroupLobbyScreen(groupId: groupId),
                        ),
                      );
                    }
                  } catch (e) {
                    safePrint("Error accepting: $e");
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Meeting Calendar Notifications ─────────────────────────────────────────

  /// Schedule a reminder 10 minutes before a meeting starts.
  Future<void> scheduleMeetingReminder({
    required String eventId,
    required String title,
    required DateTime startTime,
  }) async {
    final reminderTime = startTime.subtract(const Duration(minutes: 10));
    if (reminderTime.isBefore(DateTime.now())) return;

    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
      final String tz0 = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(tz0));
    }

    const androidDetails = AndroidNotificationDetails(
      'meeting_reminder_channel',
      'Meeting Reminders',
      channelDescription: 'Reminds you before a meeting starts',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.zonedSchedule(
      id: eventId.hashCode.abs() % 100000,
      title: '📅 Meeting in 10 min',
      body: title,
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'meeting_reminder',
    );
  }

  /// Schedule a post-meeting productivity rating request 5 minutes after a meeting ends.
  Future<void> scheduleMeetingRatingRequest({
    required String eventId,
    required String title,
    required DateTime endTime,
  }) async {
    final ratingTime = endTime.add(const Duration(minutes: 5));
    if (ratingTime.isBefore(DateTime.now())) return;

    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
      final String tz0 = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(tz0));
    }

    const androidDetails = AndroidNotificationDetails(
      'meeting_rating_channel',
      'Meeting Productivity',
      channelDescription: 'Asks how productive your meeting was',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.zonedSchedule(
      id: (eventId.hashCode.abs() % 100000) + 200000,
      title: '🚀 How was your meeting?',
      body: 'Rate how productive "$title" was',
      scheduledDate: tz.TZDateTime.from(ratingTime, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'meeting_rating|$eventId',
    );
  }

  /// Cancel both reminder and rating notifications for a given event.
  Future<void> cancelMeetingNotifications(String eventId) async {
    await _localNotifications.cancel(id: eventId.hashCode.abs() % 100000);
    await _localNotifications.cancel(id: (eventId.hashCode.abs() % 100000) + 200000);
  }

  Future<void> scheduleDailyReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reminders',
      channelDescription: 'Reminds you to check your task completion',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      id: 0,
      title: 'Task Completion Reminder',
      body: 'Did you finish all your tasks today? Check them off now!',
      scheduledDate: _nextInstanceOfNinePM(),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfNinePM() {
    try {
      tz.local;
    } catch (_) {
      return tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 21));
    }
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      21,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleTaskAlarm(
    String title,
    DateTime startTime,
    int duration,
  ) async {
    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
      final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    }

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestExactAlarmsPermission();
    }

    // 1. Schedule 2-minute warning notification with custom alarm sound
    final alarmTime = startTime.subtract(const Duration(minutes: 2));
    if (alarmTime.isAfter(DateTime.now())) {
      final tzAlarmTime = tz.TZDateTime.from(alarmTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'task_alarm_channel_v5',
        'Task Alarms',
        channelDescription: 'Alarms for scheduled tasks',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('alarm'),
        ticker: 'Task Reminder',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alarm.mp3',
        categoryIdentifier: 'task_alarm',
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.zonedSchedule(
        id: title.hashCode.abs(),
        title: 'Task Starting Soon',
        body:
            'Your task "$title" starts in 2 minutes. Prepare for your focus session!',
        scheduledDate: tzAlarmTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'focus_session|$duration|${startTime.toIso8601String()}',
      );
    }

    // 2. Schedule exact start-time notification with custom alarm sound and Full Screen Intent on Android (to auto-open app)
    if (startTime.isAfter(DateTime.now())) {
      final tzStartTime = tz.TZDateTime.from(startTime, tz.local);
      final bool hasFullScreenPermission = await canUseFullScreenIntent();

      final androidStartDetails = AndroidNotificationDetails(
        'task_alarm_channel_v5',
        'Task Alarms',
        channelDescription: 'Alarms for scheduled tasks',
        importance: Importance.max,
        priority: Priority.max,
        sound: RawResourceAndroidNotificationSound('alarm'),
        ticker: 'Task Starter',
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent:
            hasFullScreenPermission, // Dynamically use the permission status!
      );

      const iosStartDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alarm.mp3',
        categoryIdentifier: 'task_alarm',
      );
      final startDetails = NotificationDetails(
        android: androidStartDetails,
        iOS: iosStartDetails,
      );

      await _localNotifications.zonedSchedule(
        id: title.hashCode.abs() + 1,
        title: 'Task Starting Now!',
        body:
            'Your task "$title" is starting now. Let\'s begin the focus session!',
        scheduledDate: tzStartTime,
        notificationDetails: startDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'focus_session|$duration|${startTime.toIso8601String()}',
      );
    }
  }

  Future<void> scheduleFocusCompleteAlarm({
    required DateTime endTime,
    required String soundName,
  }) async {
    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
      final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    }

    final remainingSeconds = endTime.difference(DateTime.now()).inSeconds;
    // 🌍 Timezone-agnostic calculation: always schedules exactly remainingSeconds in the future relative to the active timezone!
    final tzEndTime = tz.TZDateTime.now(tz.local).add(Duration(seconds: remainingSeconds));

    // 🧠 Ultra-robust notification channel using standard high-importance system alerts
    final androidDetails = AndroidNotificationDetails(
      'focus_complete_channel_v2', // Clean new channel
      'Focus Session Completion',
      channelDescription:
          'Heads-up banner alerts when a focus session finishes',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'Focus Alarm',
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'alarm.mp3',
      categoryIdentifier: 'focus_complete',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Cancel any existing focus complete alarm first
    await cancelFocusCompleteAlarm();

    try {
      await _localNotifications.zonedSchedule(
        id: 8888, // Fixed ID for Focus Complete Alarm
        title: 'Focus Session Complete! 🧠',
        body: 'Great job! You finished your focus session.',
        scheduledDate: tzEndTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Exact schedule mode so it triggers on time when minimized
        payload: 'focus_complete_alarm',
      );
      safePrint('Successfully scheduled background focus completion notification at $tzEndTime (in $remainingSeconds seconds) with timezone ${tz.local.name}');
    } catch (e) {
      safePrint('Error scheduling focus complete notification: $e');
    }
  }

  Future<void> cancelFocusCompleteAlarm() async {
    await _localNotifications.cancel(id: 8888);
  }

  Future<void> showFocusCompleteNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'focus_complete_channel_v2',
      'Focus Session Completion',
      channelDescription:
          'Heads-up banner alerts when a focus session finishes',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'Focus Alarm',
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'alarm.mp3',
      categoryIdentifier: 'focus_complete',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        id: 8888,
        title: 'Focus Session Complete! 🧠',
        body: 'Great job! You finished your focus session.',
        notificationDetails: details,
        payload: 'focus_complete_alarm',
      );
      safePrint('Successfully showed immediate focus completion notification');
    } catch (e) {
      safePrint('Error showing immediate focus completion notification: $e');
    }
  }

  Future<void> cancelDailyReminder() async {
    await _localNotifications.cancel(id: 0);
  }

  Future<void> scheduleStreakAtRiskReminder(int streak) async {
    const androidDetails = AndroidNotificationDetails(
      'streak_reminder_channel',
      'Streak Reminders',
      channelDescription: 'Reminds you to keep your streak alive',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await cancelStreakAtRiskReminder();

    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
      final String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _localNotifications.zonedSchedule(
      id: 2,
      title: 'Streak at risk 🔥',
      body:
          'Your $streak-day streak ends tonight. Complete a focus session, journal entry, or decision to keep it alive.',
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'streak_at_risk',
    );
  }

  Future<void> cancelStreakAtRiskReminder() async {
    await _localNotifications.cancel(id: 2);
  }

  Future<void> scheduleMorningInsightReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'morning_insight_channel',
      'Morning Insights',
      channelDescription: 'Daily morning clarity reminder',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await cancelMorningInsightReminder();

    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
      final String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    }

    await _localNotifications.zonedSchedule(
      id: 3,
      title: 'Good morning ☀️',
      body: 'Your daily insight is waiting. Open MindPilot for clarity.',
      scheduledDate: _nextInstanceOfMorning(),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'morning_insight',
    );
  }

  Future<void> cancelMorningInsightReminder() async {
    await _localNotifications.cancel(id: 3);
  }

  tz.TZDateTime _nextInstanceOfMorning() {
    try {
      tz.local;
    } catch (_) {
      return tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 8));
    }
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      8,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<bool> isNotificationsEnabled() async {
    final settings = await _fcm.getNotificationSettings();
    final fcmAllowed =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!fcmAllowed) return false;

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }

    return fcmAllowed;
  }

  Future<bool> requestPermissions() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    bool isAuthorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      final bool? grantedNotificationPermission = await androidImplementation
          ?.requestNotificationsPermission();
      isAuthorized = isAuthorized && (grantedNotificationPermission ?? false);
    } else if (Platform.isIOS) {
      final iosImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      isAuthorized = isAuthorized && (granted ?? false);
    }

    return isAuthorized;
  }

  Future<void> scheduleDailyMoodCheckInReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'daily_mood_check_in_channel',
      'Daily Mood Check-In',
      channelDescription: 'Reminds you to check in and log your daily mood',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await cancelDailyMoodCheckInReminder();

    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
      final String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    }

    await _localNotifications.zonedSchedule(
      id: 4,
      title: 'Daily Mood Check-In 🧠',
      body: 'How was your day? Tap to log your mood and get a daily tip.',
      scheduledDate: _nextInstanceOfEightThirtyPM(),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_mood_check_in',
    );
  }

  Future<void> cancelDailyMoodCheckInReminder() async {
    await _localNotifications.cancel(id: 4);
  }

  tz.TZDateTime _nextInstanceOfEightThirtyPM() {
    try {
      tz.local;
    } catch (_) {
      return tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 20, minutes: 30));
    }
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      20,
      30,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleDailyBibleQuizReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'daily_bible_quiz_channel',
      'Daily Bible Quiz',
      channelDescription: 'Reminds you to test your knowledge with a daily Bible Quiz',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await cancelDailyBibleQuizReminder();

    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
      final String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    }

    await _localNotifications.zonedSchedule(
      id: 5,
      title: 'Daily Bible Quiz 📖',
      body: 'Ready to test your scripture knowledge? Start your daily quiz now!',
      scheduledDate: _nextInstanceOfTenPM(),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_bible_quiz',
    );
  }

  Future<void> cancelDailyBibleQuizReminder() async {
    await _localNotifications.cancel(id: 5);
  }

  tz.TZDateTime _nextInstanceOfTenPM() {
    try {
      tz.local;
    } catch (_) {
      return tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 22));
    }
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      22,
      0,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleDailyGrowthPraiseReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'daily_growth_praise_channel',
      'Growth Praise',
      channelDescription: 'Daily praise notification for spiritual growth and knowledge',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await cancelDailyGrowthPraiseReminder();

    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
      final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    }

    await _localNotifications.zonedSchedule(
      id: 6,
      title: 'Growing in Knowledge 📖',
      body: 'You are making great progress! Keep studying and completing quizzes to build a stronger spiritual foundation.',
      scheduledDate: _nextInstanceOfSevenThirtyPM(),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_growth_praise',
    );
  }

  Future<void> cancelDailyGrowthPraiseReminder() async {
    await _localNotifications.cancel(id: 6);
  }

  tz.TZDateTime _nextInstanceOfSevenThirtyPM() {
    try {
      tz.local;
    } catch (_) {
      return tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 19, minutes: 30));
    }
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      19,
      30,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleWeeklyGrowthPraiseReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'weekly_growth_praise_channel',
      'Weekly Growth Praise',
      channelDescription: 'Weekly praise notification on Friday to keep up the momentum',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await cancelWeeklyGrowthPraiseReminder();

    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
      final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    }

    await _localNotifications.zonedSchedule(
      id: 7,
      title: 'Keep up the good work! 🌟',
      body: "Reflecting on a week of spiritual growth and learning. Let's keep this momentum going next week!",
      scheduledDate: _nextInstanceOfFridaySixPM(),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weekly_growth_praise',
    );
  }

  Future<void> cancelWeeklyGrowthPraiseReminder() async {
    await _localNotifications.cancel(id: 7);
  }

  tz.TZDateTime _nextInstanceOfFridaySixPM() {
    try {
      tz.local;
    } catch (_) {
      return tz.TZDateTime.now(tz.UTC).add(const Duration(days: 5));
    }
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      18,
      0,
    );
    while (scheduledDate.weekday != DateTime.friday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    return scheduledDate;
  }
}
