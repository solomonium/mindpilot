// ignore_for_file: must_be_immutable

import 'package:mindpilot/export.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool firstSwipe = true;

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return WillPopScope(
      onWillPop: () async {
        final homeProvider = context.read<HomeProvider>();
        if (homeProvider.navIndex != 0) {
          homeProvider.navIndex = 0;
          return false;
        } else {
          if (firstSwipe) {
            firstSwipe = false;
            return false;
          } else {
            return true;
          }
        }
      },
      child: Consumer<HomeProvider>(
        builder: (context, store, child) {
          return Stack(
            children: [
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
                        theme.brandDark.withOpacity(0.2),
                        theme.brandDark.withOpacity(0.6),
                        theme.brandDark,
                      ],
                    ),
                  ),
                ),
              ),
              Scaffold(
                backgroundColor: Colors.transparent,
                floatingActionButton: const GlowingChatFab(),
                bottomNavigationBar: const BottomNav(),
                body: IndexedStack(
                  index: store.navIndex,
                  children: const [
                    HomeScreen(),
                    FocusSessionScreen(),
                    JournalScreen(),
                    ProgressScreen(),
                    ProfileScreen(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
