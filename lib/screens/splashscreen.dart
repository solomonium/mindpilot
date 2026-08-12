// ignore_for_file: unused_local_variable

import 'dart:async';

import 'package:mindpilot/export.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> animation;

  Future<Timer> startTime() async {
    var duration = const Duration(seconds: 4);
    return Timer(duration, navigationPage);
  }

  void navigationPage() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final hasSeenPersonalization =
        prefs.getBool('HAS_SEEN_PERSONALIZATION') ?? false;

    if (!mounted) return;

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                throw TimeoutException('Network timeout');
              },
            );

        final data = doc.data();
        final name = data?['name'] as String? ?? '';
        final displayName = data?['displayName'] as String? ?? '';
        final fullName = data?['fullName'] as String? ?? '';

        if (doc.exists &&
            name.trim().isEmpty &&
            displayName.trim().isEmpty &&
            fullName.trim().isEmpty) {
          // Force sign out so their name can be extracted on their next login attempt
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            context.pushOff(const LoginScreen());
          }
          return;
        }

        final hasPersonalized = data?['hasCompletedSetup'] ?? false;

        if (mounted) {
          if (!hasPersonalized) {
            context.pushOff(const PersonalizationScreen());
          } else {
            context.pushOff(const MainScreen());
          }
        }
      } catch (e) {
        // If network fails or timeouts, proceed to MainScreen for offline access
        debugPrint('Splash Navigation Error: $e');
        if (mounted) context.pushOff(const MainScreen());
      }
    } else {
      context.pushOff(const LoginScreen());
    }
  }

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    );

    animation.addListener(() => setState(() {}));
    animationController.forward();

    NotificationService().logDeviceToken();
    startTime();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: theme.brandDark,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
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
                    theme.brandDark.withOpacity(0.4),
                    theme.brandDark.withOpacity(0.8),
                    theme.brandDark,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: animation.value * 150,
                  height: animation.value * 150,
                  child: Image.asset(
                    R.png.mindpilotApp.png,
                    fit: BoxFit.contain,
                  ),
                ),
                20.verticalSpace,
                SecondaryText(
                  text: 'Think clearly. Live intentionally.',
                  fontSize: 13,
                  color: theme.accentTxt.withOpacity(0.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
