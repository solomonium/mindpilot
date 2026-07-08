import 'package:mindpilot/export.dart';

class AppPreferencesScreen extends StatefulWidget {
  final bool onlyNotifications;
  const AppPreferencesScreen({super.key, this.onlyNotifications = false});

  @override
  State<AppPreferencesScreen> createState() => _AppPreferencesScreenState();
}

class _AppPreferencesScreenState extends State<AppPreferencesScreen> {
  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    final isEnabled = await NotificationService().isNotificationsEnabled();
    if (mounted) {
      context.read<AppProvider>().pushNotificationsEnabled = isEnabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final appProvider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: R.S.appPreferences,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.accentTxt,
        ),
        leading: Icon(
          Icons.arrow_back_ios,
          color: theme.accentTxt,
        ).clickable(() => context.pop()),
      ),
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
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.onlyNotifications) ...[
                  PrimaryText(
                    text: R.S.appearance,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.accentTxt,
                  ),
                  16.verticalSpace,
                  _themeOption(
                    context,
                    R.S.lightMode,
                    ThemeType.light,
                    Icons.light_mode_outlined,
                  ),
                  _themeOption(
                    context,
                    R.S.darkMode,
                    ThemeType.dark,
                    Icons.dark_mode_outlined,
                  ),
                  _themeOption(
                    context,
                    R.S.systemDefault,
                    ThemeType.system,
                    Icons.settings_brightness_outlined,
                  ),
                  32.verticalSpace,
                ],
                PrimaryText(
                  text: R.S.notifications,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.accentTxt,
                ),
                16.verticalSpace,
                _switchTile(
                  context,
                  R.S.pushNotifications,
                  appProvider.pushNotificationsEnabled,
                  (v) async {
                    if (v) {
                      final granted = await NotificationService()
                          .requestPermissions();
                      if (!granted) {
                        _showPermissionDialog();
                      }
                      appProvider.pushNotificationsEnabled = granted;
                    } else {
                      appProvider.pushNotificationsEnabled = false;
                      context.showInAppNotification(
                        'Push notifications disabled. You will still receive silent insight updates.',
                        type: InAppNotificationType.success,
                      );
                    }
                  },
                ),
                _switchTile(
                  context,
                  R.S.taskReminder,
                  appProvider.dailyReminderEnabled,
                  (v) {
                    appProvider.dailyReminderEnabled = v;
                  },
                ),
                _switchTile(
                  context,
                  'Daily Mood Check-In',
                  appProvider.dailyMoodCheckInEnabled,
                  (v) {
                    appProvider.dailyMoodCheckInEnabled = v;
                  },
                ),
                _switchTile(
                  context,
                  'Daily Bible Quiz',
                  appProvider.dailyBibleQuizReminderEnabled,
                  (v) {
                    appProvider.dailyBibleQuizReminderEnabled = v;
                  },
                ),
                _switchTile(context, R.S.emailNotifications, false, (v) {}),
                24.verticalSpace,
                PrimaryText(
                  text: 'Daily Insight Frequency',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.accentTxt,
                ),
                8.verticalSpace,
                SecondaryText(
                  text: 'How often should we send you a mental boost?',
                  color: theme.accentTxt.withOpacity(0.5),
                  fontSize: 13,
                ),
                16.verticalSpace,
                _insightFrequencySelector(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightFrequencySelector(BuildContext context) {
    AppTheme theme = context.watch();
    final authProvider = context.watch<AppAuthProvider>();
    final intervals = [0, 3, 6, 12];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: intervals.map((hours) {
        bool isSelected = authProvider.insightIntervalHours == hours;
        return GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          gradient: isSelected ? theme.glassGradient : null,
          border: isSelected
              ? Border.all(color: theme.primaryBase, width: 2)
              : Border.all(color: theme.accentTxt.withOpacity(0.1), width: 1.5),
          child: PrimaryText(
            text: hours == 0 ? 'Off' : '$hours Hours',
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: theme.accentTxt,
          ),
        ).rippleClick(() {
          authProvider.updateInsightInterval(hours);
          context.showInAppNotification(
            hours == 0
                ? 'Daily insights disabled.'
                : 'Insight frequency updated to $hours hours.',
            type: InAppNotificationType.success,
          );
        });
      }).toList(),
    );
  }

  void _showPermissionDialog() {
    AppTheme theme = context.read();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.brandDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: PrimaryText(
          text: 'Notifications Disabled',
          color: theme.accentTxt,
        ),
        content: SecondaryText(
          text:
              'To receive alerts and sounds, please enable notifications in your device settings.',
          color: theme.accentTxt.withOpacity(0.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: SecondaryText(
              text: 'Cancel',
              color: theme.accentTxt.withOpacity(0.5),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AppSettings.openAppSettings(type: AppSettingsType.notification);
            },
            child: PrimaryText(text: 'Open Settings', color: theme.primaryBase),
          ),
        ],
      ),
    );
  }

  Widget _themeOption(
    BuildContext context,
    String title,
    ThemeType type,
    IconData icon,
  ) {
    AppTheme theme = context.watch();
    final appProvider = context.watch<AppProvider>();
    bool isSelected = appProvider.theme == type;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      gradient: isSelected ? theme.glassGradient : null,
      border: isSelected
          ? Border.all(color: theme.primaryBase, width: 2)
          : Border.all(color: theme.accentTxt.withOpacity(0.1), width: 1.5),
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected
                ? theme.primaryBase
                : theme.accentTxt.withOpacity(0.7),
            size: 24,
          ),
          16.horizontalSpace,
          Expanded(
            child: PrimaryText(
              text: title,
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: theme.accentTxt,
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

  Widget _switchTile(
    BuildContext context,
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    AppTheme theme = context.watch();
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: PrimaryText(
              text: label,
              fontSize: 15,
              color: theme.accentTxt,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: theme.primaryBase,
          ),
        ],
      ),
    );
  }
}
