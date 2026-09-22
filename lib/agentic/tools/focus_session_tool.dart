import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mindpilot/export.dart';
import '../models/agent_action.dart';
import 'agent_tool.dart';

/// Agent tool that enables the AI to launch or configure a focused work/reflection timer.
class FocusSessionTool extends AgentTool {
  @override
  String get name => 'start_focus_session';

  @override
  String get description =>
      'Starts or schedules a focus session timer for deep work, meditation, or clearing mental blocks.';

  @override
  bool get isAutonomous => false; // Requires user tap or visual confirmation

  @override
  FunctionDeclaration toFunctionDeclaration() {
    return FunctionDeclaration(
      name,
      description,
      Schema.object(
        properties: {
          'task_title': Schema.string(
            description: 'The title or objective of the focus session.',
          ),
          'duration_minutes': Schema.integer(
            description:
                'Duration of the focus session in minutes (e.g. 15, 25, 45). Default is 25.',
          ),
        },
        requiredProperties: ['task_title'],
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> execute({
    required BuildContext? context,
    required Map<String, dynamic> arguments,
  }) async {
    final title = (arguments['task_title'] as String?)?.trim() ?? 'Focus Session';
    final duration = (arguments['duration_minutes'] as num?)?.toInt() ?? 25;

    try {
      if (context != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FocusSessionScreen(
              initialDuration: duration,
            ),
          ),
        );
      }
      return {
        'status': 'success',
        'task_title': title,
        'duration_minutes': duration,
        'message': 'Focus session "$title" configured for $duration minutes.',
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
    ActionStatus initialStatus = ActionStatus.pendingApproval,
  }) {
    final title = arguments['task_title'] as String? ?? 'Deep Work';
    final duration = (arguments['duration_minutes'] as num?)?.toInt() ?? 25;

    return AgentAction(
      id: id,
      toolName: name,
      title: 'Start Focus Session: $title',
      description: 'Launch a $duration-minute timer to help you focus and execute.',
      arguments: {
        'task_title': title,
        'duration_minutes': duration,
      },
      status: initialStatus,
    );
  }
}
