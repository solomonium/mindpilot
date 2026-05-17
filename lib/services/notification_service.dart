import 'dart:io';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:mindpilot/export.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  final isEnabled = await SharedPrefs.getBool('PUSH_NOTIFICATIONS_ENABLED') ?? false;
  final type = message.data['type'] ?? 'update';

  if (!isEnabled && type != 'insight') {
    return;
  }

  final dbHelper = DatabaseHelper();
  final title = message.notification?.title ?? message.data['title'] ?? 'MindPilot';
  final body = message.notification?.body ?? message.data['body'] ?? '';
  
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
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;
  StreamSubscription? _playerCompleteSubscription;


  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationClick(details.payload);
      },
    );

    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    if (Platform.isAndroid) {
      const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
        'mindpilot_notifications',
        'General Notifications',
        description: 'Used for important updates and insights',
        importance: Importance.max,
      );

      const AndroidNotificationChannel taskChannel = AndroidNotificationChannel(
        'task_alarm_channel',
        'Task Alarms',
        description: 'Alarms for scheduled tasks',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      await androidPlugin?.createNotificationChannel(generalChannel);
      await androidPlugin?.createNotificationChannel(taskChannel);
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }


    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

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
    
    _fcm.getToken().then((token) {
      if (token != null) {
        _syncTokenToProvider(token);
      }
    });

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
              
              var startDt = DateTime(now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);

              if (startDt.isBefore(now.subtract(const Duration(hours: 1)))) {
                startDt = startDt.add(const Duration(days: 1));
              }

              final alarmTime = startDt.subtract(const Duration(minutes: 2));
              final diff = now.difference(alarmTime).inSeconds;

              if (diff >= 0 && diff < 120) {
                if (!_playedAlarms.contains(taskId)) {
                  _playedAlarms.add(taskId);
                  playAlarmSound();
                  
                  final payload = 'focus_session:${task['id']}:${startDt.toIso8601String()}';
                  showForegroundNotification(
                    'Task Starting Soon', 
                    'Your task "${task['title']}" starts in 2 minutes.', 
                    payload
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
        final apnsToken = await _fcm.getAPNSToken();
        if (apnsToken == null) return;
      }
      await _fcm.getToken().timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  void _processMessage(RemoteMessage message, {bool isForeground = false, bool wasTapped = false}) {
    final context = R.N.navKey.currentContext;
    if (context == null) return;

    final isEnabled = context.read<AppProvider>().pushNotificationsEnabled;
    final type = message.data['type'] ?? 'update';

    if (!isEnabled && type != 'insight' && type != 'feedback') {
      return;
    }

    // Debug log for Admin
    safePrint('--- [FCM FOREGROUND PAYLOAD] ---');
    safePrint('Data: ${message.data}');
    safePrint('-------------------------------');

    final title = message.notification?.title ?? message.data['title'] ?? 'MindPilot';
    final body = message.notification?.body ?? message.data['body'] ?? '';

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

    if (isForeground && isEnabled) {
      showForegroundNotification(title, body, type);
    }

    if (wasTapped) {
      _handleNotificationClick(type);
    }
  }

  Future<void> showForegroundNotification(String title, String body, String type) async {
    const androidDetails = AndroidNotificationDetails(
      'mindpilot_notifications',
      'General Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

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
      await _audioPlayer.setAudioContext(AudioContext(
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
      ));

      _isAlarmPlaying = true;
      int playCount = 0;
      
      _playerCompleteSubscription?.cancel();
      _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) async {
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

  void _handleNotificationClick(String? payload) {
    if (payload == null) return;
    
    if (payload.startsWith('focus_session:')) {
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
    } else if (payload.startsWith('focus_session:')) {
      final context = R.N.navKey.currentContext;
      if (context != null) {
        final parts = payload.split(':');
        final duration = int.tryParse(parts[1]) ?? 30;
        final startDt = parts.length > 2 ? DateTime.tryParse(parts[2]) : null;
        
        context.push(FocusSessionScreen(
          initialDuration: duration, 
          autoStart: true,
          scheduledStartTime: startDt,
        ));
      }
    }
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
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

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

    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }


  Future<void> scheduleTaskAlarm(String title, DateTime startTime, int duration) async {
    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    }

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();
    }


    final alarmTime = startTime.subtract(const Duration(minutes: 2));

    if (alarmTime.isBefore(DateTime.now())) {
      return;
    }

    final tzAlarmTime = tz.TZDateTime.from(alarmTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'task_alarm_channel',
      'Task Alarms',
      channelDescription: 'Alarms for scheduled tasks',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Task Reminder',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'task_alarm',
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.zonedSchedule(
      id: title.hashCode.abs(),
      title: 'Task Starting Soon',
      body: 'Your task "$title" starts in 2 minutes. Prepare for your focus session!',
      scheduledDate: tzAlarmTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'focus_session:$duration:${startTime.toIso8601String()}',
    );
  }

  Future<void> cancelDailyReminder() async {
    await _localNotifications.cancel(id: 0);
  }

  Future<bool> isNotificationsEnabled() async {
    final settings = await _fcm.getNotificationSettings();
    final fcmAllowed = settings.authorizationStatus == AuthorizationStatus.authorized || 
                       settings.authorizationStatus == AuthorizationStatus.provisional;
    
    if (!fcmAllowed) return false;

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
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
    
    bool isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized || 
                       settings.authorizationStatus == AuthorizationStatus.provisional;

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      final bool? grantedNotificationPermission = await androidImplementation?.requestNotificationsPermission();
      isAuthorized = isAuthorized && (grantedNotificationPermission ?? false);
    } else if (Platform.isIOS) {
      final iosImplementation = _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final bool? granted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      isAuthorized = isAuthorized && (granted ?? false);
    }
    
    return isAuthorized;
  }
}
