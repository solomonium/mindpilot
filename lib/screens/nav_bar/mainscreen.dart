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
      child: Scaffold(
        backgroundColor: theme.background,
        bottomNavigationBar: const BottomNav(),
        body: Consumer<HomeProvider>(
          builder: (context, store, child) {
            return IndexedStack(
              index: store.navIndex,
              children: [
                HomeScreen(),
                GroupScreen(),
                WalletScreen(),
                DirectScreen(),
                ProfileScreen(),
              ],
            );
          },
        ),
      ),
    );
  }
}
