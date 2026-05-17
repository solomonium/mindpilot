import 'package:flutter/services.dart';
import 'package:mindpilot/export.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
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
                    theme.brandDark.withOpacity(0.4),
                    theme.brandDark.withOpacity(0.8),
                    theme.brandDark,
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              _header(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (context.watch<AppAuthProvider>().isAdmin)
                      _menuItem(context, Icons.admin_panel_settings_outlined, 'Admin Privileges', isSpecial: true, onTap: () {
                        context.push(const AdminDashboardScreen());
                      }),
                    _menuItem(context, Icons.person_outline, 'Personal Information', onTap: () {
                      context.push(const PersonalInformationScreen());
                    }),


                    _menuItem(context, Icons.trending_up, 'My Progress', onTap: () {
                      context.push(const ProgressReportScreen());
                    }),
                    _menuItem(context, Icons.psychology_outlined, 'Refine Personalization', onTap: () {
                      context.push(const PersonalizationScreen());
                    }),
                    _menuItem(context, Icons.settings_outlined, 'App Preferences', onTap: () {
                      context.push(const AppPreferencesScreen());
                    }),

                    _menuItem(context, Icons.psychology_outlined, 'AI Preferences', onTap: () {
                      context.push(const AiPreferencesScreen());
                    }),


                    _menuItem(context, Icons.notifications_none, 'Reminders', onTap: () {
                      context.push(const AppPreferencesScreen(onlyNotifications: true));
                    }),
                    _menuItem(context, Icons.lock_outline, 'Privacy & Security', onTap: () {
                      context.push(const PrivacyScreen());
                    }),
                    _menuItem(context, Icons.help_outline, 'Help & Support', onTap: () {
                      context.push(const SupportScreen());
                    }),
                    _menuItem(context, Icons.share_outlined, 'Share App', onTap: () async {
                      final downloadUrl = ConfigService().updateUrl;
                      await Share.share(
                        "Download MindPilot to organize your thoughts, stay focused, and achieve your goals. Follow the link to download the app: $downloadUrl",
                        subject: 'MindPilot App',
                      );
                    }),
                    _menuItem(context, Icons.logout, 'Log Out', onTap: () {
                      _showLogoutConfirmation(context);
                    }),
                    _menuItem(context, Icons.delete_forever_outlined, 'Delete Account', onTap: () {
                      _showDeleteConfirmation(context);
                    }),
                    40.verticalSpace,
                    Center(
                      child: Column(
                        children: [
                          SecondaryText(
                            text: 'Developed by SolteQ Innovations Ltd',
                            color: theme.accentTxt.withOpacity(0.5),
                            fontSize: 12,
                          ),
                          4.verticalSpace,
                           SecondaryText(
                            text: 'v${ConfigService().currentAppVersion}',
                            color: theme.accentTxt.withOpacity(0.3),
                            fontSize: 10,
                          ),
                        ],
                      ),
                    ),

                    20.verticalSpace,
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();
    final authProvider = context.watch<AppAuthProvider>();
    final user = authProvider.user;
    final isPro = authProvider.userType == 'Pro Member';

    return GlassContainer(
      padding: const EdgeInsets.only(top: 60, bottom: 30),
      width: double.infinity,
      customBorderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
      gradient: theme.glassGradient,
      border: Border(bottom: BorderSide(color: theme.accentTxt.withOpacity(0.1), width: 1)),
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
          PrimaryText(
              text: user?.displayName ?? 'User Name',
              color: theme.accentTxt,
              fontSize: 20,
              fontWeight: FontWeight.bold),
          4.verticalSpace,
          SecondaryText(
              text: user?.email ?? 'user@example.com',
              color: theme.accentTxt.withOpacity(0.7),
              fontSize: 13),
          16.verticalSpace,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration:
                BoxDecoration(color: theme.accentTxt.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPro ? Icons.star : Icons.person_outline, 
                  color: isPro ? const Color(0xFFF59E0B) : theme.accentTxt.withOpacity(0.5), 
                  size: 16
                ),
                8.horizontalSpace,
                PrimaryText(
                  text: authProvider.userType, 
                  color: theme.accentTxt, 
                  fontSize: 12, 
                  fontWeight: FontWeight.bold
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    AppTheme theme = context.read();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.brandDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: PrimaryText(text: 'Log Out', color: theme.accentTxt, fontWeight: FontWeight.bold),
        content: SecondaryText(text: 'Are you sure you want to log out of MindPilot?', color: theme.accentTxt.withOpacity(0.8)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: SecondaryText(text: 'Cancel', color: theme.accentTxt.withOpacity(0.5)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AppAuthProvider>().logout();
              if (context.mounted) {
                context.pushOff(const LoginScreen());
              }
            },
            child: const PrimaryText(text: 'Log Out', color: Color(0xffEF4444), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    AppTheme theme = context.read<AppTheme>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.brandDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: PrimaryText(
          text: 'Delete Account',
          color: theme.accentTxt,
          fontWeight: FontWeight.bold,
        ),
        content: SecondaryText(
          text: 'Are you sure you want to permanently delete your MindPilot account? This action is irreversible and all your data (journals, tasks, and profile details) will be permanently erased.',
          color: theme.accentTxt.withOpacity(0.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: SecondaryText(
              text: 'Cancel',
              color: theme.accentTxt.withOpacity(0.5),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (context.mounted) {
                await context.read<AppAuthProvider>().deleteAccount(context);
              }
            },
            child: const PrimaryText(
              text: 'Delete Permanently',
              color: Color(0xffEF4444),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String title,
      {bool isLast = false, bool isSpecial = false, VoidCallback? onTap}) {

    AppTheme theme = context.watch<AppTheme>();
    final isDestructive = title == 'Log Out' || title == 'Delete Account';
    final iconColor = isDestructive ? const Color(0xffEF4444) : theme.accentTxt.withOpacity(0.8);
    final titleColor = isDestructive ? const Color(0xffEF4444) : theme.accentTxt;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GlassContainer(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          gradient: isDestructive ? null : theme.glassGradient,
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              16.horizontalSpace,
              Expanded(
                  child: PrimaryText(
                      text: title, fontSize: 15, fontWeight: FontWeight.w500, color: titleColor)),
              Icon(Icons.chevron_right, color: theme.accentTxt.withOpacity(0.3)),
            ],
          ),
        ).rippleClick(onTap),

        if (isSpecial)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xffEF4444),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 10),
            ),
          ),
      ],
    );

  }
}
