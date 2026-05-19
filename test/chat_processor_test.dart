import 'package:flutter_test/flutter_test.dart';
import 'package:mindpilot/services/chat_processor.dart';

void main() {
  group('ChatProcessor Decision Analyzer Tests', () {
    test('buildDecisionAnalysisPrompt contains the Verdict and Framework headers', () {
      final prompt = ChatProcessor.buildDecisionAnalysisPrompt(
        userMessage: 'I want to learn Python',
        intent: UserIntent.generalQuestion,
        emotion: EmotionType.neutral,
        framework: '1. Test step 1.\n2. Test step 2.',
        importance: 0.8,
        selectedFeeling: 'Calm',
      );

      // Verify that the prompt includes the Verdict and Decision instruction
      expect(prompt, contains("MindPilot's Verdict & Decision"));
      expect(prompt, contains("Framework Analysis"));
      
      // Verify other key prompt parameters are embedded correctly
      expect(prompt, contains("I want to learn Python"));
      expect(prompt, contains("generalQuestion"));
      expect(prompt, contains("Calm"));
      expect(prompt, contains("0.8"));
      expect(prompt, contains("1. Test step 1."));
    });

    test('classifyIntent returns expected UserIntent categories', () {
      expect(ChatProcessor.classifyIntent('quit my job'), UserIntent.careerDecision);
      expect(ChatProcessor.classifyIntent('save money'), UserIntent.financialDecision);
      expect(ChatProcessor.classifyIntent('lazy procrastination'), UserIntent.productivityProblem);
      expect(ChatProcessor.classifyIntent('feeling sad'), UserIntent.emotionalSupport);
      expect(ChatProcessor.classifyIntent('learn python'), UserIntent.generalQuestion);
    });
  });
}
