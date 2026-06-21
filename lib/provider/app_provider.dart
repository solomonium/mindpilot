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

  bool _dailyMoodCheckInEnabled = true;
  bool get dailyMoodCheckInEnabled => _dailyMoodCheckInEnabled;

  set dailyMoodCheckInEnabled(bool val) {
    _dailyMoodCheckInEnabled = val;
    SharedPrefs.setBool('DAILY_MOOD_CHECK_IN_ENABLED', val);
    notifyListeners();
    if (val) {
      NotificationService().scheduleDailyMoodCheckInReminder();
    } else {
      NotificationService().cancelDailyMoodCheckInReminder();
    }
  }

  bool _dailyBibleQuizReminderEnabled = true;
  bool get dailyBibleQuizReminderEnabled => _dailyBibleQuizReminderEnabled;

  set dailyBibleQuizReminderEnabled(bool val) {
    _dailyBibleQuizReminderEnabled = val;
    SharedPrefs.setBool('DAILY_BIBLE_QUIZ_REMINDER_ENABLED', val);
    notifyListeners();
    if (val) {
      NotificationService().scheduleDailyBibleQuizReminder();
    } else {
      NotificationService().cancelDailyBibleQuizReminder();
    }
  }

  int _streak = 0;
  int get streak => _streak;
  bool _engagedToday = false;
  bool get engagedToday => _engagedToday;

  void applyEngagementSync({required int streak}) {
    _streak = streak;
    _engagedToday = true;
    notifyListeners();
  }

  Future<void> syncEngagementFromCloud() async {
    final data = await EngagementService().loadEngagementData();
    _streak = data['streak'] as int? ?? 0;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _engagedToday = (data['lastEngagementDate'] as String? ?? '') == today;
    notifyListeners();
    await EngagementService().scheduleStreakAtRiskReminder(_streak);
  }

  Future<void> updateStreak() async {
    await syncEngagementFromCloud();
  }

  Future<void> init() async {
    await ConfigService().init();
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
    _dailyMoodCheckInEnabled =
        await SharedPrefs.getBool('DAILY_MOOD_CHECK_IN_ENABLED') ?? true;
    if (_dailyMoodCheckInEnabled) {
      NotificationService().scheduleDailyMoodCheckInReminder();
    }
    _dailyBibleQuizReminderEnabled =
        await SharedPrefs.getBool('DAILY_BIBLE_QUIZ_REMINDER_ENABLED') ?? true;
    if (_dailyBibleQuizReminderEnabled) {
      NotificationService().scheduleDailyBibleQuizReminder();
    }
    await syncEngagementFromCloud();
    await EngagementService().recordLastAppOpen();
    notifyListeners();
  }
}
