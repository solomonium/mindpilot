enum UserIntent {
  careerDecision,
  relationshipDecision,
  financialDecision,
  productivityProblem,
  emotionalSupport,
  habitBuilding,
  spiritualReflection,
  generalQuestion,
}

enum EmotionType {
  stressed,
  confused,
  sad,
  angry,
  anxious,
  frustrated,
  motivated,
  neutral,
}

class ChatProcessor {
  static String generateTitle(String text, UserIntent intent) {
    if (text.length < 5) return "New Decision";
    final words = text.split(' ');
    final firstThree = words.take(3).join(' ');
    
    switch (intent) {
      case UserIntent.careerDecision:
        return "Career: $firstThree...";
      case UserIntent.financialDecision:
        return "Finance: $firstThree...";
      case UserIntent.productivityProblem:
        return "Goal: $firstThree...";
      case UserIntent.emotionalSupport:
        return "Reflection: $firstThree...";
      default:
        return "Clarity: $firstThree...";
    }
  }

  static UserIntent classifyIntent(String text) {
    final input = text.toLowerCase();

    if (input.contains("job") ||
        input.contains("career") ||
        input.contains("resign") ||
        input.contains("quit")) {
      return UserIntent.careerDecision;
    }

    if (input.contains("money") ||
        input.contains("save") ||
        input.contains("invest") ||
        input.contains("debt")) {
      return UserIntent.financialDecision;
    }

    if (input.contains("lazy") ||
        input.contains("procrastinate") ||
        input.contains("productive") ||
        input.contains("focus")) {
      return UserIntent.productivityProblem;
    }

    if (input.contains("sad") ||
        input.contains("angry") ||
        input.contains("anxious") ||
        input.contains("tired")) {
      return UserIntent.emotionalSupport;
    }

    return UserIntent.generalQuestion;
  }

  static EmotionType detectEmotion(String text) {
    final input = text.toLowerCase();

    if (input.contains("stressed") || input.contains("overwhelmed")) {
      return EmotionType.stressed;
    }

    if (input.contains("confused") || input.contains("lost")) {
      return EmotionType.confused;
    }

    if (input.contains("sad") || input.contains("depressed")) {
      return EmotionType.sad;
    }

    if (input.contains("frustrated")) {
      return EmotionType.frustrated;
    }

    if (input.contains("angry") || input.contains("annoyed")) {
      return EmotionType.angry;
    }

    if (input.contains("anxious") || input.contains("worried")) {
      return EmotionType.anxious;
    }

    return EmotionType.neutral;
  }

  static String generateFramework(UserIntent intent) {
    switch (intent) {
      case UserIntent.careerDecision:
        return """
Use this decision framework:
1. Clarify the real problem.
2. Separate emotion from facts.
3. Identify short-term and long-term consequences.
4. List practical options.
5. Recommend the safest progressive next step.
6. End with one action the user can take today.
""";

      case UserIntent.financialDecision:
        return """
Use this financial clarity framework:
1. Understand the user's current financial pressure.
2. Avoid emotional or impulsive financial advice.
3. Compare risk, affordability, and long-term value.
4. Suggest a practical next step.
5. Encourage budgeting and responsible planning.
""";

      case UserIntent.productivityProblem:
        return """
Use this productivity framework:
1. Identify the user's blocker.
2. Detect whether the issue is discipline, fear, burnout, or lack of clarity.
3. Suggest a simple routine.
4. Break the solution into small actions.
5. Give the user one task to do immediately.
""";

      case UserIntent.emotionalSupport:
        return """
Use this emotional clarity framework:
1. Validate the user's feeling.
2. Help the user slow down.
3. Ask reflective questions.
4. Avoid extreme advice.
5. Suggest a calming exercise and one positive action.
""";

      default:
        return """
Use a clarity framework:
1. Understand the question.
2. Identify the user's goal.
3. Explain possible options.
4. Recommend a productive next step.
""";
    }
  }

  static String buildAIPrompt({
    required String userMessage,
    required UserIntent intent,
    required EmotionType emotion,
    required String framework,
  }) {
    return """
You are a supportive and clear-thinking AI assistant for the MindPilot app.

Your goal is to help the user with their current thought, problem, or question in a balanced and practical way.

User intent: ${intent.name}
Detected emotion: ${emotion.name}

User message:
"$userMessage"

Framework to follow:
$framework

Rules:
- Be helpful and natural. 
- You can mention **Decision Analysis** or **Focus Sessions** if they genuinely help the user's situation, but do not force them.
- Do not give medical, legal, or financial guarantees.
- Be practical, calm, and supportive.
- Use simple, clear language.
- End with a helpful suggestion or next step.

Now respond to the user.
""";
  }


  static String buildDecisionAnalysisPrompt({
    required String userMessage,
    required UserIntent intent,
    required EmotionType emotion,
    required String framework,
    required double importance,
    required String selectedFeeling,
  }) {
    return """
You are the **MindPilot Decision Analyzer**, a specialized AI module designed to provide absolute clarity.

Your goal is to make a definitive decision for the user on their situation, explain how and why they should proceed, and then perform a structured framework analysis.

User intent: ${intent.name}
Detected emotion (from text): ${emotion.name}
User selected feeling: $selectedFeeling
Decision importance (0.0 to 1.0): $importance

User message:
"$userMessage"

Framework to follow for the analysis part:
$framework

Structure your response EXACTLY as follows using Markdown:

### 🧭 **MindPilot's Verdict & Decision**
Start by directly presenting your decision/recommendation for the user on this choice. State clearly and boldly:
1. **The Decision**: What the user should do (e.g. "You should learn Python!").
2. **Why**: The core reasons why this choice is highly beneficial or necessary for the user.
3. **How**: A high-level guide on how the user should execute this decision.

---

### ⚠️ **Cognitive Bias Checklist**
Examine the user's situation and check if their thinking shows any cognitive biases (e.g., Sunk Cost Fallacy, Catastrophizing, Confirmation Bias, Loss Aversion, Black-and-White Thinking, Emotional Reasoning, Overgeneralization, etc.). If any biases are found, list them as:
- **[Bias Name]**: Explanation of how the user's input reflects this bias, and a brief tip to counter it.
If no cognitive biases are detected in their input, state "No significant cognitive biases detected."

---

### 📊 **Framework Analysis**
Now analyze the decision using the requested framework details:
- **Emotional State**: Reflect on their current feelings/emotions and importance level.
- **Key Risks & Rewards**: Detail potential drawbacks and benefits.
- **Detailed Guidance**: Proceed with the specific framework steps:
$framework
- **Next Step**: End with 1 clear, immediate next action. Suggest starting a **Focus Session** if it requires concentrated effort.

Rules:
- Be direct, structured, and extremely clear.
- Provide definitive, actionable advice that cuts through indecision.
- Keep sections clean, engaging, and well-spaced.
""";
  }

}
