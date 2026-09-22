import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mindpilot/export.dart';
import '../models/agent_action.dart';
import '../models/agent_turn_result.dart';
import '../tools/agent_tool_registry.dart';

/// The ReAct (Reasoning + Acting) Agent Execution Engine for MindPilot.
/// Coordinates multi-turn thought -> tool execution -> synthesis loops.
class AgentLoopExecutor {
  final AgentToolRegistry _registry = AgentToolRegistry();
  final int maxIterations = 4;

  static const String _defaultSystemInstruction = '''
You are MindPilot's Autonomous Executive Agent.
Your role is to guide the user through life decisions, productivity blockers, spiritual alignment, and emotional clarity.

You are equipped with concrete tools that directly interact with the MindPilot app:
1. `create_action_plan`: Decomposes an overwhelming goal, dilemma, or task into an interactive checklist of 2 to 5 concrete steps with time estimates.
2. `start_focus_session`: Launches a deep work or meditation timer for focused execution.
3. `create_journal_entry`: Persists reflections, verdicts, and decisions to the user's personal journal.
4. `get_user_context`: Fetches the user's current streak, XP, level, and recent reflections for personalized context.
5. `search_wisdom`: Queries biblical scriptures and philosophical tenets for dilemmas.

Autonomous Agent Multi-Tool Chaining Rules:
- When a user is procrastinating, feeling stuck, or facing an ambitious project: DO NOT just write paragraphs of advice. Chain tools proactively!
  1. If appropriate, retrieve spiritual or philosophical grounding via `search_wisdom` or inspect past context via `get_user_context`.
  2. Always generate an actionable, bite-sized checklist using `create_action_plan`.
  3. Stage a deep work timer using `start_focus_session` to help them start the very first step immediately.
- When a user reaches clarity on a dilemma or emotional breakthrough, record it via `create_journal_entry`.
- You may invoke multiple tools across iterations to provide a complete, holistic execution package.
- Always conclude with a practical, empathetic next step in your response text.
''';

  /// Runs the agentic loop on a user message and returns the final synthesized response with any generated actions.
  Future<AgentTurnResult> executeTurn({
    required String userMessage,
    required List<Map<String, String>> conversationHistory,
    BuildContext? context,
    String? customSystemInstruction,
  }) async {
    final geminiApiKey = ConfigService().geminiApiKey;
    if (geminiApiKey.isEmpty) {
      safePrint('AgentLoopExecutor: GEMINI_API_KEY is not configured. Falling back to standard chat.');
      return _runFallback(userMessage);
    }

    final systemInstruction = customSystemInstruction ?? _defaultSystemInstruction;
    final tools = _registry.toGeminiTools();

    // Prepare contents
    final List<Content> contents = [];

    // Add recent history (up to last 6 messages to stay concise)
    final recentHistory = conversationHistory.length > 6
        ? conversationHistory.sublist(conversationHistory.length - 6)
        : conversationHistory;

    for (final msg in recentHistory) {
      final role = msg['role'];
      final text = msg['content'] ?? '';
      if (text.isEmpty) continue;

      if (role == 'user') {
        contents.add(Content.text(text));
      } else if (role == 'assistant' || role == 'model') {
        contents.add(Content.model([TextPart(text)]));
      }
    }

    // Add current user prompt
    contents.add(Content.text(userMessage));

    final List<AgentAction> recordedActions = [];
    final List<String> thoughts = [];
    String finalResponseText = '';
    bool hasExecutedTools = false;

    try {
      final modelName = ConfigService().directGeminiModel.isNotEmpty
          ? ConfigService().directGeminiModel
          : (dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.5-flash');
      final model = GenerativeModel(
        model: modelName,
        apiKey: geminiApiKey,
        systemInstruction: Content.system(systemInstruction),
        tools: tools,
      );

      int iteration = 0;
      while (iteration < maxIterations) {
        iteration++;
        safePrint('AgentLoopExecutor: Iteration $iteration executing...');

        final response = await model.generateContent(contents);
        final candidate = response.candidates.firstOrNull;

        if (candidate == null) {
          safePrint('AgentLoopExecutor: No candidate returned by model.');
          break;
        }

        final content = candidate.content;
        contents.add(content);

        // Check for function calls
        final functionCalls = content.parts.whereType<FunctionCall>().toList();
        final textParts = content.parts.whereType<TextPart>().toList();

        if (textParts.isNotEmpty) {
          finalResponseText = textParts.map((p) => p.text).join('\n');
        }

        if (functionCalls.isEmpty) {
          safePrint('AgentLoopExecutor: No further tool calls. Reasoning complete.');
          break;
        }

        hasExecutedTools = true;
        final List<Part> functionResponses = [];

        for (final call in functionCalls) {
          final toolName = call.name;
          final arguments = Map<String, dynamic>.from(call.args);
          final tool = _registry.getTool(toolName);

          safePrint('AgentLoopExecutor: Model invoked tool "$toolName" with args: $arguments');

          String thoughtMessage;
          switch (toolName) {
            case 'create_action_plan':
              final title = arguments['plan_title'] ?? 'Action Plan';
              thoughtMessage = 'Deconstructed goal into execution plan: "$title"';
              break;
            case 'start_focus_session':
              final minutes = arguments['duration_minutes'] ?? 25;
              final task = arguments['task_title'] ?? 'Deep Work';
              thoughtMessage = 'Configured $minutes-min focus session timer for "$task"';
              break;
            case 'search_wisdom':
              final topic = arguments['topic'] ?? 'Wisdom';
              thoughtMessage = 'Retrieved grounding wisdom principles for "$topic"';
              break;
            case 'get_user_context':
              thoughtMessage = 'Inspected user profile, active streak, and recent reflections';
              break;
            case 'create_journal_entry':
              final title = arguments['title'] ?? 'Reflection';
              thoughtMessage = 'Persisted clarity breakthrough to journal: "$title"';
              break;
            default:
              thoughtMessage = 'Invoked agent tool: $toolName';
          }
          thoughts.add(thoughtMessage);

          final actionId = '${DateTime.now().millisecondsSinceEpoch}_$toolName';
          final action = tool?.createAction(
                id: actionId,
                arguments: arguments,
                initialStatus: tool.isAutonomous
                    ? ActionStatus.executing
                    : ActionStatus.pendingApproval,
              ) ??
              AgentAction(
                id: actionId,
                toolName: toolName,
                title: toolName,
                description: 'Automated agent action',
                arguments: arguments,
              );

          Map<String, dynamic> executionResult;
          if (tool != null && tool.isAutonomous) {
            // Autonomous tool execution (context retrieval, wisdom, auto-journaling)
            final validContext = (context != null && context.mounted) ? context : null;
            executionResult = await _registry.dispatch(
              toolName: toolName,
              arguments: arguments,
              context: validContext,
            );
            action.status = ActionStatus.completed;
            action.result = executionResult;
          } else {
            // For user-confirming tools (e.g. focus session timer), mark as ready for user action
            executionResult = {
              'status': 'action_prepared',
              'message': 'Action card rendered for user approval.',
            };
            action.status = ActionStatus.pendingApproval;
          }

          recordedActions.add(action);

          functionResponses.add(
            FunctionResponse(toolName, executionResult),
          );
        }

        // Feed function response back to model to continue reasoning
        contents.add(Content('function', functionResponses));
      }

      if (finalResponseText.isEmpty) {
        finalResponseText = "I've analyzed your situation and prepared the next action for you.";
      }

      return AgentTurnResult(
        responseText: finalResponseText,
        thoughts: thoughts,
        actions: recordedActions,
        hasExecutedTools: hasExecutedTools,
      );
    } catch (e) {
      safePrint('AgentLoopExecutor Error: $e');
      return _runFallback(userMessage, errorNotice: e.toString());
    }
  }

  Future<AgentTurnResult> _runFallback(String userMessage, {String? errorNotice}) async {
    try {
      final geminiService = GeminiService();
      final fallbackResponse = await geminiService.sendMessage(
        userMessage,
        feature: 'chat_agent_fallback',
      );

      return AgentTurnResult(
        responseText: fallbackResponse ?? "I'm here to help. What would you like to focus on?",
        thoughts: errorNotice != null ? ['Fallback engaged: $errorNotice'] : [],
        actions: [],
      );
    } catch (e) {
      return AgentTurnResult(
        responseText: "I'm having trouble connecting right now. Please try again in a moment.",
        thoughts: ['Critical error: $e'],
        actions: [],
      );
    }
  }
}
