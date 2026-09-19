import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mindpilot/export.dart';
import '../models/agent_action.dart';
import 'agent_tool.dart';

/// Agent tool that retrieves user metrics, streaks, goals, and recent reflections
/// to provide deep personalization and episodic memory.
class UserContextTool extends AgentTool {
  @override
  String get name => 'get_user_context';

  @override
  String get description =>
      'Fetches the user profile summary, current streak days, XP, level, active focus goals, and recent journal reflections.';

  @override
  bool get isAutonomous => true; // Read-only tool, always safe to execute automatically

  @override
  FunctionDeclaration toFunctionDeclaration() {
    return FunctionDeclaration(
      name,
      description,
      Schema.object(
        properties: {},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> execute({
    required BuildContext? context,
    required Map<String, dynamic> arguments,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.displayName ?? 'User';

      int streak = 0;
      int xp = 0;
      int level = 1;
      List<String> goals = [];

      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (doc.exists) {
            final data = doc.data() ?? {};
            streak = (data['streak'] as num?)?.toInt() ?? 0;
            xp = (data['xp'] as num?)?.toInt() ?? 0;
            level = (data['level'] as num?)?.toInt() ?? 1;
            goals = List<String>.from(data['personalization'] ?? []);
          }
        } catch (_) {}
      }

      // Fetch recent journal reflections from local SQLite
      final recentEntries = await DatabaseHelper().getEntries();
      final recentSummary = recentEntries.take(3).map((e) {
        return {
          'title': e['title'] ?? 'Entry',
          'mood': e['mood'] ?? 'Neutral',
          'date': e['date'] ?? '',
        };
      }).toList();

      final totalFocusMinutes = await DatabaseHelper().getTotalFocusMinutes();

      return {
        'status': 'success',
        'userName': userName,
        'streakDays': streak,
        'xp': xp,
        'level': level,
        'focusGoals': goals,
        'totalFocusMinutes': totalFocusMinutes,
        'recentReflections': recentSummary,
      };
    } catch (e) {
      return {
        'status': 'failed',
        'error': e.toString(),
      };
    }
  }

  @override
  AgentAction createAction({
    required String id,
    required Map<String, dynamic> arguments,
    ActionStatus initialStatus = ActionStatus.completed,
  }) {
    return AgentAction(
      id: id,
      toolName: name,
      title: 'Context Sync',
      description: 'Synchronized user profile and recent reflections',
      arguments: arguments,
      status: initialStatus,
    );
  }
}
