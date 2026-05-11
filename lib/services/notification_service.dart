import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mindpilot/export.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  final dbHelper = DatabaseHelper();
  final type = message.data['type'] ?? 'update';
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

  Future<void> initialize() async {
    safePrint('--- NOTIFICATION SERVICE INITIALIZING ---');
    
    // 2. Initialize Local Notifications Plugin FIRST
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationClick(details.payload);
      },
    );
    safePrint('Local Notifications Initialized');

    // 3. Request permissions & Create Channel (now that plugin is ready)
    if (Platform.isAndroid) {
      safePrint('Creating Notification Channel & Requesting Permission...');
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'mindpilot_notifications',
        'General Notifications',
        description: 'Used for important updates and insights',
        importance: Importance.max,
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.requestNotificationsPermission();
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
  }

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

    final type = message.data['type'] ?? 'update';
    final title = message.notification?.title ?? message.data['title'] ?? 'MindPilot';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    // Save to provider/database
    context.read<NotificationProvider>().addNotification({
      'title': title,
      'body': body,
      'type': type,
    });

    if (isForeground) {
      _showForegroundNotification(title, body, type);
    }

    if (wasTapped && type == 'update') {
      _handleNotificationClick(type);
    }
  }

  Future<void> _showForegroundNotification(String title, String body, String type) async {
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

  void _handleNotificationClick(String? payload) {
    if (payload == 'update') {
      final context = R.N.navKey.currentContext;
      if (context != null) {
        // Navigate to notification page
        context.push(const NotificationScreen());
      }
    }
  }
}
