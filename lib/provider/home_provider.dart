import 'package:mindpilot/export.dart';

enum LoadingState { idle, busy, loaded, error }

class HomeProvider extends BaseProvider {
  int _navIndex = 0;
  String phoneNumber = '';
  int get navIndex => _navIndex;
  set navIndex(int val) {
    _navIndex = val;
    notifyListeners();
    
    // Log screen view to Analytics
    final screenNames = ['Home', 'Focus', 'Decision', 'Journal', 'Profile'];
    if (val >= 0 && val < screenNames.length) {
      final screenName = screenNames[val];
      AnalyticsService.logScreenView(screenName);
      // Record last visited screen in Firestore for admin tracking
      EngagementService().recordScreenVisit(screenName);
    }
  }

  // Weekly Stats
  int weeklyTasks = 0;
  int weeklyFocusMinutes = 0;
  int weeklyJournalEntries = 0;
  int weeklyQuizzes = 0;
  int weeklyQuizXp = 0;
  double bibleKnowledgeScore = 0.0;
  double bibleGrowthScore = 0.0;
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

    try {
      final quizzes = await db.getQuizResultsSince(dateIso);
      weeklyQuizzes = quizzes.length;
      if (quizzes.isNotEmpty) {
        int totalScore = 0;
        int totalQuestions = 0;
        int totalXp = 0;
        for (final q in quizzes) {
          totalScore += (q['score'] as int? ?? 0);
          totalQuestions += (q['total_questions'] as int? ?? 0);
          totalXp += (q['xp_earned'] as int? ?? 0);
        }
        bibleKnowledgeScore = totalQuestions > 0 ? (totalScore / totalQuestions) * 100 : 0.0;
        bibleGrowthScore = (weeklyQuizzes * 20.0).clamp(0.0, 100.0);
        weeklyQuizXp = totalXp;
      } else {
        bibleKnowledgeScore = 0.0;
        bibleGrowthScore = 0.0;
        weeklyQuizXp = 0;
      }
    } catch (_) {
      weeklyQuizzes = 0;
      weeklyQuizXp = 0;
      bibleKnowledgeScore = 0.0;
      bibleGrowthScore = 0.0;
    }

    isLoadingStats = false;
    notifyListeners();
  }
}
