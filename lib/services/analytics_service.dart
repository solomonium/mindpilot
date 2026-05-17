import 'package:mindpilot/export.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  static Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  static Future<void> logScreenView(String screenName) async {
    await _analytics.logEvent(
      name: 'screen_view',
      parameters: {'screen_name': screenName},
    );
  }

  static Future<void> logProUpgrade(String plan) async {
    await _analytics.logEvent(
      name: 'pro_upgrade',
      parameters: {'plan': plan, 'timestamp': DateTime.now().toIso8601String()},
    );
  }

  static Future<void> logAIChat(String model) async {
    await _analytics.logEvent(
      name: 'ai_chat_message',
      parameters: {'model': model},
    );
  }
}
