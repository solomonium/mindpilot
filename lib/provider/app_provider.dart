import 'dart:async';
import 'package:mindpilot/export.dart';

class AppProvider extends BaseProvider with WidgetsBindingObserver {
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

  bool _dailyMoodCheckInEnabled = false;
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

  // App Lifecycle and Time Spent Tracking
  DateTime? _sessionStartTime;
  Timer? _timeSpentTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionStartTime = DateTime.now();
      _startTimeSpentTimer();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      accumulateTimeSpent();
      _stopTimeSpentTimer();
    }
  }

  void _startTimeSpentTimer() {
    _timeSpentTimer?.cancel();
    _timeSpentTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (_sessionStartTime != null) {
        final elapsed = DateTime.now().difference(_sessionStartTime!);
        _sessionStartTime = DateTime.now();
        if (elapsed.inSeconds > 0) {
          _updateTimeSpentInFirestore(elapsed.inSeconds);
        }
      }
    });
  }

  void _stopTimeSpentTimer() {
    _timeSpentTimer?.cancel();
    _timeSpentTimer = null;
  }

  void accumulateTimeSpent() {
    if (_sessionStartTime != null) {
      final elapsed = DateTime.now().difference(_sessionStartTime!);
      _sessionStartTime = null;
      if (elapsed.inSeconds > 0) {
        _updateTimeSpentInFirestore(elapsed.inSeconds);
      }
    }
  }

  Future<void> _updateTimeSpentInFirestore(int seconds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'totalTimeSpent': FieldValue.increment(seconds),
          'lastActive': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        safePrint('Error updating total time spent: $e');
      }
    }
  }

  @override
  void dispose() {
    accumulateTimeSpent();
    _stopTimeSpentTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        await SharedPrefs.getBool('DAILY_MOOD_CHECK_IN_ENABLED') ?? false;
    if (_dailyMoodCheckInEnabled) {
      NotificationService().scheduleDailyMoodCheckInReminder();
    } else {
      NotificationService().cancelDailyMoodCheckInReminder();
    }
    _dailyBibleQuizReminderEnabled =
        await SharedPrefs.getBool('DAILY_BIBLE_QUIZ_REMINDER_ENABLED') ?? true;
    if (_dailyBibleQuizReminderEnabled) {
      NotificationService().scheduleDailyBibleQuizReminder();
    }
    
    // Automatically schedule daily growth and weekly Friday growth praise reminders
    NotificationService().scheduleDailyGrowthPraiseReminder();
    NotificationService().scheduleWeeklyGrowthPraiseReminder();

    await syncEngagementFromCloud();
    await EngagementService().recordLastAppOpen();

    // Register lifecycle observer for time tracking
    WidgetsBinding.instance.addObserver(this);
    _sessionStartTime = DateTime.now();
    _startTimeSpentTimer();

    notifyListeners();
  }
}
