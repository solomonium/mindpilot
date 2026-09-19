# MindPilot Agentic Architecture

Welcome to the **MindPilot Agentic Flow** module! This folder (`lib/agentic/`) contains the complete implementation of autonomous, tool-augmented AI agents in MindPilot.

It is isolated into this directory so you can understand the exact mechanics of agentic workflows, function calling, tool execution, and interactive UI cards for learning and future expansion.

---

## 1. What Makes This "Agentic"?

In a standard LLM chatbot:
```
User Message ──> [Prompt] ──> [LLM] ──> Text Response
```
The model can only talk. It cannot check the user's real database, cannot start a focus session, and cannot save a decision to the journal.

In an **Agentic Flow** (specifically the **ReAct: Reason + Act** pattern):
```
User Message ──> [LLM + Tools]
                     │
                     ├──> Thought: "The user is procrastinating and needs deep work."
                     ├──> Action: Calls `start_focus_session(duration: 25, task: "Report")`
                     │         │
                     │         └──> Flutter executes tool / creates UI Action Card
                     │         └──> Tool outputs observation back to LLM
                     └──> Final Synthesis: "I noticed you're feeling blocked, so I configured a 25-minute timer below to help you begin."
```

The AI can **observe state**, **invoke app functions**, and **synthesize results** with human-in-the-loop oversight.

---

## 2. Directory Map

```
lib/agentic/
├── README.md                      # This comprehensive guide
├── agentic_facade.dart            # Unified gateway used by MindPilot UI & Providers
├── models/
│   ├── agent_action.dart          # Data model for tool calls, status, & arguments
│   └── agent_turn_result.dart     # Output of an agent turn (text, actions, thoughts)
├── tools/
│   ├── agent_tool.dart            # Abstract base class for creating tools
│   ├── agent_tool_registry.dart   # Registry converting tools to Gemini SDK schemas
│   ├── focus_session_tool.dart    # Tool: start or configure focus sessions
│   ├── journal_tool.dart          # Tool: save reflections & decisions to SQLite/Firestore
│   ├── user_context_tool.dart     # Tool: read streak, XP, level, and past reflections
│   └── wisdom_search_tool.dart    # Tool: search scriptures and philosophical tenets
├── engine/
│   └── agent_loop_executor.dart   # The ReAct reasoning and execution loop
└── ui/
    └── agent_action_card.dart     # Interactive widget rendered in the chat bubble
```

---

## 3. How Gemini Function Calling Works Under the Hood

### Step A: Declare the Tool Schema
In `AgentTool.toFunctionDeclaration()`, we define the parameters using Gemini's `Schema` object:
```dart
FunctionDeclaration(
  'start_focus_session',
  'Starts or schedules a focus session timer...',
  Schema.object(
    properties: {
      'duration_minutes': Schema.integer(description: 'Duration in minutes'),
      'task_title': Schema.string(description: 'Title of the task'),
    },
    optionalProperties: ['duration_minutes'],
  ),
);
```

### Step B: Pass Tools to `GenerativeModel`
In `AgentLoopExecutor`:
```dart
final model = GenerativeModel(
  model: 'gemini-2.5-flash',
  apiKey: geminiApiKey,
  tools: AgentToolRegistry().toGeminiTools(),
);
```

### Step C: Handle the ReAct Loop
When Gemini replies, instead of regular text, its response candidate may contain a `FunctionCall`:
```dart
final functionCalls = content.parts.whereType<FunctionCall>();
for (final call in functionCalls) {
  // 1. Dispatch local Dart function
  final result = await registry.dispatch(toolName: call.name, arguments: call.args);
  
  // 2. Feed the result back to the model as a FunctionResponse
  contents.add(Content('function', [FunctionResponse(call.name, result)]));
}
// 3. Model continues reasoning until it produces a final conversational response!
```

---

## 4. Autonomous vs. Supervised (Human-in-the-Loop) Tools

We classify tools into two safety categories:

| Tool Category | `isAutonomous` | Behavior | Example |
| :--- | :--- | :--- | :--- |
| **Read-Only / Context** | `true` | Executes immediately behind the scenes; the user never experiences interruption. | `get_user_context`, `search_wisdom` |
| **State-Mutating / Interactive** | `false` | Prepares an `AgentAction` and renders an interactive `AgentActionCard` in chat. The user taps **"Launch Focus Session"** to execute. | `start_focus_session` |

---

## 5. How to Add a New Tool in 3 Steps

If you want to add a new tool (e.g. `add_calendar_event` or `set_daily_goal`):

1. **Create the Tool Class** in `lib/agentic/tools/`:
   ```dart
   class CalendarTool extends AgentTool {
     @override
     String get name => 'schedule_calendar_event';
     
     @override
     FunctionDeclaration toFunctionDeclaration() => ...;
     
     @override
     Future<Map<String, dynamic>> execute(...) async {
       // Call GoogleCalendarService
     }
   }
   ```
2. **Register it** in `AgentToolRegistry._registerDefaultTools()`:
   ```dart
   registerTool(CalendarTool());
   ```
3. That's it! Gemini automatically receives the new schema and will invoke it whenever relevant.

---

## 6. How the UI Connects

MindPilot's UI communicates **only** with `AgenticFacade`:
```dart
final turnResult = await AgenticFacade().processMessage(
  userMessage: messageText,
  conversationHistory: history,
  context: context,
);

// turnResult.responseText contains the AI's explanation
// turnResult.actions contains the AgentAction cards to render in the chat list
```
