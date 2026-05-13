import 'package:mindpilot/export.dart';

enum LoadingState { idle, busy, loaded, error }

class HomeProvider extends BaseProvider {
  int _navIndex = 0;
  String phoneNumber = '';
  int get navIndex => _navIndex;
  set navIndex(int val) {
    _navIndex = val;
    safePrint(val);
    notifyListeners();
  }

  // Weekly Stats
  int weeklyTasks = 0;
  int weeklyFocusMinutes = 0;
  int weeklyJournalEntries = 0;
  bool isLoadingStats = false;

  Future<void> loadWeeklyStats() async {
    isLoadingStats = true;
    notifyListeners();

    final db = DatabaseHelper();
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final dateIso = sevenDaysAgo.toIso8601String();

    weeklyTasks = await db.getTasksCompletedSince(dateIso);
    weeklyFocusMinutes = await db.getFocusMinutesSince(dateIso);
    weeklyJournalEntries = await db.getJournalCountSince(dateIso);

    isLoadingStats = false;
    notifyListeners();
  }
}
