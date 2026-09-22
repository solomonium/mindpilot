import 'dart:async';
import 'package:mindpilot/export.dart';

class AiDowntimeAlertService {
  static final AiDowntimeAlertService _instance = AiDowntimeAlertService._internal();
  factory AiDowntimeAlertService() => _instance;
  AiDowntimeAlertService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static const List<String> _superAdmins = [
    'laleyesolomon2@gmail.com',
    'solteqinnovationsltd@gmail.com',
  ];

  /// Checks if the error message indicates a critical API key, auth, or gateway failure.
  bool isCriticalDowntimeError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('api_key') ||
        lower.contains('api key') ||
        lower.contains('permission_denied') ||
        lower.contains('unauthorized') ||
        lower.contains('401') ||
        lower.contains('402') ||
        lower.contains('403') ||
        lower.contains('429') ||
        lower.contains('quota') ||
        lower.contains('exhausted') ||
        lower.contains('leaked') ||
        lower.contains('billing') ||
        lower.contains('all attempted models failed') ||
        lower.contains('failed to get response from ai models');
  }

  /// Reports an AI failure and triggers WhatsApp + Local Notification if criteria are met.
  Future<void> reportFailure({
    required String provider,
    required String feature,
    required String errorMessage,
    bool force = false,
  }) async {
    if (!force && !isCriticalDowntimeError(errorMessage)) {
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final alertDocRef = firestore.collection('app_config').doc('ai_downtime_alert');

      // 1. Check Cooldown (45 minutes) unless forced
      if (!force) {
        final alertDoc = await alertDocRef.get();
        if (alertDoc.exists) {
          final data = alertDoc.data() ?? {};
          final Timestamp? lastSent = data['lastAlertSentAt'] as Timestamp?;
          if (lastSent != null) {
            final difference = DateTime.now().difference(lastSent.toDate());
            if (difference.inMinutes < 45) {
              safePrint('AiDowntimeAlertService: Cooldown active (${difference.inMinutes}m / 45m). Suppressing duplicate WhatsApp alert.');
              // Still record current health status in Firestore
              _updateAiHealthStatus(provider: provider, error: errorMessage, isDown: true);
              return;
            }
          }
        }
      }

      // 2. Mark cooldown timestamp immediately in Firestore
      await alertDocRef.set({
        'lastAlertSentAt': FieldValue.serverTimestamp(),
        'lastError': errorMessage,
        'lastProvider': provider,
        'lastFeature': feature,
        'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'anonymous_user',
      }, SetOptions(merge: true));

      // 3. Update global health status document
      await _updateAiHealthStatus(provider: provider, error: errorMessage, isDown: true);

      // 4. Send Notifications to Admin (Telegram + TextMeBot + CallMeBot)
      await Future.wait([
        sendTelegramNotification(
          provider: provider,
          feature: feature,
          errorMessage: errorMessage,
        ),
        sendTextMeBotNotification(
          provider: provider,
          feature: feature,
          errorMessage: errorMessage,
        ),
        sendWhatsAppNotification(
          provider: provider,
          feature: feature,
          errorMessage: errorMessage,
        ),
      ]);

      // 5. Trigger Local Heads-Up Push Notification if the current user is an Admin
      _triggerLocalAdminPushNotification(
        title: '🚨 CRITICAL: MindPilot AI is DOWN',
        body: '$provider failed on "$feature": ${_cleanErrorMessage(errorMessage)}',
      );
    } catch (e) {
      safePrint('AiDowntimeAlertService reportFailure error: $e');
    }
  }

  /// Sends a WhatsApp message via CallMeBot API directly to the admin phone.
  Future<bool> sendWhatsAppNotification({
    required String provider,
    required String feature,
    required String errorMessage,
  }) async {
    final config = ConfigService();
    final phone = config.whatsappAlertPhone.trim();
    final apiKey = config.whatsappAlertApiKey.trim();

    if (phone.isEmpty) {
      safePrint('AiDowntimeAlertService: WhatsApp alert phone number is not configured.');
      return false;
    }

    if (apiKey.isEmpty) {
      safePrint('AiDowntimeAlertService: WhatsApp CallMeBot API key is not configured in remote config or .env.');
      return false;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final cleanError = _cleanErrorMessage(errorMessage);
    final timestamp = DateTime.now().toLocal().toString().split('.').first;

    final messageText = '''
🚨 *CRITICAL: MindPilot AI Service is DOWN!*

• *Provider*: $provider
• *Feature*: $feature
• *Error*: $cleanError
• *Time*: $timestamp

⚠️ *Action Required*: Users are unable to receive AI responses. Please update your API key in the MindPilot Admin Dashboard.
'''.trim();

    try {
      final response = await _dio.get(
        'https://api.callmebot.com/whatsapp.php',
        queryParameters: {
          'phone': cleanPhone,
          'text': messageText,
          'apikey': apiKey,
        },
      );

      safePrint('AiDowntimeAlertService WhatsApp response: ${response.statusCode} - ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      safePrint('AiDowntimeAlertService WhatsApp Error: $e');
      return false;
    }
  }

  /// Sends a test message to verify the WhatsApp configuration.
  Future<Map<String, dynamic>> testWhatsAppAlert() async {
    final config = ConfigService();
    final phone = config.whatsappAlertPhone.trim();
    final apiKey = config.whatsappAlertApiKey.trim();

    if (phone.isEmpty) {
      return {'success': false, 'message': 'WhatsApp phone number is missing.'};
    }
    if (apiKey.isEmpty) {
      return {
        'success': false,
        'message': 'CallMeBot API Key is empty. Please enter your API key first.',
      };
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final timestamp = DateTime.now().toLocal().toString().split('.').first;
    final messageText = '''
✅ *MindPilot AI Downtime Alert Test*

Your WhatsApp downtime notification system is active!
• *Target*: $cleanPhone
• *Timestamp*: $timestamp

You will receive instant alerts here if Direct Gemini or OpenRouter encounters API key or quota failure.
'''.trim();

    try {
      final response = await _dio.get(
        'https://api.callmebot.com/whatsapp.php',
        queryParameters: {
          'phone': cleanPhone,
          'text': messageText,
          'apikey': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final bodyText = response.data?.toString() ?? '';
        if (bodyText.contains('error') || bodyText.contains('Invalid APIKey')) {
          return {
            'success': false,
            'message': 'CallMeBot Error: $bodyText',
          };
        }
        return {
          'success': true,
          'message': 'WhatsApp test alert sent successfully!',
        };
      } else {
        return {
          'success': false,
          'message': 'Server responded with HTTP ${response.statusCode}: ${response.data}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error sending WhatsApp test: $e',
      };
    }
  }

  /// Sends a WhatsApp message via TextMeBot API directly to the admin phone.
  Future<bool> sendTextMeBotNotification({
    required String provider,
    required String feature,
    required String errorMessage,
  }) async {
    final config = ConfigService();
    final phone = config.whatsappAlertPhone.trim();
    final apiKey = config.textMeBotApiKey.trim();

    if (phone.isEmpty || apiKey.isEmpty) {
      safePrint('AiDowntimeAlertService: TextMeBot is not configured.');
      return false;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final cleanError = _cleanErrorMessage(errorMessage);
    final timestamp = DateTime.now().toLocal().toString().split('.').first;

    final messageText = '''
🚨 *CRITICAL: MindPilot AI Service is DOWN!*

• *Provider*: $provider
• *Feature*: $feature
• *Error*: $cleanError
• *Time*: $timestamp

⚠️ *Action Required*: Users are unable to receive AI responses. Please update your API key in the MindPilot Admin Dashboard.
'''.trim();

    try {
      final response = await _dio.get(
        'https://api.textmebot.com/send.php',
        queryParameters: {
          'recipient': cleanPhone,
          'apikey': apiKey,
          'text': messageText,
          'json': 'yes',
        },
      );

      safePrint('AiDowntimeAlertService TextMeBot response: ${response.statusCode} - ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      safePrint('AiDowntimeAlertService TextMeBot Error: $e');
      return false;
    }
  }

  /// Sends a test message to verify the TextMeBot configuration.
  Future<Map<String, dynamic>> testTextMeBotAlert() async {
    final config = ConfigService();
    final phone = config.whatsappAlertPhone.trim();
    final apiKey = config.textMeBotApiKey.trim();

    if (phone.isEmpty) {
      return {'success': false, 'message': 'WhatsApp phone number is missing.'};
    }
    if (apiKey.isEmpty) {
      return {
        'success': false,
        'message': 'TextMeBot API Key is empty. Please enter your TextMeBot API key in Configuration.',
      };
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final timestamp = DateTime.now().toLocal().toString().split('.').first;
    final messageText = '''
✅ *MindPilot AI Downtime Alert Test (TextMeBot)*

Your TextMeBot WhatsApp downtime alert is active!
• *Target*: $cleanPhone
• *Timestamp*: $timestamp

You will receive instant alerts here if Direct Gemini or OpenRouter encounters failure.
'''.trim();

    try {
      final response = await _dio.get(
        'https://api.textmebot.com/send.php',
        queryParameters: {
          'recipient': cleanPhone,
          'apikey': apiKey,
          'text': messageText,
          'json': 'yes',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['status'] == 'error') {
          return {
            'success': false,
            'message': 'TextMeBot Error: ${data['message'] ?? data}',
          };
        }
        return {
          'success': true,
          'message': 'TextMeBot WhatsApp alert delivered successfully to your phone!',
        };
      } else {
        return {
          'success': false,
          'message': 'TextMeBot responded with HTTP ${response.statusCode}: ${response.data}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error sending TextMeBot test: $e',
      };
    }
  }

  /// Sends a Telegram message via official Telegram Bot API directly to admin.
  Future<bool> sendTelegramNotification({
    required String provider,
    required String feature,
    required String errorMessage,
  }) async {
    final config = ConfigService();
    final token = config.telegramBotToken.trim();
    final chatId = config.telegramChatId.trim();

    if (token.isEmpty || chatId.isEmpty) {
      safePrint('AiDowntimeAlertService: Telegram Bot is not configured.');
      return false;
    }

    final cleanError = _cleanErrorMessage(errorMessage);
    final timestamp = DateTime.now().toLocal().toString().split('.').first;

    final messageText = '''
🚨 *CRITICAL: MindPilot AI Service is DOWN!*

• *Provider*: $provider
• *Feature*: $feature
• *Error*: $cleanError
• *Time*: $timestamp

⚠️ *Action Required*: Users are unable to receive AI responses. Please update your API key in the MindPilot Admin Dashboard.
'''.trim();

    try {
      final response = await _dio.post(
        'https://api.telegram.org/bot$token/sendMessage',
        data: {
          'chat_id': chatId,
          'text': messageText,
          'parse_mode': 'Markdown',
        },
      );

      safePrint('AiDowntimeAlertService Telegram response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      safePrint('AiDowntimeAlertService Telegram Error: $e');
      return false;
    }
  }

  /// Sends a test message to verify the Telegram Bot configuration.
  Future<Map<String, dynamic>> testTelegramAlert() async {
    final config = ConfigService();
    final token = config.telegramBotToken.trim();
    final chatId = config.telegramChatId.trim();

    if (token.isEmpty) {
      return {'success': false, 'message': 'Telegram Bot Token is missing.'};
    }
    if (chatId.isEmpty) {
      return {'success': false, 'message': 'Telegram Chat ID is missing.'};
    }

    final timestamp = DateTime.now().toLocal().toString().split('.').first;
    final messageText = '''
✅ *MindPilot AI Downtime Alert Test*

Your Telegram downtime alert bot is working!
• *Target Chat ID*: $chatId
• *Timestamp*: $timestamp

You will receive instant alerts here if Direct Gemini or OpenRouter encounters API key or quota failure.
'''.trim();

    try {
      final response = await _dio.post(
        'https://api.telegram.org/bot$token/sendMessage',
        data: {
          'chat_id': chatId,
          'text': messageText,
          'parse_mode': 'Markdown',
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Telegram test alert delivered successfully to your chat!',
        };
      } else {
        return {
          'success': false,
          'message': 'Telegram API returned HTTP ${response.statusCode}: ${response.data}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network/Telegram error: $e',
      };
    }
  }

  /// Updates Firestore collection app_config/ai_health with live gateway state
  Future<void> _updateAiHealthStatus({
    required String provider,
    required String error,
    required bool isDown,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('app_config').doc('ai_health').set({
        'status': isDown ? 'down' : 'operational',
        'provider': provider,
        'lastError': error,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      safePrint('Error updating ai_health doc: $e');
    }
  }

  /// Triggers a local heads-up notification if the current user is an admin
  void _triggerLocalAdminPushNotification({
    required String title,
    required String body,
  }) {
    try {
      final currentUserEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim();
      final isAdmin = currentUserEmail != null && _superAdmins.contains(currentUserEmail);

      if (isAdmin) {
        NotificationService().showAdminCriticalAlert(
          title: title,
          body: body,
        );
      }
    } catch (e) {
      safePrint('Error triggering local admin notification: $e');
    }
  }

  String _cleanErrorMessage(String error) {
    String clean = error.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length > 250) {
      clean = '${clean.substring(0, 247)}...';
    }
    return clean;
  }
}
