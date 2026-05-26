import 'dart:ui';
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
          margin: EdgeInsets.only(
            left: 18,
            right: 18,
            bottom: context.mq.padding.bottom > 0 ? context.mq.padding.bottom + 6 : 18,
          ),
          decoration: BoxDecoration(
            // High sheer frosted glass with a premium subtle purple-tinted base matching the active primary color
            color: theme.isDark 
                ? theme.brandDark.withOpacity(0.5) 
                : theme.primaryBase.withOpacity(0.07),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: theme.primaryBase.withOpacity(0.35), // More prominent purple-like border
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.primaryBase.withOpacity(0.18), // Richer glowing shadow matching your purple-like color
                blurRadius: 25,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22), // High Gaussian blur for an ultra-glassy look
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(
                    items.length,
                    (index) => _NavItem(
                      index: index,
                      icon: items[index]['icon'],
                      title: items[index]['label'],
                      isSelected: store.navIndex == index,
                      onPressed: () => store.navIndex = index,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.icon,
    required this.title,
    required this.isSelected,
    this.onPressed,
  });

  final int index;
  final dynamic icon;
  final String title;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final user = context.watch<AppAuthProvider>().user;
    
    return Consumer<HomeProvider>(
      builder: (context, home, _) {
        if (index == 2) {
          // Prominent circular center button matching mockup design
          return InkWell(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: onPressed,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.primaryBase,
                    theme.primaryBase.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryBase.withOpacity(isSelected ? 0.5 : 0.3),
                    blurRadius: isSelected ? 12 : 8,
                    spreadRadius: isSelected ? 2 : 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: icon is IconData
                    ? Icon(
                        icon,
                        color: Colors.white,
                        size: 26,
                      )
                    : SvgPicture.asset(
                        icon,
                        color: Colors.white,
                        width: 24,
                        height: 24,
                      ),
              ),
            ),
          );
        }

        // Standard navigation items
        return InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: (title.toLowerCase() == 'profile' && user?.photoURL != null)
                      ? Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: NetworkImage(user!.photoURL!),
                              fit: BoxFit.cover,
                            ),
                            border: Border.all(
                              color: isSelected ? theme.primaryBase : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                        )
                      : icon is IconData
                          ? Icon(
                              icon,
                              color: isSelected ? theme.primaryBase : theme.secondaryTxt.withOpacity(0.75),
                              size: 24,
                            )
                          : SvgPicture.asset(
                              icon,
                              color: isSelected ? theme.primaryBase : theme.secondaryTxt.withOpacity(0.75),
                              width: 24,
                              height: 24,
                            ),
                ),
                6.verticalSpace,
                SecondaryText(
                  text: title,
                  color: isSelected ? theme.primaryBase : theme.secondaryTxt.withOpacity(0.75),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
