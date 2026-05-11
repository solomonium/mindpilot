import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mindpilot/export.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await dotenv.load(fileName: ".env");
    await GoogleSignIn.instance.initialize(
      clientId: '802202587833-dhe5c6sbcpvbtj020dr9bmin2ovqhipk.apps.googleusercontent.com',
      serverClientId: '802202587833-rqih2hp4dmur1lrqku0dq08bblf6ng6m.apps.googleusercontent.com',
    );
    
    // Register background handler globally
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Initialization failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => JournalProvider()..loadInitialData()),
        ChangeNotifierProvider(create: (_) => TaskProvider()..loadTasks()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()..loadNotifications()),
        Provider<BuildContext>(create: (c) => c),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    // var themeType = context.select<AppProvider, ThemeType>((val) => val.theme);
    // AppTheme theme = AppTheme.fromType(themeType);
    AppTheme theme = AppTheme.fromType(ThemeType.light);
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
