import 'package:flutter/widgets.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/agent_action.dart';

/// Abstract base contract for any tool that the MindPilot AI Agent can invoke.
abstract class AgentTool {
  /// Unique tool identifier (e.g., 'start_focus_session')
  String get name;

  /// High-level description of what this tool accomplishes, read by the LLM
  String get description;

  /// Generates the Gemini SDK FunctionDeclaration
  FunctionDeclaration toFunctionDeclaration();

  /// Whether this tool automatically executes behind the scenes without waiting for user confirmation
  bool get isAutonomous;

  /// Executes the tool logic in the app context
  Future<Map<String, dynamic>> execute({
    required BuildContext? context,
    required Map<String, dynamic> arguments,
  });

  /// Converts a tool invocation into a human-readable AgentAction card model
  AgentAction createAction({
    required String id,
    required Map<String, dynamic> arguments,
    ActionStatus initialStatus = ActionStatus.pendingApproval,
  });
}
