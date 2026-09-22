import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mindpilot/export.dart';
import '../models/agent_action.dart';
import 'agent_tool.dart';

/// Agent tool that enables the AI to record reflections, decisions, or insights into the user's Journal.
class JournalTool extends AgentTool {
  @override
  String get name => 'create_journal_entry';

  @override
  String get description =>
      'Creates a new journal entry to record reflections, clarity decisions, or thoughts with an optional mood tag.';

  @override
  bool get isAutonomous => true; // Can auto-execute or be offered as an action card

  @override
  FunctionDeclaration toFunctionDeclaration() {
    return FunctionDeclaration(
      name,
      description,
      Schema.object(
        properties: {
          'title': Schema.string(
            description: 'A concise, reflective title for the journal entry.',
          ),
          'content': Schema.string(
            description: 'The body or key takeaways of the reflection or decision.',
          ),
          'mood': Schema.string(
            description:
                'Optional detected mood or feeling (e.g. Calm, Stressed, Confused, Excited, Neutral).',
          ),
        },
        requiredProperties: ['content'],
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> execute({
    required BuildContext? context,
    required Map<String, dynamic> arguments,
  }) async {
    final title = (arguments['title'] as String?)?.trim() ?? 'AI Reflection';
    final content = (arguments['content'] as String?)?.trim() ?? '';
    final mood = (arguments['mood'] as String?)?.trim() ?? 'Calm 😊';

    if (content.isEmpty) {
      return {
        'status': 'failed',
        'error': 'Journal content cannot be empty.',
      };
    }

    try {
      if (context != null && context.mounted) {
        await context.read<JournalProvider>().addEntry(
              title: title,
              text: content,
              mood: mood,
            );
      } else {
        // Fallback to direct DB insert
        final now = DateTime.now();
        final date = DateFormat('MMM dd, yyyy').format(now);
        final time = DateFormat('hh:mm a').format(now);
        await DatabaseHelper().insertEntry({
          'date': date,
          'time': time,
          'text': content,
          'mood': mood,
          'title': title,
        });
      }

      return {
        'status': 'success',
        'title': title,
        'mood': mood,
        'message': 'Reflection saved to Journal successfully.',
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
    final title = arguments['title'] as String? ?? 'AI Reflection';
    final content = arguments['content'] as String? ?? '';
    final mood = arguments['mood'] as String? ?? 'Calm';

    return AgentAction(
      id: id,
      toolName: name,
      title: 'Save to Journal: $title',
      description: content.length > 90 ? '${content.substring(0, 90)}...' : content,
      arguments: {
        'title': title,
        'content': content,
        'mood': mood,
      },
      status: initialStatus,
    );
  }
}
