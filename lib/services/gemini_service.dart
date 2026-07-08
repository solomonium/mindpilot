import 'package:google_generative_ai/google_generative_ai.dart';
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
  bool _isPro = false;

  void setIsPro(bool isPro) {
    _isPro = isPro;
    safePrint('GeminiService: Updated isPro to $_isPro');
  }

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

  List<Content> _convertToGenerativeContent() {
    final List<Content> contents = [];
    for (final msg in _messages) {
      final role = msg['role'];
      final content = msg['content'] ?? '';
      if (role == 'user') {
        contents.add(Content.text(content));
      } else if (role == 'assistant' || role == 'model') {
        contents.add(Content.model([TextPart(content)]));
      }
    }
    return contents;
  }

  Future<String?> _sendDirectGemini({
    required List<Content> contents,
    String? systemInstruction,
  }) async {
    final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
    if (geminiApiKey == null || geminiApiKey.isEmpty) {
      safePrint('GeminiService: GEMINI_API_KEY is not configured in .env.');
      return null;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: geminiApiKey,
        systemInstruction: systemInstruction != null && systemInstruction.isNotEmpty
            ? Content.system(systemInstruction)
            : null,
      );

      final response = await model.generateContent(contents);
      final responseText = response.text;
      if (responseText != null && responseText.isNotEmpty) {
        safePrint('GeminiService: Direct Gemini API success.');
        _logUsage(
          model: 'gemini-2.5-flash',
          source: 'direct',
          promptTokens: response.usageMetadata?.promptTokenCount ?? 0,
          responseTokens: response.usageMetadata?.candidatesTokenCount ?? 0,
          totalTokens: response.usageMetadata?.totalTokenCount ?? 0,
        );
        return responseText;
      }
    } catch (e) {
      safePrint('GeminiService Direct API Error: $e');
      _logUsage(
        model: 'gemini-2.5-flash',
        source: 'direct',
        promptTokens: 0,
        responseTokens: 0,
        totalTokens: 0,
        status: 'failed',
        errorMessage: e.toString(),
      );
    }
    return null;
  }

  Future<String?> _sendOpenRouter({
    required List<String> models,
    required List<Map<String, String>> messages,
    int maxTokens = 1500,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return null;
    }

    for (var i = 0; i < models.length; i++) {
      final model = models[i];
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
          data: {
            'model': model,
            'messages': messages,
            'max_tokens': maxTokens,
          },
        );

        if (response.statusCode == 200) {
          final content = response.data['choices'][0]['message']['content'] as String;
          final usage = response.data['usage'];
          if (usage != null) {
            _logUsage(
              model: model,
              source: 'openrouter',
              promptTokens: usage['prompt_tokens'] as int? ?? 0,
              responseTokens: usage['completion_tokens'] as int? ?? 0,
              totalTokens: usage['total_tokens'] as int? ?? 0,
            );
          } else {
            _logUsage(
              model: model,
              source: 'openrouter',
              promptTokens: 0,
              responseTokens: 0,
              totalTokens: 0,
            );
          }
          return content;
        } else {
          safePrint('OpenRouter Issue ($model): ${response.statusCode}');
          continue;
        }
      } catch (e) {
        safePrint('AI ATTEMPT ERROR ($model): $e');
        continue;
      }
    }
    _logUsage(
      model: models.isNotEmpty ? models.last : 'unknown',
      source: 'openrouter',
      promptTokens: 0,
      responseTokens: 0,
      totalTokens: 0,
      status: 'failed',
      errorMessage: 'All attempted models failed.',
    );
    return null;
  }

  Future<String?> sendMessage(String message) async {
    // Auto-initialize if apiKey is missing
    if (_apiKey == null || _apiKey!.isEmpty) {
      _apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
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

    if (_isPro) {
      // 1. Try Direct Google Gemini Pro SDK
      final systemMessage = _messages.firstWhere(
        (m) => m['role'] == 'system',
        orElse: () => <String, String>{},
      );
      final systemInstruction = systemMessage.isNotEmpty ? systemMessage['content'] : null;

      final directResponse = await _sendDirectGemini(
        contents: _convertToGenerativeContent(),
        systemInstruction: systemInstruction,
      );
      if (directResponse != null) {
        _messages.add({'role': 'assistant', 'content': directResponse});
        return directResponse;
      }

      // 2. Fallback to OpenRouter Premium Models
      safePrint('GeminiService: Direct Gemini API failed or unconfigured. Trying premium models via OpenRouter.');
      final openRouterProResponse = await _sendOpenRouter(
        models: [
          'google/gemini-2.5-pro',
          'google/gemini-2.5-flash',
        ],
        messages: _messages,
      );
      if (openRouterProResponse != null) {
        _messages.add({'role': 'assistant', 'content': openRouterProResponse});
        return openRouterProResponse;
      }
    }

    // Freemium or Fallback for Pro
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception(
        "AI not initialized. Please check your OpenRouter API key.",
      );
    }

    List<String> modelsToTry = _availableModels.isNotEmpty
        ? List<String>.from(_availableModels)
        : [
            'meta-llama/llama-3.3-70b-instruct:free',
            'google/gemma-4-31b-it:free',
            'meta-llama/llama-3.2-3b-instruct:free',
          ];

    modelsToTry.shuffle();
    final finalModels = modelsToTry.take(15).toList();

    final response = await _sendOpenRouter(models: finalModels, messages: _messages);
    if (response != null) {
      _messages.add({'role': 'assistant', 'content': response});
      return response;
    }

    throw Exception("Failed to get response from AI models.");
  }

  Future<String?> sendMessageOneShot(String message, {String? systemInstruction}) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
    }

    if (_isPro) {
      // 1. Try Direct Google Gemini Pro SDK
      final directResponse = await _sendDirectGemini(
        contents: [Content.text(message)],
        systemInstruction: systemInstruction,
      );
      if (directResponse != null) {
        return directResponse;
      }

      // 2. Fallback to OpenRouter Premium Models
      safePrint('GeminiService OneShot: Direct Gemini API failed or unconfigured. Trying premium models via OpenRouter.');
      final List<Map<String, String>> messages = [];
      if (systemInstruction != null && systemInstruction.isNotEmpty) {
        messages.add({'role': 'system', 'content': systemInstruction});
      }
      messages.add({'role': 'user', 'content': message});

      final openRouterProResponse = await _sendOpenRouter(
        models: [
          'google/gemini-2.5-pro',
          'google/gemini-2.5-flash',
        ],
        messages: messages,
      );
      if (openRouterProResponse != null) {
        return openRouterProResponse;
      }
    }

    // Freemium or Fallback for Pro
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
            'meta-llama/llama-3.3-70b-instruct:free',
            'google/gemma-4-31b-it:free',
            'meta-llama/llama-3.2-3b-instruct:free',
          ];

    modelsToTry.shuffle();
    final finalModels = modelsToTry.take(15).toList();

    final response = await _sendOpenRouter(models: finalModels, messages: messages);
    if (response != null) {
      return response;
    }

    throw Exception("Failed to get response from AI models.");
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

  void _logUsage({
    required String model,
    required String source,
    required int promptTokens,
    required int responseTokens,
    required int totalTokens,
    String status = 'success',
    String? errorMessage,
  }) {
    try {
      final user = FirebaseAuth.instance.currentUser;
      FirebaseFirestore.instance.collection('api_usage').add({
        'userId': user?.uid ?? 'unknown',
        'userEmail': user?.email ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'model': model,
        'source': source,
        'promptTokens': promptTokens,
        'responseTokens': responseTokens,
        'totalTokens': totalTokens,
        'status': status,
        'errorMessage': errorMessage,
      });
    } catch (e) {
      safePrint('GeminiService Log Usage Error: $e');
    }
  }
}
