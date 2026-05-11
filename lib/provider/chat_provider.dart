import 'package:mindpilot/export.dart';

class ChatProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _messages = [];
  final GeminiService _geminiService = GeminiService();
  List<String> _availableModels = ['gemini-1.5-flash'];
  String _selectedModel = 'gemini-1.5-flash';
  bool _isInitialized = false;

  List<Map<String, dynamic>> get messages => _messages;
  GeminiService get geminiService => _geminiService;
  List<String> get availableModels => _availableModels;
  String get selectedModel => _selectedModel;
  bool get isInitialized => _isInitialized;

  void initChat() async {
    if (_isInitialized) return;
    
    final apiKey = 'AIzaSyCjYNWFh9g0XspukeBSRm86HpbyEoa4IhU';
    
    // Fetch models
    final models = await _geminiService.listModels(apiKey);
    if (models.isNotEmpty) {
      _availableModels = models;
      if (!_availableModels.contains(_selectedModel)) {
        _selectedModel = _availableModels.first;
      }
    }
    
    _geminiService.init(apiKey, modelName: _selectedModel);
    
    // Welcome message
    if (_messages.isEmpty) {
      _messages.add({
        "text": "Hello! I'm your MindPilot assistant. How can I help you today?",
        "isMe": false,
      });
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  void addMessage(String text, bool isMe) {
    _messages.add({"text": text, "isMe": isMe});
    notifyListeners();
  }

  void updateModel(String modelName) {
    _selectedModel = modelName;
    final apiKey = 'AIzaSyCjYNWFh9g0XspukeBSRm86HpbyEoa4IhU';
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
