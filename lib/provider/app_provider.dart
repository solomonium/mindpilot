import 'package:mindpilot/export.dart';

class AppProvider extends BaseProvider {
  ThemeType _theme = ThemeType.light;
  ThemeType get theme => _theme;

  set theme(ThemeType val) {
    _theme = val;
    notifyListeners();
    SharedPrefs.setString('THEME_VALUE', val.toString().split('.').last);
    safePrint(val);
  }

  void toggleTheme() {
    switch (_theme) {
      case ThemeType.light:
        theme = ThemeType.dark;
        break;
      case ThemeType.dark:
        theme = ThemeType.light;
        break;
      default:
        theme = ThemeType.light;
    }
  }

  // New property to represent the current app theme
  AppTheme get currentAppTheme {
    return AppTheme.fromType(_theme);
  }

  int get currentPage => _currentPage;
  int _currentPage = 0;
  set currentPage(int value) {
    _currentPage = value;
    notifyListeners();
  }

  bool _pushNotificationsEnabled = false;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;

  set pushNotificationsEnabled(bool val) {
    _pushNotificationsEnabled = val;
    SharedPrefs.setBool('PUSH_NOTIFICATIONS_ENABLED', val);
    notifyListeners();
  }

  bool _dailyReminderEnabled = true;
  bool get dailyReminderEnabled => _dailyReminderEnabled;

  set dailyReminderEnabled(bool val) {
    _dailyReminderEnabled = val;
    SharedPrefs.setBool('DAILY_REMINDER_ENABLED', val);
    notifyListeners();
    // Schedule/Cancel logic will be handled by UI or Service
    if (val) {
      NotificationService().scheduleDailyReminder();
    } else {
      NotificationService().cancelDailyReminder();
    }
  }

  int _streak = 0;
  int get streak => _streak;

  Future<void> updateStreak() async {
    final lastActiveStr = await SharedPrefs.getString('LAST_ACTIVE_DATE');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastActiveStr.isEmpty) {
      _streak = 1;
    } else {
      final lastActive = DateTime.tryParse(lastActiveStr) ?? today;
      final difference = today.difference(lastActive).inDays;

      if (difference == 1) {
        final current = await SharedPrefs.getInt('STREAK_COUNT') ?? 0;
        _streak = current + 1;
      } else if (difference > 1) {
        _streak = 1;
      } else {
        _streak = await SharedPrefs.getInt('STREAK_COUNT') ?? 1;
      }
    }

    if (lastActiveStr != today.toIso8601String()) {
      await SharedPrefs.setInt('STREAK_COUNT', _streak);
      await SharedPrefs.setString('LAST_ACTIVE_DATE', today.toIso8601String());
    }
    notifyListeners();
  }

  Future<void> init() async {
    final themeStr = await SharedPrefs.getString('THEME_VALUE');
    if (themeStr.isNotEmpty) {
      _theme = ThemeType.values.firstWhere(
        (e) => e.toString().split('.').last == themeStr,
        orElse: () => ThemeType.light,
      );
    }
    _pushNotificationsEnabled =
        await SharedPrefs.getBool('PUSH_NOTIFICATIONS_ENABLED') ?? false;
    _dailyReminderEnabled =
        await SharedPrefs.getBool('DAILY_REMINDER_ENABLED') ?? true;
    await updateStreak();
    notifyListeners();
  }
}
