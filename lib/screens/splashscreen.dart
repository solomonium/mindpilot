import 'dart:async';

import 'package:mindpilot/export.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  int notificationCounter = -1;

  late AnimationController animationController;
  late Animation<double> animation;
  Future<Timer> startTime() async {
    var duration = const Duration(seconds: 4);
    return Timer(duration, navigationPage);
  }

  void navigationPage() async {
    bool? isFirstTimeUser = await SharedPrefs.getBool('isFirstTime');
    Map<String, dynamic>? userMap = await SharedPrefs.getMap('USER_DETAILS');

    safePrint('First Timer User? $isFirstTimeUser');

    if (isFirstTimeUser != null && isFirstTimeUser == false) {
      if (userMap.isNotEmpty) {
        /// Restore user into provider

        context.pushOff(MainScreen());
      } else {
        context.pushOff(const LoginScreen());
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
    safePrint('Opening splash screen');
    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: animation.value * 100,
                height: animation.value * 100,
                child: SvgPicture.asset(R.png.twezi.svg),
                // Image.asset("assets/images/transit_ease.png"),
              ),
              SecondaryText(text: R.S.comFinanceMadeSimple, fontSize: 13),
            ],
          ),
        ],
      ),
    );
  }
}
