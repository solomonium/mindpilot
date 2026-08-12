import 'package:mindpilot/export.dart';
import 'package:mindpilot/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Failed to load .env file: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Initialization failed: $e');
  }

  // Initialize NotificationService before appProvider or any background tasks schedule reminders
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService initialization failed: $e');
  }

  // Initialize AdService / AdMob SDK
  try {
    await AdService.instance.initialize();
  } catch (e) {
    debugPrint('AdService initialization failed: $e');
  }

  final appProvider = AppProvider();
  try {
    await appProvider.init();
  } catch (e) {
    debugPrint('Init failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => FocusProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(
          create: (_) => JournalProvider()..loadInitialData(),
        ),
        ChangeNotifierProvider(create: (_) => TaskProvider()..loadTasks()),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider()..loadNotifications(),
        ),
        ChangeNotifierProvider(create: (_) => GroupQuizProvider()),
        Provider<BuildContext>(create: (c) => c),
      ],
      child: const MyApp(),
    ),
  );

  _initializeBackgroundServices();
}

Future<void> _initializeBackgroundServices() async {
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await AnalyticsService.logAppOpen();
    await PaymentService.initialize();
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
              navigatorObservers: [
                FirebaseAnalyticsObserver(
                  analytics: FirebaseAnalytics.instance,
                ),
              ],
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
