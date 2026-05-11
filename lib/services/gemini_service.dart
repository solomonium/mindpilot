import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mindpilot/export.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  GenerativeModel? _model;
  ChatSession? _chat;

  void init(String apiKey, {String modelName = 'gemini-1.5-flash'}) {
    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );
    _chat = _model!.startChat();
  }

  Future<String?> sendMessage(String message) async {
    if (_chat == null) return "AI not initialized. Please check your API key.";

    try {
      final response = await _chat!.sendMessage(Content.text(message));
      return response.text;
    } catch (e) {
      safePrint('Gemini Error: $e');
      return "Sorry, I'm having trouble connecting right now. Please try again.";
    }
  }

  Future<List<String>> listModels(String apiKey) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      if (response.statusCode == 200) {
        final List models = response.data['models'];
        return models
            .map((m) => m['name'].toString().replaceFirst('models/', ''))
            .where((name) => name.contains('gemini'))
            .toList();
      }
    } catch (e) {
      safePrint('List Models Error: $e');
    }
    return ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-1.0-pro'];
  }

  void resetChat() {
    if (_model != null) {
      _chat = _model!.startChat();
    }
  }
}
