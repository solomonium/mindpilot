import 'package:mindpilot/export.dart';
import '../agentic/agentic_facade.dart';
import '../agentic/models/agent_action.dart';
import '../agentic/models/agent_turn_result.dart';

class ChatProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _messages = [];
  final GeminiService _geminiService = GeminiService();
  final List<String> _availableModels = [
    'google/gemma-4-31b-it:free',
    'google/gemma-4-26b-a4b-it:free',
    'openai/gpt-oss-20b:free',
    'cohere/north-mini-code:free',
    'poolside/laguna-s-2.1:free',
  ];

  String _selectedModel = 'google/gemma-4-31b-it:free';
  int _modelIndex = 0;

  bool _isInitialized = false;
  bool _isAgentMode = true; // Enabled by default for autonomous tool assistance

  // AI Limit tracking
  int _dailyMessageCount = 0;
  final int _freemiumLimit = 10;

  List<Map<String, dynamic>> get messages => _messages;
  GeminiService get geminiService => _geminiService;
  List<String> get availableModels => _availableModels;
  String get selectedModel => _selectedModel;
  bool get isInitialized => _isInitialized;
  bool get isAgentMode => _isAgentMode;
  int get dailyMessageCount => _dailyMessageCount;
  int get freemiumLimit => _freemiumLimit;

  void toggleAgentMode() {
    _isAgentMode = !_isAgentMode;
    notifyListeners();
  }

  void initChat() async {
    if (_isInitialized) return;

    final apiKey = ConfigService().openRouterApiKey;
    final models = await _geminiService.listModels(apiKey);
    if (models.isNotEmpty) {
      _availableModels.clear();
      _availableModels.addAll(models);

      if (!_availableModels.contains(_selectedModel)) {
        _selectedModel = _availableModels.first;
      }
    }

    _geminiService.init(apiKey, modelName: _selectedModel);

    // Load existing chat history from SQLite!
    final savedMessages = await DatabaseHelper().getChatMessages();
    _messages.clear();
    if (savedMessages.isNotEmpty) {
      for (var msg in savedMessages) {
        _messages.add({
          'text': msg['text'],
          'isMe': msg['isMe'] == 1,
          'timestamp': msg['timestamp'],
        });
      }
    } else {
      // Add first greeting to database and memory
      final user = FirebaseAuth.instance.currentUser;
      final name = user?.displayName?.getFirstName();
      final greeting = name != null
          ? "Hello $name! I'm your MindPilot assistant. How can I help you today?"
          : "Hello! I'm your MindPilot assistant. How can I help you today?";
      final timestamp = DateTime.now().toIso8601String();

      await DatabaseHelper().insertChatMessage({
        'text': greeting,
        'isMe': 0,
        'timestamp': timestamp,
      });

      _messages.add({"text": greeting, "isMe": false, "timestamp": timestamp});
    }

    // Load daily count from prefs
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastChatDate = prefs.getString('LAST_CHAT_DATE') ?? '';

    if (lastChatDate != today) {
      _dailyMessageCount = 0;
      await prefs.setString('LAST_CHAT_DATE', today);
      await prefs.setInt('DAILY_CHAT_COUNT', 0);
    } else {
      _dailyMessageCount = prefs.getInt('DAILY_CHAT_COUNT') ?? 0;
    }

    _isInitialized = true;
    notifyListeners();
  }

  bool canSendMessage(bool isPro) {
    if (isPro) return true;
    return _dailyMessageCount < _freemiumLimit;
  }

  void incrementMessageCount() async {
    _dailyMessageCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('DAILY_CHAT_COUNT', _dailyMessageCount);
    notifyListeners();
  }

  void rewardMessageCount() async {
    if (_dailyMessageCount > 0) {
      _dailyMessageCount--;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('DAILY_CHAT_COUNT', _dailyMessageCount);
      notifyListeners();
    }
  }

  void addMessage(
    String text,
    bool isMe, {
    List<AgentAction>? actions,
    List<String>? thoughts,
  }) async {
    final timestamp = DateTime.now().toIso8601String();

    // Persist to local SQLite DB
    await DatabaseHelper().insertChatMessage({
      'text': text,
      'isMe': isMe ? 1 : 0,
      'timestamp': timestamp,
    });

    _messages.add({
      "text": text,
      "isMe": isMe,
      "timestamp": timestamp,
      "actions": actions,
      "thoughts": thoughts,
    });

    // Automatically alternate model for the next request
    if (isMe && _availableModels.isNotEmpty) {
      _modelIndex = (_modelIndex + 1) % _availableModels.length;
      _selectedModel = _availableModels[_modelIndex];
      final apiKey = ConfigService().openRouterApiKey;
      _geminiService.init(apiKey, modelName: _selectedModel);
      safePrint('AI: Alternated to model $_selectedModel');
    }

    notifyListeners();
  }

  /// Sends a message through the autonomous Agentic Engine (ReAct loop with tools)
  Future<AgentTurnResult> sendAgenticTurn({
    required String userText,
    required BuildContext context,
  }) async {
    // 1. Add user message
    addMessage(userText, true);
    incrementMessageCount();
    await EngagementService().recordAction(EngagementAction.chatMessage);

    // 2. Prepare conversation history format
    final history = _messages.map((m) {
      return {
        'role': (m['isMe'] as bool? ?? false) ? 'user' : 'assistant',
        'content': m['text'] as String? ?? '',
      };
    }).toList();

    final validContext = context.mounted ? context : null;

    // 3. Process turn via AgenticFacade
    final turnResult = await AgenticFacade().processMessage(
      userMessage: userText,
      conversationHistory: history,
      context: validContext,
    );

    // 4. Record assistant message with any attached tool actions and reasoning thoughts
    addMessage(
      turnResult.responseText,
      false,
      actions: turnResult.actions.isNotEmpty ? turnResult.actions : null,
      thoughts: turnResult.thoughts.isNotEmpty ? turnResult.thoughts : null,
    );

    return turnResult;
  }

  void updateModel(String modelName) {
    _selectedModel = modelName;
    final apiKey = ConfigService().openRouterApiKey;
    _geminiService.init(apiKey, modelName: _selectedModel);
    notifyListeners();
  }

  void resetChat() async {
    await DatabaseHelper().clearChatMessages();
    _messages.clear();
    _geminiService.resetChat();
    _isInitialized = false;
    initChat();
    notifyListeners();
  }
}
