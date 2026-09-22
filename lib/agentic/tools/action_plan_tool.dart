import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mindpilot/export.dart';
import '../models/agent_action.dart';
import 'agent_tool.dart';

/// Agent tool that creates a structured, interactive task checklist to help users overcome friction and execute.
class ActionPlanTool extends AgentTool {
  @override
  String get name => 'create_action_plan';

  @override
  String get description =>
      'Decomposes a goal, dilemma, or overwhelming task into an interactive step-by-step checklist of 2 to 5 concrete tasks.';

  @override
  bool get isAutonomous => true; // Staged directly into the chat as an interactive widget

  @override
  FunctionDeclaration toFunctionDeclaration() {
    return FunctionDeclaration(
      name,
      description,
      Schema.object(
        properties: {
          'plan_title': Schema.string(
            description: 'A punchy, motivating title for the action plan (e.g. "Quarterly Report Sprint").',
          ),
          'tasks': Schema.array(
            description: 'The list of 2 to 5 small, clear, sequential tasks.',
            items: Schema.object(
              properties: {
                'id': Schema.string(
                  description: 'Unique task id (e.g. "1", "2").',
                ),
                'title': Schema.string(
                  description: 'Actionable verb-first task description (e.g. "Outline 3 main points").',
                ),
                'estimated_minutes': Schema.integer(
                  description: 'Approximate minutes to complete (e.g. 5, 10, 15).',
                ),
              },
              requiredProperties: ['id', 'title'],
            ),
          ),
        },
        requiredProperties: ['plan_title', 'tasks'],
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> execute({
    required BuildContext? context,
    required Map<String, dynamic> arguments,
  }) async {
    final title = (arguments['plan_title'] as String?)?.trim() ?? 'Execution Plan';
    final rawTasks = arguments['tasks'] as List? ?? [];

    return {
      'status': 'success',
      'plan_title': title,
      'task_count': rawTasks.length,
      'message': 'Action plan "$title" created with ${rawTasks.length} tasks.',
    };
  }

  @override
  AgentAction createAction({
    required String id,
    required Map<String, dynamic> arguments,
    ActionStatus initialStatus = ActionStatus.completed,
  }) {
    final title = arguments['plan_title'] as String? ?? 'Action Plan';
    final rawTasks = arguments['tasks'] as List? ?? [];

    // Format tasks to ensure valid maps
    final List<Map<String, dynamic>> sanitizedTasks = [];
    for (int i = 0; i < rawTasks.length; i++) {
      final t = rawTasks[i];
      if (t is Map) {
        sanitizedTasks.add({
          'id': (t['id'] ?? '${i + 1}').toString(),
          'title': (t['title'] ?? 'Step ${i + 1}').toString(),
          'estimated_minutes': (t['estimated_minutes'] as num?)?.toInt() ?? 10,
          'is_completed': false,
        });
      }
    }

    return AgentAction(
      id: id,
      toolName: name,
      title: title,
      description: 'Interactive ${sanitizedTasks.length}-step execution checklist',
      arguments: {
        'plan_title': title,
        'tasks': sanitizedTasks,
      },
      status: initialStatus,
    );
  }
}
