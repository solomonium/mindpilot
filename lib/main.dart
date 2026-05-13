import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mindpilot/export.dart';
import 'package:mindpilot/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initializations that MUST happen before runApp
  try {
    await dotenv.load(fileName: ".env");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Critical Initialization failed: $e');
  }

  // 2. Initialize App Settings provider
  final appProvider = AppProvider();
  try {
    await appProvider.init();
  } catch (e) {
    debugPrint('AppProvider init failed: $e');
  }

  // 3. Start the app immediately to avoid black screen
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(
          create: (_) => JournalProvider()..loadInitialData(),
        ),
        ChangeNotifierProvider(create: (_) => TaskProvider()..loadTasks()),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider()..loadNotifications(),
        ),
        Provider<BuildContext>(create: (c) => c),
      ],
      child: const MyApp(),
    ),
  );

  // 4. Background initializations (don't block the UI)
  _initializeBackgroundServices();
}

Future<void> _initializeBackgroundServices() async {
  try {
    await GoogleSignIn.instance.initialize(
      clientId: dotenv.env['GOOGLE_SIGN_IN_CLIENT_ID'],
      serverClientId: dotenv.env['GOOGLE_SIGN_IN_SERVER_CLIENT_ID'],
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await NotificationService().initialize();

    final isAllowed = await NotificationService().isNotificationsEnabled();
    if (!isAllowed) {
      await NotificationService().requestPermissions();
    }
  } catch (e) {
    debugPrint('Background service initialization failed: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    AppTheme theme = AppTheme.fromType(appProvider.theme);
    return GestureDetector(
      onTap: () {
        AppHelper.unFocus();
      },
      child: Provider.value(
        value: theme,
        child: ScreenUtilInit(
          designSize: const Size(430, 932),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return MaterialApp(
              theme: theme.themeData,
              navigatorKey: R.N.navKey,
              title: "Mind Pilot",
              debugShowCheckedModeBanner: false,
              home: const AnimatedSplashScreen(),
              builder: (context, child) => MediaQuery(
                data: context.widthPx < 600
                    ? context.mq.copyWith(
                        textScaler: const TextScaler.linear(0.95),
                      )
                    : context.mq.copyWith(
                        textScaler: const TextScaler.linear(1),
                      ),
                child: InAppNotification(
                  key: R.N.notifyKey,
                  safeAreaPadding: MediaQuery.of(context).viewPadding,
                  minAlertHeight: 100.0,
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
