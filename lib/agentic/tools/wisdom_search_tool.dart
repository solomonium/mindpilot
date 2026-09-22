import 'package:flutter/widgets.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/agent_action.dart';
import 'agent_tool.dart';

/// Agent tool that retrieves targeted scriptures, philosophical proverbs, or mental clarity models.
class WisdomSearchTool extends AgentTool {
  @override
  String get name => 'search_wisdom';

  @override
  String get description =>
      'Retrieves relevant biblical verses, philosophical principles, or clarity frameworks based on a topic (e.g. anxiety, decision, focus, career).';

  @override
  bool get isAutonomous => true; // Read-only tool, safe for autonomous execution

  static final Map<String, List<Map<String, String>>> _wisdomBank = {
    'anxiety': [
      {
        'source': 'Philippians 4:6-7',
        'text': 'Do not be anxious about anything, but in every situation, by prayer and petition, present your requests to God.',
      },
      {
        'source': 'Marcus Aurelius',
        'text': 'Never let the future disturb you. You will meet it, if you have to, with the same weapons of reason which today arm you against the present.',
      },
    ],
    'decision': [
      {
        'source': 'Proverbs 3:5-6',
        'text': 'Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.',
      },
      {
        'source': 'First Principles Thinking',
        'text': 'Boil a dilemma down to its most fundamental truths and reason up from there instead of reasoning by analogy.',
      },
    ],
    'focus': [
      {
        'source': 'Colossians 3:2',
        'text': 'Set your minds on things above, not on earthly things.',
      },
      {
        'source': 'Seneca',
        'text': 'To be everywhere is to be nowhere. People who spend their whole life traveling end up having plenty of places where they can find hospitality, but no real friendships.',
      },
    ],
    'discipline': [
      {
        'source': 'Proverbs 25:28',
        'text': 'Like a city whose walls are broken through is a person who lacks self-control.',
      },
      {
        'source': 'Lao Tzu',
        'text': 'A journey of a thousand miles begins with a single step.',
      },
    ],
  };

  @override
  FunctionDeclaration toFunctionDeclaration() {
    return FunctionDeclaration(
      name,
      description,
      Schema.object(
        properties: {
          'topic': Schema.string(
            description: 'Topic or dilemma keyword (e.g. anxiety, decision, focus, discipline).',
          ),
        },
        requiredProperties: ['topic'],
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> execute({
    required BuildContext? context,
    required Map<String, dynamic> arguments,
  }) async {
    final topic = (arguments['topic'] as String?)?.toLowerCase().trim() ?? 'decision';

    List<Map<String, String>> matches = [];
    for (final key in _wisdomBank.keys) {
      if (topic.contains(key) || key.contains(topic)) {
        matches.addAll(_wisdomBank[key]!);
      }
    }

    if (matches.isEmpty) {
      matches = _wisdomBank['decision']!;
    }

    return {
      'status': 'success',
      'topic': topic,
      'results': matches,
    };
  }

  @override
  AgentAction createAction({
    required String id,
    required Map<String, dynamic> arguments,
    ActionStatus initialStatus = ActionStatus.completed,
  }) {
    final topic = arguments['topic'] as String? ?? 'Wisdom';
    return AgentAction(
      id: id,
      toolName: name,
      title: 'Consulted Wisdom Bank ($topic)',
      description: 'Retrieved foundational scriptures and principles for $topic.',
      arguments: arguments,
      status: initialStatus,
    );
  }
}
