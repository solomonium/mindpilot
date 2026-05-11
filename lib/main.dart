import 'package:mindpilot/export.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
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
              title: "Twezi App",
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
