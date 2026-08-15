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

  String _selectedLlmProvider = 'Direct Gemini';

  void setIsPro(bool isPro) {
    _isPro = isPro;
    safePrint('GeminiService: Updated isPro to $_isPro');
  }

  void setLlmProvider(String provider) {
    _selectedLlmProvider = provider;
    safePrint('GeminiService: Updated LLM provider to $_selectedLlmProvider');
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
    String modelName = 'google/gemma-4-31b-it:free',
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

  String _sanitizeDirectGeminiModel(String rawModelName) {
    String name = rawModelName.trim();
    name = name.replaceAll(RegExp(r'^google/'), '');
    name = name.replaceAll(RegExp(r':free$'), '');
    return name.isEmpty ? 'gemini-2.0-flash' : name;
  }

  String _sanitizeOpenRouterModel(String rawModel) {
    String model = rawModel.trim();
    if (model.isEmpty) return 'google/gemma-4-31b-it:free';
    if (model.startsWith('gemini-') && !model.startsWith('google/')) {
      model = 'google/$model';
    }
    return model;
  }

  Future<String?> _sendDirectGemini({
    required List<Content> contents,
    String? systemInstruction,
    required String feature,
    int maxTokens = 1000,
    String? overrideModel,
  }) async {
    final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
    if (geminiApiKey == null || geminiApiKey.isEmpty) {
      safePrint('GeminiService: GEMINI_API_KEY is not configured in .env.');
      return null;
    }

    final String rawModelName = overrideModel ??
        (ConfigService().directGeminiModel.isNotEmpty
            ? ConfigService().directGeminiModel
            : 'gemini-2.0-flash');
    final String directModelName = _sanitizeDirectGeminiModel(rawModelName);

    try {
      final model = GenerativeModel(
        model: directModelName,
        apiKey: geminiApiKey,
        systemInstruction: systemInstruction != null && systemInstruction.isNotEmpty
            ? Content.system(systemInstruction)
            : null,
      );

      final response = await model.generateContent(
        contents,
        generationConfig: GenerationConfig(maxOutputTokens: maxTokens),
      );
      final responseText = response.text;
      if (responseText != null && responseText.isNotEmpty) {
        safePrint('GeminiService: Direct Gemini API success ($directModelName).');
        _logUsage(
          model: directModelName,
          feature: feature,
          source: 'direct',
          promptTokens: response.usageMetadata?.promptTokenCount ?? 0,
          responseTokens: response.usageMetadata?.candidatesTokenCount ?? 0,
          totalTokens: response.usageMetadata?.totalTokenCount ?? 0,
        );
        return responseText;
      }
    } catch (e) {
      safePrint('GeminiService Direct API Error ($directModelName): $e');
      
      final fallbackChain = ['gemini-2.5-flash', 'gemini-3.5-flash', 'gemini-flash-latest'];
      int currentIdx = fallbackChain.indexOf(directModelName);
      
      if (currentIdx >= 0 && currentIdx < fallbackChain.length - 1) {
        final nextModel = fallbackChain[currentIdx + 1];
        safePrint('GeminiService: Retrying Direct Gemini API with fallback model ($nextModel)...');
        return _sendDirectGemini(
          contents: contents,
          systemInstruction: systemInstruction,
          feature: feature,
          maxTokens: maxTokens,
          overrideModel: nextModel,
        );
      } else if (currentIdx < 0) {
        // If the failed model was not in the fallback chain, start the fallback chain
        final nextModel = fallbackChain.first;
        safePrint('GeminiService: Retrying Direct Gemini API with fallback model ($nextModel)...');
        return _sendDirectGemini(
          contents: contents,
          systemInstruction: systemInstruction,
          feature: feature,
          maxTokens: maxTokens,
          overrideModel: nextModel,
        );
      }

      _logUsage(
        model: directModelName,
        feature: feature,
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
    required String feature,
    int maxTokens = 1500,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
    }
    if (_apiKey == null || _apiKey!.isEmpty) {
      return null;
    }

    final cleanKey = _apiKey!.trim();
    String? lastError;

    for (var i = 0; i < models.length; i++) {
      final model = _sanitizeOpenRouterModel(models[i]);
      try {
        final dio = Dio();
        const url = 'https://openrouter.ai/api/v1/chat/completions';

        if (i > 0) {
          await Future.delayed(const Duration(milliseconds: 500));
        }

        final response = await dio.post(
          url,
          options: Options(
            headers: {
              'Authorization': 'Bearer $cleanKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://mindpilot-131f1.web.app/',
              'X-Title': 'MindPilot',
            },
            validateStatus: (status) => status != null && status < 500,
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
          data: {
            'model': model,
            'messages': messages,
            'max_tokens': maxTokens,
          },
        );

        if (response.statusCode == 200 && response.data != null && response.data['choices'] != null && (response.data['choices'] as List).isNotEmpty) {
          final content = response.data['choices'][0]['message']['content'] as String;
          final usage = response.data['usage'];
          if (usage != null) {
            _logUsage(
              model: model,
              feature: feature,
              source: 'openrouter',
              promptTokens: usage['prompt_tokens'] as int? ?? 0,
              responseTokens: usage['completion_tokens'] as int? ?? 0,
              totalTokens: usage['total_tokens'] as int? ?? 0,
            );
          } else {
            _logUsage(
              model: model,
              feature: feature,
              source: 'openrouter',
              promptTokens: 0,
              responseTokens: 0,
              totalTokens: 0,
            );
          }
          return content;
        } else {
          final errorMsg = response.data != null && response.data['error'] != null
              ? (response.data['error']['message'] ?? response.data['error'].toString())
              : 'HTTP ${response.statusCode}';
          safePrint('OpenRouter Issue ($model): $errorMsg (status: ${response.statusCode})');
          lastError = '$model: $errorMsg (HTTP ${response.statusCode})';
          
          if (response.statusCode == 401 || response.statusCode == 402) {
            safePrint('OpenRouter Authentication/Credit Error. Aborting further model retries.');
            break;
          }
          continue;
        }
      } catch (e) {
        safePrint('AI ATTEMPT ERROR ($model): $e');
        lastError = '$model error: $e';
        continue;
      }
    }
    _logUsage(
      model: models.isNotEmpty ? models.last : 'unknown',
      feature: feature,
      source: 'openrouter',
      promptTokens: 0,
      responseTokens: 0,
      totalTokens: 0,
      status: 'failed',
      errorMessage: lastError ?? 'All attempted models failed.',
    );
    return null;
  }

  Future<String?> _sendAgentRouter({
    required List<String> models,
    required List<Map<String, String>> messages,
    required String feature,
    int maxTokens = 1500,
  }) async {
    final agentRouterApiKey = dotenv.env['AGENT_ROUTER_API_KEY'] ?? '';
    if (agentRouterApiKey.isEmpty) {
      safePrint('GeminiService: AGENT_ROUTER_API_KEY is not configured in .env.');
      return null;
    }

    final cleanKey = agentRouterApiKey.trim();
    String? lastError;

    for (var i = 0; i < models.length; i++) {
      final model = models[i];
      try {
        final dio = Dio();
        const url = 'https://agentrouter.org/v1/chat/completions';

        if (i > 0) {
          await Future.delayed(const Duration(milliseconds: 500));
        }

        final response = await dio.post(
          url,
          options: Options(
            headers: {
              'Authorization': 'Bearer $cleanKey',
              'Content-Type': 'application/json',
            },
            validateStatus: (status) => status != null && status < 500,
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
          data: {
            'model': model,
            'messages': messages,
            'max_tokens': maxTokens,
          },
        );

        if (response.statusCode == 200 && response.data != null && response.data['choices'] != null && (response.data['choices'] as List).isNotEmpty) {
          final content = response.data['choices'][0]['message']['content'] as String;
          final usage = response.data['usage'];
          _logUsage(
            model: model,
            feature: feature,
            source: 'agentrouter',
            promptTokens: usage != null ? (usage['prompt_tokens'] as int? ?? 0) : 0,
            responseTokens: usage != null ? (usage['completion_tokens'] as int? ?? 0) : 0,
            totalTokens: usage != null ? (usage['total_tokens'] as int? ?? 0) : 0,
          );
          return content;
        } else {
          final errorMsg = response.data != null && response.data['error'] != null
              ? (response.data['error']['message'] ?? response.data['error'].toString())
              : 'HTTP ${response.statusCode}';
          safePrint('AgentRouter Issue ($model): $errorMsg (status: ${response.statusCode})');
          lastError = '$model: $errorMsg (HTTP ${response.statusCode})';
          continue;
        }
      } catch (e) {
        safePrint('AgentRouter ATTEMPT ERROR ($model): $e');
        lastError = '$model error: $e';
        continue;
      }
    }

    _logUsage(
      model: models.isNotEmpty ? models.last : 'unknown',
      feature: feature,
      source: 'agentrouter',
      promptTokens: 0,
      responseTokens: 0,
      totalTokens: 0,
      status: 'failed',
      errorMessage: lastError ?? 'All attempted models failed.',
    );
    return null;
  }

  Future<void> _summarizeOlderMessages() async {
    if (_messages.length <= 10) return;

    bool hasPreviousSummary = _messages.length > 1 &&
        _messages[1]['role'] == 'system' &&
        _messages[1]['content'] != null &&
        _messages[1]['content']!.startsWith('Summary of previous conversation:');

    int startIdx = hasPreviousSummary ? 2 : 1;
    int endIdx = _messages.length - 6;

    if (endIdx <= startIdx) return;

    final messagesToSummarize = _messages.sublist(startIdx, endIdx);
    
    final conversationText = messagesToSummarize.map((m) {
      final role = m['role'] == 'user' ? 'User' : 'Assistant';
      return '$role: ${m['content']}';
    }).join('\n');

    final summaryPrompt = 'Summarize the key context, facts, and decisions from the following conversation history briefly in 1-2 paragraphs:\n\n$conversationText';

    try {
      safePrint('GeminiService: Summarizing ${messagesToSummarize.length} older messages...');
      final summary = await sendMessageOneShot(
        summaryPrompt,
        feature: 'summary',
        preferFlash: true,
        maxTokens: 250,
        systemInstruction: 'You are a helpful assistant. Provide a brief, objective summary of the conversation context to serve as history. Keep it concise.',
      );

      if (summary != null && summary.isNotEmpty) {
        String newSummaryContent = 'Summary of previous conversation:\n$summary';
        if (hasPreviousSummary) {
          final oldSummary = _messages[1]['content']!.replaceFirst('Summary of previous conversation:\n', '');
          final combinedPrompt = 'Combine these two summaries of a conversation history into a single concise summary (max 3 paragraphs):\n\nSummary 1:\n$oldSummary\n\nSummary 2:\n$summary';
          final combinedSummary = await sendMessageOneShot(
            combinedPrompt,
            feature: 'summary',
            preferFlash: true,
            maxTokens: 350,
            systemInstruction: 'Combine the summaries cleanly and concisely.',
          );
          if (combinedSummary != null && combinedSummary.isNotEmpty) {
            newSummaryContent = 'Summary of previous conversation:\n$combinedSummary';
          }
        }

        _messages.removeRange(startIdx, endIdx);
        
        if (hasPreviousSummary) {
          _messages[1] = {'role': 'system', 'content': newSummaryContent};
        } else {
          _messages.insert(1, {'role': 'system', 'content': newSummaryContent});
        }
        safePrint('GeminiService: Successfully summarized older messages. New _messages length: ${_messages.length}');
      }
    } catch (e) {
      safePrint('GeminiService: Error summarizing older messages: $e');
    }
  }

  Future<String?> sendMessage(
    String message, {
    required String feature,
    int maxTokens = 2000,
    bool preferFlash = true,
    String? cacheKey,
  }) async {
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

      context +=
          "Crucial: Your response must be complete, fully finished, and must never cut off mid-sentence. Keep it concise enough to fit within length constraints if necessary, but always complete it. "
          "Policy Directive: You are an AI companion, not a medical or mental health professional. You must NOT diagnose conditions, recommend medications, or provide medical/mental health treatment plans. If a user asks for medical advice, diagnoses, or treatment, you must politely remind them of your AI nature, advise them to consult a qualified healthcare professional, and decline to provide medical recommendations.";

      if (context.isNotEmpty) {
        _messages.add({'role': 'system', 'content': context});
      }
    }

    await _summarizeOlderMessages();

    _messages.add({'role': 'user', 'content': message});

    String? response;

    final systemMessage = _messages.firstWhere(
      (m) => m['role'] == 'system',
      orElse: () => <String, String>{},
    );
    final systemInstruction = systemMessage.isNotEmpty ? systemMessage['content'] : null;

    final String provider = _selectedLlmProvider;
    if (provider == 'Direct Gemini') {
      response = await _sendDirectGemini(
        contents: _convertToGenerativeContent(),
        systemInstruction: systemInstruction,
        feature: feature,
        maxTokens: maxTokens,
      );
    } else if (provider == 'Agent Router') {
      final configuredModels = ConfigService().agentRouterModels;
      response = await _sendAgentRouter(
        models: configuredModels,
        messages: _messages,
        feature: feature,
        maxTokens: maxTokens,
      );
    } else {
      // OpenRouter provider (default)
      final configuredModels = _isPro ? ConfigService().openRouterProModels : ConfigService().openRouterFreeModels;
      response = await _sendOpenRouter(
        models: configuredModels,
        messages: _messages,
        feature: feature,
        maxTokens: maxTokens,
      );
    }

    if (response != null) {
      _messages.add({'role': 'assistant', 'content': response});
      return response;
    }

    // Fallback if the selected provider fails
    safePrint('GeminiService: Selected provider ($provider) failed. Falling back to Direct Gemini...');
    response = await _sendDirectGemini(
      contents: _convertToGenerativeContent(),
      systemInstruction: systemInstruction,
      feature: feature,
      maxTokens: maxTokens,
    );
    if (response != null) {
      _messages.add({'role': 'assistant', 'content': response});
      return response;
    }

    // Ultimate Safety Net
    response = await _sendDirectGemini(
      contents: _convertToGenerativeContent(),
      systemInstruction: systemInstruction,
      feature: feature,
      maxTokens: maxTokens,
      overrideModel: 'gemini-2.5-flash',
    );
    if (response != null) {
      _messages.add({'role': 'assistant', 'content': response});
      return response;
    }

    throw Exception("Failed to get response from AI models. Please try again in a moment.");
  }

  Future<String?> sendMessageOneShot(
    String message, {
    String? systemInstruction,
    required String feature,
    int maxTokens = 2500,
    bool preferFlash = true,
    String? cacheKey,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
    }

    String defaultSystemInstruction = systemInstruction ?? '';
    if (defaultSystemInstruction.isEmpty) {
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
      defaultSystemInstruction = context;
    }

    final String completeInstruction = "$defaultSystemInstruction\nCrucial: Your response must be complete, fully finished, and must never cut off mid-sentence. Keep it concise enough to fit within length constraints if necessary, but always complete it. Policy Directive: You are an AI companion, not a medical or mental health professional. You must NOT diagnose conditions, recommend medications, or provide medical/mental health treatment plans. If a user asks for medical advice, diagnoses, or treatment, you must politely remind them of your AI nature, advise them to consult a qualified healthcare professional, and decline to provide medical recommendations.".trim();

    String? response;

    final List<Map<String, String>> messages = [];
    if (completeInstruction.isNotEmpty) {
      messages.add({'role': 'system', 'content': completeInstruction});
    }
    messages.add({'role': 'user', 'content': message});

    final String provider = _selectedLlmProvider;
    if (provider == 'Direct Gemini') {
      response = await _sendDirectGemini(
        contents: [Content.text(message)],
        systemInstruction: completeInstruction,
        feature: feature,
        maxTokens: maxTokens,
      );
    } else if (provider == 'Agent Router') {
      final configuredModels = ConfigService().agentRouterModels;
      response = await _sendAgentRouter(
        models: configuredModels,
        messages: messages,
        feature: feature,
        maxTokens: maxTokens,
      );
    } else {
      // OpenRouter provider (default)
      final configuredModels = _isPro ? ConfigService().openRouterProModels : ConfigService().openRouterFreeModels;
      response = await _sendOpenRouter(
        models: configuredModels,
        messages: messages,
        feature: feature,
        maxTokens: maxTokens,
      );
    }

    if (response != null) {
      return response;
    }

    // Fallback if the selected provider fails
    safePrint('GeminiService OneShot: Selected provider ($provider) failed. Falling back to Direct Gemini...');
    response = await _sendDirectGemini(
      contents: [Content.text(message)],
      systemInstruction: completeInstruction,
      feature: feature,
      maxTokens: maxTokens,
    );
    if (response != null) {
      return response;
    }

    // Ultimate Safety Net
    response = await _sendDirectGemini(
      contents: [Content.text(message)],
      systemInstruction: completeInstruction,
      feature: feature,
      maxTokens: maxTokens,
      overrideModel: 'gemini-2.5-flash',
    );
    if (response != null) {
      return response;
    }

    throw Exception("Failed to get response from AI models. Please try again in a moment.");
  }

  Future<List<String>> listModels(String apiKey) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://openrouter.ai/api/v1/models',
        options: Options(headers: {'Authorization': 'Bearer ${apiKey.trim()}'}),
      );

      if (response.statusCode == 200 && response.data != null && response.data['data'] != null) {
        final List data = response.data['data'];
        final models = data
            .map((m) => m['id'].toString())
            .where((id) {
              if (_isPro) {
                return id.contains(':free') || id.contains('flash') || id.contains('gpt') || id.contains('claude');
              } else {
                return id.endsWith(':free');
              }
            })
            .toList();

        if (models.isNotEmpty) {
          _availableModels = models;
          return models;
        }
      }
    } catch (e) {
      safePrint('List Models Error: $e');
    }

    return _isPro ? ConfigService().openRouterProModels : ConfigService().openRouterFreeModels;
  }

  void resetChat() {
    _messages.clear();
  }



  void _logUsage({
    required String model,
    required String feature,
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
        'feature': feature,
        'source': source,
        'promptTokens': promptTokens,
        'responseTokens': responseTokens,
        'totalTokens': totalTokens,
        'status': status,
        'errorMessage': errorMessage,
      }).catchError((e) {
        safePrint('GeminiService Log Usage Error (async): $e');
      });
    } catch (e) {
      safePrint('GeminiService Log Usage Error (sync): $e');
    }
  }
}

