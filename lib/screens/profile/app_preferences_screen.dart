import 'package:mindpilot/export.dart';

class AppPreferencesScreen extends StatelessWidget {
  const AppPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final appProvider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: theme.homeBg,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        title: PrimaryText(text: 'App Preferences', fontSize: 18, fontWeight: FontWeight.bold),
        leading: Icon(Icons.arrow_back_ios, color: theme.primaryText).clickable(() => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PrimaryText(text: 'Appearance', fontSize: 16, fontWeight: FontWeight.bold),
            16.verticalSpace,
            _themeOption(context, 'Light Mode', ThemeType.light, Icons.light_mode_outlined),
            _themeOption(context, 'Dark Mode', ThemeType.dark, Icons.dark_mode_outlined),
            _themeOption(context, 'System Default', ThemeType.system, Icons.settings_brightness_outlined),
            
            32.verticalSpace,
            PrimaryText(text: 'Language', fontSize: 16, fontWeight: FontWeight.bold),
            16.verticalSpace,
            _preferenceTile(context, 'App Language', 'English (US)', Icons.language),
            
            32.verticalSpace,
            PrimaryText(text: 'Notifications', fontSize: 16, fontWeight: FontWeight.bold),
            16.verticalSpace,
            _switchTile(context, 'Push Notifications', true),
            _switchTile(context, 'Email Notifications', false),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(BuildContext context, String title, ThemeType type, IconData icon) {
    AppTheme theme = context.watch();
    final appProvider = context.watch<AppProvider>();
    bool isSelected = appProvider.theme == type;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? theme.primaryBase : theme.dividerAndBorderColor.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isSelected ? theme.primaryBase : theme.secondaryTxt, size: 24),
          16.horizontalSpace,
          Expanded(
            child: PrimaryText(
              text: title, 
              fontSize: 15, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? theme.primaryBase : theme.primaryText,
            ),
          ),
          if (isSelected) 
            Icon(Icons.check_circle, color: theme.primaryBase, size: 20),
        ],
      ),
    ).clickable(() {
      appProvider.theme = type;
    });
  }

  Widget _preferenceTile(BuildContext context, String label, String value, IconData icon) {
    AppTheme theme = context.watch();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.secondaryTxt, size: 22),
          16.horizontalSpace,
          Expanded(child: PrimaryText(text: label, fontSize: 15)),
          PrimaryText(text: value, fontSize: 14, color: theme.primaryBase, fontWeight: FontWeight.w600),
          8.horizontalSpace,
          Icon(Icons.chevron_right, color: theme.secondaryTxt, size: 20),
        ],
      ),
    );
  }

  Widget _switchTile(BuildContext context, String label, bool value) {
    AppTheme theme = context.watch();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: PrimaryText(text: label, fontSize: 15)),
          Switch(
            value: value, 
            onChanged: (v) {},
            activeColor: theme.primaryBase,
          ),
        ],
      ),
    );
  }
}
