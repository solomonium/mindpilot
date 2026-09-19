import 'package:flutter/widgets.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'action_plan_tool.dart';
import 'agent_tool.dart';
import 'focus_session_tool.dart';
import 'journal_tool.dart';
import 'user_context_tool.dart';
import 'wisdom_search_tool.dart';

/// Central registry managing all executable agent tools in MindPilot.
class AgentToolRegistry {
  static final AgentToolRegistry _instance = AgentToolRegistry._internal();
  factory AgentToolRegistry() => _instance;

  final Map<String, AgentTool> _tools = {};

  AgentToolRegistry._internal() {
    _registerDefaultTools();
  }

  void _registerDefaultTools() {
    registerTool(ActionPlanTool());
    registerTool(FocusSessionTool());
    registerTool(JournalTool());
    registerTool(UserContextTool());
    registerTool(WisdomSearchTool());
  }

  void registerTool(AgentTool tool) {
    _tools[tool.name] = tool;
  }

  AgentTool? getTool(String name) => _tools[name];

  List<AgentTool> getAllTools() => _tools.values.toList();

  /// Converts all registered tools into Gemini SDK Tool instances
  List<Tool> toGeminiTools() {
    final declarations = _tools.values
        .map((tool) => tool.toFunctionDeclaration())
        .toList();

    return [Tool(functionDeclarations: declarations)];
  }

  /// Dispatches a tool execution with input validation and error safety
  Future<Map<String, dynamic>> dispatch({
    required String toolName,
    required Map<String, dynamic> arguments,
    BuildContext? context,
  }) async {
    final tool = _tools[toolName];
    if (tool == null) {
      return {
        'status': 'error',
        'error': 'Tool "$toolName" is not recognized by AgentToolRegistry.',
      };
    }

    try {
      return await tool.execute(context: context, arguments: arguments);
    } catch (e) {
      return {
        'status': 'error',
        'error': 'Tool "$toolName" execution failed: $e',
      };
    }
  }
}
