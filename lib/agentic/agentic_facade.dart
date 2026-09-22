import 'package:flutter/widgets.dart';
import 'engine/agent_loop_executor.dart';
import 'models/agent_action.dart';
import 'models/agent_turn_result.dart';
import 'tools/agent_tool_registry.dart';

/// Clean public gateway connecting MindPilot's UI and state providers to the Agentic Engine.
class AgenticFacade {
  static final AgenticFacade _instance = AgenticFacade._internal();
  factory AgenticFacade() => _instance;
  AgenticFacade._internal();

  final AgentLoopExecutor _executor = AgentLoopExecutor();
  final AgentToolRegistry _registry = AgentToolRegistry();

  /// Executes an agentic reasoning turn with full tool awareness and multi-step ReAct loop.
  Future<AgentTurnResult> processMessage({
    required String userMessage,
    required List<Map<String, String>> conversationHistory,
    BuildContext? context,
    String? customSystemInstruction,
  }) async {
    return await _executor.executeTurn(
      userMessage: userMessage,
      conversationHistory: conversationHistory,
      context: context,
      customSystemInstruction: customSystemInstruction,
    );
  }

  /// Manually dispatches an action prepared by the agent
  Future<Map<String, dynamic>> executeAction({
    required AgentAction action,
    BuildContext? context,
  }) async {
    return await _registry.dispatch(
      toolName: action.toolName,
      arguments: action.arguments,
      context: context,
    );
  }

  /// Returns metadata of all registered tools
  List<Map<String, String>> getAvailableTools() {
    return _registry.getAllTools().map((t) {
      return {
        'name': t.name,
        'description': t.description,
        'autonomous': t.isAutonomous.toString(),
      };
    }).toList();
  }
}
