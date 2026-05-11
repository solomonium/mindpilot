import 'package:flutter/services.dart';
import 'package:mindpilot/export.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Consumer<HomeProvider>(
      builder: (context, store, child) {
        List<Map<String, dynamic>> items = Mock.navItems();

        return Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            color: theme.background,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                spreadRadius: 0,
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ...List.generate(
                    items.length,
                    (index) => _NavItem(
                      icon: items[index]['icon'],
                      title: items[index]['label'],
                      isSelected: store.navIndex == index,
                      onPressed: () => store.navIndex = index,
                    ),
                  ),
                ],
              ),
              10.verticalSpace,
            ],
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    this.onPressed,
  });

  final String icon;
  final String title;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Consumer<HomeProvider>(
      builder: (context, home, _) {
        return WillPopScope(
          onWillPop: () async {
            if (R.N.navKey.currentState!.canPop()) {
              R.N.navKey.currentState!.popUntil((route) => route.isFirst);
              return false;
            }
            SystemNavigator.pop();
            return true;
          },
          child: InkWell(
            splashColor: theme.primaryBase,
            onTap: onPressed,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                22.verticalSpace,
                SizedBox(
                  height: 24,
                  width: 24,
                  child: SvgPicture.asset(
                    icon,
                    color: isSelected ? theme.primaryBase : theme.secondaryTxt,
                  ),
                ),
                10.verticalSpace,
                SecondaryText(
                  text: title,
                  color: isSelected ? theme.primaryBase : theme.secondaryTxt,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
