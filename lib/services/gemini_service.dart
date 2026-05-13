import 'package:mindpilot/export.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  String? _apiKey;
  String _selectedModel = 'google/gemini-2.0-flash-exp:free';
  final List<Map<String, String>> _messages = [];
  List<String> _availableModels = [];

  bool get isInitialized => _apiKey != null && _apiKey!.isNotEmpty;



  void init(String apiKey, {String modelName = 'google/gemini-2.0-flash-exp:free'}) {
    _apiKey = apiKey;
    _selectedModel = modelName;
    // We don't reset messages here to allow session continuity
  }

  Future<String?> sendMessage(String message) async {
    // Auto-initialize if apiKey is missing
    if (_apiKey == null || _apiKey!.isEmpty) {
      _apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception("AI not initialized. Please check your OpenRouter API key.");
    }

    _messages.add({'role': 'user', 'content': message});

    final modelsToTry = _availableModels.isNotEmpty ? _availableModels : [
      _selectedModel,
      'mistralai/mistral-7b-instruct:free',
      'google/gemini-flash-1.5-8b:free',
    ];

    for (var model in modelsToTry) {
      try {
        final dio = Dio();
        const url = 'https://openrouter.ai/api/v1/chat/completions';
        
        final response = await dio.post(
          url,
          options: Options(
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            validateStatus: (status) => status! < 500,
          ),
          data: {
            'model': model,
            'messages': _messages,
          },
        );


        if (response.statusCode == 200) {
          final text = response.data['choices'][0]['message']['content'] as String;
          _messages.add({'role': 'assistant', 'content': text});
          _selectedModel = model; // Update selected model to the one that worked
          return text;
        } else {
          // If it's a 404, we continue to the next model
          if (response.statusCode == 404) continue;
          throw Exception("OpenRouter Error: ${response.statusCode}");
        }
      } catch (e) {
        safePrint('AI ATTEMPT ERROR ($model): $e');
        if (model == modelsToTry.last) rethrow;
        continue;
      }
    }
    return null;
  }



  Future<List<String>> listModels(String apiKey) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://openrouter.ai/api/v1/models',
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
        }),
      );

      if (response.statusCode == 200) {
        final List data = response.data['data'];
        // Filter for free models and those likely to be free/low-cost
        final models = data
            .map((m) => m['id'].toString())
            .where((id) => id.contains(':free') || id.contains('flash'))
            .toList();
        
        if (models.isNotEmpty) {
          _availableModels = models;
          return models;
        }
      }
    } catch (e) {
      safePrint('List Models Error: $e');
    }

    // Ultimate fallback if API fails
    return [
      'mistralai/mistral-7b-instruct:free',
      'google/gemini-flash-1.5-8b:free',
    ];
  }




  void resetChat() {
    _messages.clear();
  }
}

