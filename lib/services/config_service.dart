import 'dart:io';
import 'package:mindpilot/export.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Default values
  int _quoteIntervalMs = 3600000; // 1 hour
  String _latestVersion = '1.0.0';
  bool _forceUpdate = false;
  String _updateUrl = 'https://play.google.com/store/apps/details?id=com.mindpilot.app';
  String _shareUrl = 'https://mindpilot-131f1.web.app/share';
  String _supportPhone = '09043230179';
  int _authenticatedUsersCount = 0;

  String _currentAppVersion = '1.0.1';

  // Dynamic AI Model Configurations
  List<String> _openRouterFreeModels = [
    'google/gemma-4-31b-it:free',
    'google/gemma-4-26b-a4b-it:free',
    'openai/gpt-oss-20b:free',
    'cohere/north-mini-code:free',
    'poolside/laguna-s-2.1:free',
  ];

  List<String> _openRouterProModels = [
    'anthropic/claude-3.5-sonnet',
    'openai/gpt-4o',
    'openai/gpt-4o-mini',
    'anthropic/claude-3.5-haiku',
    'deepseek/deepseek-chat',
  ];

  String _directGeminiModel = 'gemini-2.5-flash';
  List<String> _agentRouterModels = [];

  // Dynamic AI API Keys (Fetched remotely with .env fallback)
  String _geminiApiKey = '';
  String _openRouterApiKey = '';
  String _agentRouterApiKey = '';

  // WhatsApp Alert Configuration
  String _whatsappAlertPhone = '+2347066481782';
  String _whatsappAlertApiKey = '';
  String _textMeBotApiKey = '';

  // Telegram Alert Configuration
  String _telegramBotToken = '';
  String _telegramChatId = '';

  int get quoteIntervalMs => _quoteIntervalMs;
  String get latestVersion => _latestVersion;
  String get currentAppVersion => _currentAppVersion;
  bool get forceUpdate => _forceUpdate;
  String get updateUrl {
    if (Platform.isIOS) {
      return 'https://apps.apple.com/ng/app/mind-pilot/id6770153795';
    }
    return _updateUrl;
  }
  String get shareUrl => _shareUrl;
  String get supportPhone => _supportPhone;
  int get authenticatedUsersCount => _authenticatedUsersCount;
  List<String> get openRouterFreeModels => _openRouterFreeModels;
  List<String> get openRouterProModels => _openRouterProModels;
  String get directGeminiModel => _directGeminiModel;
  List<String> get agentRouterModels => _agentRouterModels;

  String get whatsappAlertPhone {
    if (_whatsappAlertPhone.trim().isNotEmpty) return _whatsappAlertPhone.trim();
    return (dotenv.env['WHATSAPP_ALERT_PHONE'] ?? '+2347066481782').trim();
  }

  String get whatsappAlertApiKey {
    if (_whatsappAlertApiKey.trim().isNotEmpty) return _whatsappAlertApiKey.trim();
    return (dotenv.env['WHATSAPP_ALERT_API_KEY'] ?? '').trim();
  }

  String get textMeBotApiKey {
    if (_textMeBotApiKey.trim().isNotEmpty) return _textMeBotApiKey.trim();
    return (dotenv.env['TEXTMEBOT_API_KEY'] ?? '').trim();
  }

  String get telegramBotToken {
    if (_telegramBotToken.trim().isNotEmpty) return _telegramBotToken.trim();
    return (dotenv.env['TELEGRAM_BOT_TOKEN'] ?? '').trim();
  }

  String get telegramChatId {
    if (_telegramChatId.trim().isNotEmpty) return _telegramChatId.trim();
    return (dotenv.env['TELEGRAM_CHAT_ID'] ?? '').trim();
  }

  String get geminiApiKey {
    if (_geminiApiKey.trim().isNotEmpty) return _geminiApiKey.trim();
    return (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
  }

  String get openRouterApiKey {
    if (_openRouterApiKey.trim().isNotEmpty) return _openRouterApiKey.trim();
    return (dotenv.env['OPEN_ROUTER_API_KEY'] ?? '').trim();
  }

  String get agentRouterApiKey {
    if (_agentRouterApiKey.trim().isNotEmpty) return _agentRouterApiKey.trim();
    return (dotenv.env['AGENT_ROUTER_API_KEY'] ?? '').trim();
  }

  Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentAppVersion = packageInfo.version;
      safePrint('ℹ️ Current App Version from Platform: $_currentAppVersion');
    } catch (e) {
      safePrint('⚠️ Failed to load App Version from Platform: $e');
    }
  }

  Future<void> fetchRemoteConfig() async {
    try {
      final doc = await _firestore.collection('app_config').doc('settings').get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _quoteIntervalMs = data['quote_interval_ms'] ?? 3600000;
        _latestVersion = data['latest_version'] ?? '1.0.0';
        _forceUpdate = data['force_update'] ?? false;
        _updateUrl = data['update_url'] ?? _updateUrl;
        _shareUrl = data['share_url'] ?? _shareUrl;
        _supportPhone = data['support_phone'] ?? _supportPhone;
        _authenticatedUsersCount = data['authenticated_users_count'] ?? 0;
        
        if (data['openrouter_free_models'] != null && (data['openrouter_free_models'] as List).isNotEmpty) {
          _openRouterFreeModels = List<String>.from(data['openrouter_free_models']);
        }

        if (data['openrouter_pro_models'] != null && (data['openrouter_pro_models'] as List).isNotEmpty) {
          _openRouterProModels = List<String>.from(data['openrouter_pro_models']);
        }

        if (data['direct_gemini_model'] != null && (data['direct_gemini_model'] as String).isNotEmpty) {
          _directGeminiModel = data['direct_gemini_model'];
        }

        if (data['agent_router_models'] != null && (data['agent_router_models'] as List).isNotEmpty) {
          _agentRouterModels = List<String>.from(data['agent_router_models']);
        }

        // Load Remote API Keys if present
        if (data['gemini_api_key'] != null && (data['gemini_api_key'] as String).trim().isNotEmpty) {
          _geminiApiKey = (data['gemini_api_key'] as String).trim();
        }

        if (data['openrouter_api_key'] != null && (data['openrouter_api_key'] as String).trim().isNotEmpty) {
          _openRouterApiKey = (data['openrouter_api_key'] as String).trim();
        }

        if (data['agent_router_api_key'] != null && (data['agent_router_api_key'] as String).trim().isNotEmpty) {
          _agentRouterApiKey = (data['agent_router_api_key'] as String).trim();
        }

        // Load Remote WhatsApp Alert Config
        if (data['whatsapp_alert_phone'] != null && (data['whatsapp_alert_phone'] as String).trim().isNotEmpty) {
          _whatsappAlertPhone = (data['whatsapp_alert_phone'] as String).trim();
        }

        if (data['whatsapp_alert_api_key'] != null && (data['whatsapp_alert_api_key'] as String).trim().isNotEmpty) {
          _whatsappAlertApiKey = (data['whatsapp_alert_api_key'] as String).trim();
        }

        if (data['textmebot_api_key'] != null && (data['textmebot_api_key'] as String).trim().isNotEmpty) {
          _textMeBotApiKey = (data['textmebot_api_key'] as String).trim();
        }

        // Load Remote Telegram Alert Config
        if (data['telegram_bot_token'] != null && (data['telegram_bot_token'] as String).trim().isNotEmpty) {
          _telegramBotToken = (data['telegram_bot_token'] as String).trim();
        }

        if (data['telegram_chat_id'] != null && (data['telegram_chat_id'] as String).trim().isNotEmpty) {
          _telegramChatId = (data['telegram_chat_id'] as String).trim();
        }

        safePrint('✅ Remote Config Loaded: Interval=$_quoteIntervalMs, Version=$_latestVersion, AuthUsers=$_authenticatedUsersCount, FreeModels=${_openRouterFreeModels.length}, ProModels=${_openRouterProModels.length}, DirectModel=$_directGeminiModel, HasRemoteGeminiKey=${_geminiApiKey.isNotEmpty}, HasRemoteOpenRouterKey=${_openRouterApiKey.isNotEmpty}, HasWhatsAppAlertKey=${_whatsappAlertApiKey.isNotEmpty}, HasTelegramBot=${_telegramBotToken.isNotEmpty}');
      } else {
        safePrint('⚠️ Remote Config doc not found. Using defaults.');
      }
    } catch (e) {
      safePrint('❌ Error fetching remote config: $e');
    }
  }

  bool isUpdateRequired(String currentVersion) {
    try {
      // Clean build numbers (e.g. 1.0.1+2 -> 1.0.1)
      final currentClean = currentVersion.split('+').first.trim();
      final latestClean = _latestVersion.split('+').first.trim();

      final currentParts = currentClean.split('.').map(int.parse).toList();
      final latestParts = latestClean.split('.').map(int.parse).toList();

      final maxLength = currentParts.length > latestParts.length ? currentParts.length : latestParts.length;
      for (int i = 0; i < maxLength; i++) {
        final currentVal = i < currentParts.length ? currentParts[i] : 0;
        final latestVal = i < latestParts.length ? latestParts[i] : 0;

        if (latestVal > currentVal) return true;
        if (currentVal > latestVal) return false;
      }
      return false;
    } catch (e) {
      safePrint('Error during version comparison: $e');
      // Fallback to string comparison
      return _latestVersion.compareTo(currentVersion) > 0;
    }
  }
}
