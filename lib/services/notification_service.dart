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
  
  // Check if push notifications are enabled in settings
  final isEnabled = await SharedPrefs.getBool('PUSH_NOTIFICATIONS_ENABLED') ?? false;
  final type = message.data['type'] ?? 'update';

  if (!isEnabled && type != 'insight') {
    debugPrint('Background notification ignored: Push notifications are disabled and type is not insight.');
    return;
  }

  final dbHelper = DatabaseHelper();
  final title = message.notification?.title ?? message.data['title'] ?? 'MindPilot';
  final body = message.notification?.body ?? message.data['body'] ?? '';

  await dbHelper.insertNotification({
    'title': title,
    'body': body,
    'type': type,
    'date': DateTime.now().toIso8601String(),
    'isRead': 0,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;


  Future<void> initialize() async {
    safePrint('--- NOTIFICATION SERVICE INITIALIZING ---');
    
    // 2. Initialize Local Notifications Plugin FIRST
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');

    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationClick(details.payload);
      },
    );
    safePrint('Local Notifications Initialized');

    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      safePrint('Timezone set to: $timeZoneName');
    } catch (e) {
      debugPrint('Timezone initialization error: $e');
      // Fallback to UTC
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    // 3. Request permissions & Create Channel (now that plugin is ready)
    if (Platform.isAndroid) {
      safePrint('Creating Notification Channels & Requesting Permission...');
      
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
    safePrint('FCM Permissions Requested');

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      safePrint('onMessage triggered');
      _processMessage(message, isForeground: true);
    });

    // Handle background click (tray tap)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      safePrint('onMessageOpenedApp triggered');
      _processMessage(message, isForeground: false, wasTapped: true);
    });

    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      safePrint('getInitialMessage triggered');
      _processMessage(initialMessage, isForeground: false, wasTapped: true);
    }
    safePrint('--- NOTIFICATION SERVICE INITIALIZED ---');
    _startForegroundAlarmChecker();
  }

  void _startForegroundAlarmChecker() {
    // Check every 10 seconds for upcoming alarms
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

              if (diff.abs() < 60) {
                safePrint('DEBUG: Checker watching task "${task['title']}" | Alarm in: ${-diff}s');
              }
              
              if (diff >= 0 && diff < 15) {
                if (!_playedAlarms.contains(taskId)) {
                  _playedAlarms.add(taskId);
                  playAlarmSound();
                  safePrint('ALARM TRIGGERED for task: ${task['title']}');
                  final payload = 'focus_session:${task['id']}:${startDt.toIso8601String()}';
                  showForegroundNotification('Task Starting Soon', 'Your task "${task['title']}" starts in 2 minutes.', payload);
                }
              }

              // --- AUTO-LAUNCH AT EXACT START TIME ---
              final startDiff = now.difference(startDt).inSeconds;
              if (startDiff >= 0 && startDiff < 15) {
                if (!_launchedTasks.contains(taskId)) {
                  _launchedTasks.add(taskId);
                  safePrint('AUTO-LAUNCHING Focus Session for: ${task['title']}');
                  
                  final duration = (task['durationMinutes'] as int?) ?? 25;
                  
                  // Use the global navigator key to push the focus screen
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

            } catch (e) {
              safePrint('DEBUG: Error parsing time for task "${task['title']}": $e');
            }
          }
        }
      } catch (e) {
        safePrint('DEBUG: Checker outer loop error: $e');
      }
    });
  }

  final Set<int> _playedAlarms = {};
  final Set<int> _launchedTasks = {};



  Future<void> logDeviceToken() async {
    try {
      safePrint('--- STARTING TOKEN TRACE ---');
      String? token = await _fcm.getToken().timeout(const Duration(seconds: 15));
      safePrint('--- DEVICE TOKEN RECOVERY ---');
      safePrint('TOKEN: ${token ?? "NULL"}');
      safePrint('--- END OF TOKEN TRACE ---');
    } catch (e) {
      safePrint('--- TOKEN TRACE FAILED ---');
      safePrint('REASON: $e');
    }
  }

  void _processMessage(RemoteMessage message, {bool isForeground = false, bool wasTapped = false}) {
    safePrint('--- INCOMING MESSAGE ---');
    safePrint('Is Foreground: $isForeground');
    safePrint('Was Tapped: $wasTapped');
    safePrint('Data: ${message.data}');
    safePrint('Notification Title: ${message.notification?.title}');
    safePrint('Notification Body: ${message.notification?.body}');
    final context = R.N.navKey.currentContext;
    if (context == null) {
      safePrint('Warning: Navigation context is NULL');
      return;
    }

    final isEnabled = context.read<AppProvider>().pushNotificationsEnabled;
    final type = message.data['type'] ?? 'update';

    if (!isEnabled && type != 'insight') {
      safePrint('Foreground notification ignored: Push notifications are disabled and type is not insight.');
      return;
    }

    final title = message.notification?.title ?? message.data['title'] ?? 'MindPilot';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    // Save to provider/database
    context.read<NotificationProvider>().addNotification({
      'title': title,
      'body': body,
      'type': type,
    });

    if (isForeground && isEnabled) {
      showForegroundNotification(title, body, type);
    }

    if (wasTapped && type == 'update') {
      _handleNotificationClick(type);
    }
  }

  Future<void> showForegroundNotification(String title, String body, String type) async {
    safePrint('Displaying foreground notification popup: $title');
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
      _isAlarmPlaying = true;
      // Using a standard alert sound URL similar to FocusSession
      await _audioPlayer.setSource(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
      await _audioPlayer.resume();
      
      // Stop after 5 seconds
      Future.delayed(const Duration(seconds: 5), () async {
        await _audioPlayer.stop();
        _isAlarmPlaying = false;
      });
    } catch (e) {
      safePrint('Error playing in-app alarm: $e');
      _isAlarmPlaying = false;
    }
  }

  void _handleNotificationClick(String? payload) {
    if (payload == null) return;
    
    // Play sound for all task-related notifications if in foreground
    if (payload.startsWith('focus_session:')) {
      playAlarmSound();
    }

    if (payload == 'update') {
      final context = R.N.navKey.currentContext;
      if (context != null) {
        // Navigate to notification page
        context.push(const NotificationScreen());
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

    // Schedule for 9:00 PM every day
    await _localNotifications.zonedSchedule(
      id: 0,
      title: 'Task Completion Reminder',
      body: 'Did you finish all your tasks today? Check them off now!',
      scheduledDate: _nextInstanceOfNinePM(),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    safePrint('Daily reminder scheduled for 9 PM');
  }

  tz.TZDateTime _nextInstanceOfNinePM() {
    try {
      tz.local;
    } catch (_) {
      // If uninitialized, we can't reliably get the local time yet.
      // This will be caught and initialized in scheduleTaskAlarm or initialize()
      return tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 21)); // Fallback
    }
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }


  Future<void> scheduleTaskAlarm(String title, DateTime startTime, int duration) async {
    // Ensure timezone is initialized
    try {
      tz.local;
    } catch (_) {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    }

    // Check permissions
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Try to request it directly if needed, or just rely on the init call
      await androidPlugin?.requestExactAlarmsPermission();
    }


    final alarmTime = startTime.subtract(const Duration(minutes: 2));


    if (alarmTime.isBefore(DateTime.now())) {
      safePrint('Alarm skipped: Start time is less than 2 minutes from now ($alarmTime)');
      return;
    }


    final tzAlarmTime = tz.TZDateTime.from(alarmTime, tz.local);
    safePrint('DEBUG: CURRENT TIME (TZ): ${tz.TZDateTime.now(tz.local)}');
    safePrint('DEBUG: SCHEDULED TIME (TZ): $tzAlarmTime');
    safePrint('DEBUG: ALARM TIME (DT): $alarmTime');

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


    safePrint('Task alarm scheduled for $alarmTime');
  }

  Future<void> cancelDailyReminder() async {
    await _localNotifications.cancel(id: 0);
    safePrint('Daily reminder cancelled');
  }

  Future<bool> isNotificationsEnabled() async {
    // Check FCM settings
    final settings = await _fcm.getNotificationSettings();
    final fcmAllowed = settings.authorizationStatus == AuthorizationStatus.authorized || 
                       settings.authorizationStatus == AuthorizationStatus.provisional;
    
    if (!fcmAllowed) return false;

    // Also check local notification status
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    } else if (Platform.isIOS) {
      // For iOS, FCM settings already cover the main notification permission
      return fcmAllowed;
    }
    
    return fcmAllowed;
  }

  Future<bool> requestPermissions() async {
    // 1. Request FCM Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    bool isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized || 
                       settings.authorizationStatus == AuthorizationStatus.provisional;

    // 2. Also request via Local Notifications (important for Android 13+)
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
