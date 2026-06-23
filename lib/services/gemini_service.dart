import 'package:mindpilot/export.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  String? _apiKey;
  final List<Map<String, String>> _messages = [];
  List<String> _availableModels = [];
  List<String> _personalization = [];
  String? _userName;
  String _aiTone = 'Balanced';
  String _aiPersonality = 'Encouraging';

  bool get isInitialized => _apiKey != null && _apiKey!.isNotEmpty;

  void setPersonalization(List<String> goals) {
    _personalization = goals;
  }

  void setAiPreferences(String tone, String personality) {
    _aiTone = tone;
    _aiPersonality = personality;
  }

  void setUserName(String? name) {
    _userName = name;
  }

  void init(
    String apiKey, {
    String modelName = 'google/gemini-2.0-flash-exp:free',
  }) {
    _apiKey = apiKey;
  }

  Future<String?> sendMessage(String message) async {
    // Auto-initialize if apiKey is missing
    if (_apiKey == null || _apiKey!.isEmpty) {
      _apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception(
        "AI not initialized. Please check your OpenRouter API key.",
      );
    }

    if (_messages.isEmpty) {
      String context = "";

      if (_userName != null && _userName!.isNotEmpty) {
        context +=
            "The user's name is $_userName. Please address them as $_userName when greeting them or providing feedback. ";
      }

      context +=
          "Your response style should be **$_aiTone** and your personality should be **$_aiPersonality**. ";

      if (_personalization.isNotEmpty) {
        context +=
            "The user has selected the following focus areas: ${_personalization.join(', ')}. "
            "Please tailor your advice, tone, and recommendations to align with these goals. "
            "When relevant to these focus areas, suggest using the **Decision Analyzer** for choices and **Focus Sessions** for concentration.";
      }

      if (context.isNotEmpty) {
        _messages.add({'role': 'system', 'content': context});
      }
    }

    _messages.add({'role': 'user', 'content': message});

    // 1. Get the list of models
    List<String> modelsToTry = _availableModels.isNotEmpty
        ? List<String>.from(_availableModels)
        : [
            'google/gemini-flash-1.5-8b:free',
            'mistralai/mistral-7b-instruct:free',
            'google/gemini-2.0-flash-exp:free',
          ];

    // 2. SHUFFLE the list to "span across" all providers and avoid exhaustion
    modelsToTry.shuffle();

    // 3. Take a larger slice (top 15) to ensure wide coverage
    final finalModels = modelsToTry.take(15).toList();

    for (var i = 0; i < finalModels.length; i++) {
      final model = finalModels[i];
      try {
        final dio = Dio();
        const url = 'https://openrouter.ai/api/v1/chat/completions';

        // Add a 1-second delay between retries to prevent 429 errors
        if (i > 0) {
          await Future.delayed(const Duration(seconds: 1));
        }

        final response = await dio.post(
          url,
          options: Options(
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://mindpilot-131f1.web.app/',
              'X-Title': 'MindPilot',
            },
            validateStatus: (status) => status! < 500,
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
          data: {'model': model, 'messages': _messages},
        );

        if (response.statusCode == 200) {
          final text =
              response.data['choices'][0]['message']['content'] as String;
          _messages.add({'role': 'assistant', 'content': text});
          return text;
        } else {
          // If payment or rate limit, log but continue to try other models
          safePrint('OpenRouter Issue ($model): ${response.statusCode}');
          if (i == finalModels.length - 1) {
            throw Exception("OpenRouter Error: ${response.statusCode}");
          }
          continue;
        }
      } catch (e) {
        safePrint('AI ATTEMPT ERROR ($model): $e');
        if (i == finalModels.length - 1) rethrow;
        continue;
      }
    }
    return null;
  }

  Future<String?> sendMessageOneShot(String message, {String? systemInstruction}) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception(
        "AI not initialized. Please check your OpenRouter API key.",
      );
    }

    final List<Map<String, String>> messages = [];
    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemInstruction});
    }
    messages.add({'role': 'user', 'content': message});

    List<String> modelsToTry = _availableModels.isNotEmpty
        ? List<String>.from(_availableModels)
        : [
            'google/gemini-flash-1.5-8b:free',
            'mistralai/mistral-7b-instruct:free',
            'google/gemini-2.0-flash-exp:free',
          ];

    modelsToTry.shuffle();
    final finalModels = modelsToTry.take(15).toList();

    for (var i = 0; i < finalModels.length; i++) {
      final model = finalModels[i];
      try {
        final dio = Dio();
        const url = 'https://openrouter.ai/api/v1/chat/completions';

        if (i > 0) {
          await Future.delayed(const Duration(seconds: 1));
        }

        final response = await dio.post(
          url,
          options: Options(
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://mindpilot-131f1.web.app/',
              'X-Title': 'MindPilot',
            },
            validateStatus: (status) => status! < 500,
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
          data: {'model': model, 'messages': messages},
        );

        if (response.statusCode == 200) {
          return response.data['choices'][0]['message']['content'] as String;
        } else {
          safePrint('OpenRouter Issue ($model): ${response.statusCode}');
          if (i == finalModels.length - 1) {
            throw Exception("OpenRouter Error: ${response.statusCode}");
          }
          continue;
        }
      } catch (e) {
        safePrint('AI ATTEMPT ERROR ($model): $e');
        if (i == finalModels.length - 1) rethrow;
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
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
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
