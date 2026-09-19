import 'package:flutter_test/flutter_test.dart';
import 'package:mindpilot/agentic/models/agent_action.dart';
import 'package:mindpilot/agentic/models/agent_turn_result.dart';
import 'package:mindpilot/agentic/tools/action_plan_tool.dart';
import 'package:mindpilot/agentic/tools/agent_tool_registry.dart';
import 'package:mindpilot/agentic/tools/focus_session_tool.dart';
import 'package:mindpilot/agentic/tools/journal_tool.dart';
import 'package:mindpilot/agentic/tools/user_context_tool.dart';
import 'package:mindpilot/agentic/tools/wisdom_search_tool.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgentAction & Models Tests', () {
    test('AgentAction serialization and deserialization', () {
      final action = AgentAction(
        id: 'test_123',
        toolName: 'start_focus_session',
        title: 'Deep Work Session',
        description: 'Focus for 25 minutes on Coding',
        arguments: {'duration_minutes': 25, 'task_title': 'Coding'},
        status: ActionStatus.pendingApproval,
      );

      final json = action.toJson();
      expect(json['id'], 'test_123');
      expect(json['toolName'], 'start_focus_session');
      expect(json['status'], 'pendingApproval');
      expect(json['arguments']['duration_minutes'], 25);

      final revived = AgentAction.fromJson(json);
      expect(revived.id, action.id);
      expect(revived.toolName, action.toolName);
      expect(revived.status, ActionStatus.pendingApproval);
      expect(revived.arguments['task_title'], 'Coding');
    });

    test('AgentTurnResult container properties', () {
      final action = AgentAction(
        id: 'act_1',
        toolName: 'create_journal_entry',
        title: 'Save Note',
        description: 'Saved reflection',
        arguments: {'title': 'Note', 'content': 'Peaceful'},
        status: ActionStatus.completed,
      );

      final turnResult = AgentTurnResult(
        responseText: 'I recorded your insight.',
        thoughts: ['User feels calm', 'Invoking journal tool'],
        actions: [action],
        hasExecutedTools: true,
      );

      expect(turnResult.responseText, 'I recorded your insight.');
      expect(turnResult.hasExecutedTools, true);
      expect(turnResult.actions.length, 1);
      expect(turnResult.thoughts.length, 2);
    });
  });

  group('AgentToolRegistry Tests', () {
    test('Registry initializes with all default tools', () {
      final registry = AgentToolRegistry();
      final tools = registry.getAllTools();

      expect(tools.length, greaterThanOrEqualTo(5));
      expect(registry.getTool('create_action_plan'), isA<ActionPlanTool>());
      expect(registry.getTool('start_focus_session'), isA<FocusSessionTool>());
      expect(registry.getTool('create_journal_entry'), isA<JournalTool>());
      expect(registry.getTool('get_user_context'), isA<UserContextTool>());
      expect(registry.getTool('search_wisdom'), isA<WisdomSearchTool>());
    });

    test('Converts registered tools into Gemini SDK declarations', () {
      final registry = AgentToolRegistry();
      final geminiTools = registry.toGeminiTools();

      expect(geminiTools.isNotEmpty, true);
      final declarations = geminiTools.first.functionDeclarations;
      expect(declarations, isNotNull);
      expect(declarations!.length, greaterThanOrEqualTo(5));

      final names = declarations.map((d) => d.name).toList();
      expect(names, contains('create_action_plan'));
      expect(names, contains('start_focus_session'));
      expect(names, contains('create_journal_entry'));
      expect(names, contains('get_user_context'));
      expect(names, contains('search_wisdom'));
    });

    test('WisdomSearchTool execution test', () async {
      final tool = WisdomSearchTool();
      final result = await tool.execute(
        context: null,
        arguments: {'topic': 'anxiety'},
      );

      expect(result['status'], 'success');
      expect(result['results'], isNotNull);
      final list = result['results'] as List;
      expect(list.isNotEmpty, true);
    });

    test('ActionPlanTool execution and action creation test', () async {
      final tool = ActionPlanTool();
      final result = await tool.execute(
        context: null,
        arguments: {
          'plan_title': 'Launch Project Sprint',
          'tasks': [
            {'id': '1', 'title': 'Draft outline', 'estimated_minutes': 10},
            {'id': '2', 'title': 'Write core copy', 'estimated_minutes': 20},
          ],
        },
      );

      expect(result['status'], 'success');
      expect(result['plan_title'], 'Launch Project Sprint');
      expect(result['task_count'], 2);

      final action = tool.createAction(
        id: 'plan_1',
        arguments: {
          'plan_title': 'Launch Project Sprint',
          'tasks': [
            {'id': '1', 'title': 'Draft outline', 'estimated_minutes': 10},
            {'id': '2', 'title': 'Write core copy', 'estimated_minutes': 20},
          ],
        },
      );

      expect(action.toolName, 'create_action_plan');
      final tasks = action.arguments['tasks'] as List;
      expect(tasks.length, 2);
      expect(tasks[0]['is_completed'], false);
    });
  });
}
