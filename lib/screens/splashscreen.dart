import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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
    final hasSeenPersonalization = prefs.getBool('HAS_SEEN_PERSONALIZATION') ?? false;

    if (!mounted) return;

    if (user != null) {
      context.pushOff(const MainScreen());
    } else {
      if (!hasSeenPersonalization) {
        context.pushOff(const PersonalizationScreen());
      } else {
        context.pushOff(const LoginScreen());
      }
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
                  width: animation.value * 200,
                  height: animation.value * 200,
                  child: Image.asset(R.png.mindpilotApp.png, fit: BoxFit.contain),
                ),
                4.verticalSpace,
                SecondaryText(
                  text: 'Think clearly. Live intentionally.', 
                  fontSize: 13, 
                  color: theme.accentTxt.withOpacity(0.8)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
