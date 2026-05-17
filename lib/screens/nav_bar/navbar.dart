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
            color: theme.background.withOpacity(0.05),
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
        return InkWell(
          splashColor: Colors.transparent,
          onTap: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              22.verticalSpace,
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
                            color: isSelected ? theme.primaryBase : theme.secondaryTxt,
                          )
                        : SvgPicture.asset(
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
        );
      },
    );
  }
}
