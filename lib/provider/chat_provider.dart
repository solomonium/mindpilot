import 'package:firebase_auth/firebase_auth.dart';
import 'package:mindpilot/export.dart';

class ChatProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _messages = [];
  final GeminiService _geminiService = GeminiService();
  final List<String> _availableModels = [
    'google/gemini-flash-1.5-8b:free',
    'mistralai/mistral-7b-instruct:free',
  ];

  String _selectedModel = 'google/gemini-flash-1.5-8b:free';
  int _modelIndex = 0;

  bool _isInitialized = false;

  // AI Limit tracking
  int _dailyMessageCount = 0;
  final int _freemiumLimit = 10;

  List<Map<String, dynamic>> get messages => _messages;
  GeminiService get geminiService => _geminiService;
  List<String> get availableModels => _availableModels;
  String get selectedModel => _selectedModel;
  bool get isInitialized => _isInitialized;
  int get dailyMessageCount => _dailyMessageCount;
  int get freemiumLimit => _freemiumLimit;

  void initChat() async {
    if (_isInitialized) return;
    
    final apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
    final models = await _geminiService.listModels(apiKey);
    if (models.isNotEmpty) {
      _availableModels.clear();
      _availableModels.addAll(models);
      
      if (!_availableModels.contains(_selectedModel)) {
        _selectedModel = _availableModels.first;
      }
    }





    
    _geminiService.init(apiKey, modelName: _selectedModel);
    
    if (_messages.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      final name = user?.displayName?.getFirstName();
      final greeting = name != null ? "Hello $name! I'm your MindPilot assistant. How can I help you today?" : "Hello! I'm your MindPilot assistant. How can I help you today?";
      _messages.add({
        "text": greeting,
        "isMe": false,
      });
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

  void addMessage(String text, bool isMe) {
    _messages.add({"text": text, "isMe": isMe});
    
    // Automatically alternate model for the next request
    if (isMe && _availableModels.isNotEmpty) {
      _modelIndex = (_modelIndex + 1) % _availableModels.length;
      _selectedModel = _availableModels[_modelIndex];
      final apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
      _geminiService.init(apiKey, modelName: _selectedModel);
      safePrint('AI: Alternated to model $_selectedModel');
    }

    
    notifyListeners();
  }


  void updateModel(String modelName) {
    _selectedModel = modelName;
    final apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
    _geminiService.init(apiKey, modelName: _selectedModel);
    notifyListeners();
  }


  void resetChat() {
    _messages.clear();
    _geminiService.resetChat();
    _isInitialized = false;
    initChat();
    notifyListeners();
  }
}
