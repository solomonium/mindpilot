import 'agent_action.dart';

/// Represents the holistic result of an agent reasoning and execution turn.
class AgentTurnResult {
  /// The synthesized message produced by the agent to display to the user.
  final String responseText;

  /// Any reasoning thoughts captured during the ReAct loop.
  final List<String> thoughts;

  /// Actions triggered or proposed by the agent during this turn.
  final List<AgentAction> actions;

  /// Whether the turn executed any automated tool calls.
  final bool hasExecutedTools;

  AgentTurnResult({
    required this.responseText,
    this.thoughts = const [],
    this.actions = const [],
    this.hasExecutedTools = false,
  });
}
