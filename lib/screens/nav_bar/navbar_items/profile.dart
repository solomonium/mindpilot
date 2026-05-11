import 'package:mindpilot/export.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _menuItem(context, Icons.person_outline, 'Personal Information', onTap: () {
                  context.push(const PersonalInformationScreen());
                }),
                _menuItem(context, Icons.trending_up, 'My Progress', onTap: () {
                  context.push(const ProgressReportScreen());
                }),
                _menuItem(context, Icons.settings_outlined, 'App Preferences', onTap: () {
                  context.push(const AppPreferencesScreen());
                }),
                _menuItem(context, Icons.psychology_outlined, 'AI Preferences'),
                _menuItem(context, Icons.notifications_none, 'Reminders'),
                _menuItem(context, Icons.lock_outline, 'Privacy & Security'),
                _menuItem(context, Icons.help_outline, 'Help & Support'),
                _menuItem(context, Icons.logout, 'Log Out', isLast: true, onTap: () {
                  context.pushOff(const LoginScreen());
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    AppTheme theme = context.watch();
    final user = context.watch<AuthProvider>().user;

    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 30),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: theme.primaryGradient,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: theme.primaryBase.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: theme.accentTxt.withOpacity(0.1), shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 45,
              backgroundColor: theme.primaryBase.withOpacity(0.1),
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null ? Icon(Icons.person, color: theme.accentTxt, size: 40) : null,
            ),
          ),
          16.verticalSpace,
          PrimaryText(text: user?.displayName ?? 'User Name', color: theme.accentTxt, fontSize: 20, fontWeight: FontWeight.bold),
          4.verticalSpace,
          SecondaryText(text: user?.email ?? 'user@example.com', color: theme.accentTxt.withOpacity(0.7), fontSize: 13),
          16.verticalSpace,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: theme.accentTxt.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                8.horizontalSpace,
                PrimaryText(text: 'Pro Member', color: theme.accentTxt, fontSize: 12, fontWeight: FontWeight.bold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String title, {bool isLast = false, VoidCallback? onTap}) {
    AppTheme theme = context.watch();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: theme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: theme.primaryBase.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.accentTxt.withOpacity(0.8), size: 22),
          16.horizontalSpace,
          Expanded(child: PrimaryText(text: title, fontSize: 15, fontWeight: FontWeight.w500, color: theme.accentTxt)),
          Icon(Icons.chevron_right, color: theme.accentTxt.withOpacity(0.3)),
        ],
      ),
    ).rippleClick(onTap);
  }
}
