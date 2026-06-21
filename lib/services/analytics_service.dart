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

  static Future<void> logPersonalizationCompleted(List<String> goals) async {
    await _analytics.logEvent(
      name: 'personalization_completed',
      parameters: {'goals': goals.join('|'), 'goal_count': goals.length},
    );
  }

  static Future<void> logFirstSessionComplete(String sessionType) async {
    await _analytics.logEvent(
      name: 'first_session_complete',
      parameters: {'session_type': sessionType},
    );
  }

  static Future<void> logEngagementAction(
    String action, {
    required int xpGain,
    required int streak,
    required int level,
  }) async {
    await _analytics.logEvent(
      name: 'engagement_action',
      parameters: {
        'action': action,
        'xp_gain': xpGain,
        'streak': streak,
        'level': level,
      },
    );
  }

  static Future<void> logStreakDay(int streak) async {
    await _analytics.logEvent(
      name: 'streak_day',
      parameters: {'streak_count': streak},
    );
  }

  static Future<void> logLevelUp(int level) async {
    await _analytics.logEvent(
      name: 'level_up',
      parameters: {'level': level},
    );
  }

  static Future<void> logPaywallShown(String feature) async {
    await _analytics.logEvent(
      name: 'paywall_shown',
      parameters: {'feature': feature},
    );
  }

  static Future<void> logShareCard(String mode) async {
    await _analytics.logEvent(
      name: 'share_card_created',
      parameters: {'mode': mode},
    );
  }

  static Future<void> logReferralApplied(String code) async {
    await _analytics.logEvent(
      name: 'referral_applied',
      parameters: {'code': code},
    );
  }

  static Future<void> logNotificationOpened(String type) async {
    await _analytics.logEvent(
      name: 'notification_opened',
      parameters: {'type': type},
    );
  }
}
