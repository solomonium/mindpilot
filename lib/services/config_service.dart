import 'dart:io';
import 'package:mindpilot/export.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Default values
  int _quoteIntervalMs = 3600000; // 1 hour
  String _latestVersion = '1.0.0';
  bool _forceUpdate = false;
  String _updateUrl = 'https://play.google.com/store/apps/details?id=com.mindpilot.app';
  String _shareUrl = 'https://mindpilot-131f1.web.app/share';
  String _supportPhone = '09043230179';
  int _authenticatedUsersCount = 0;

  String _currentAppVersion = '1.0.1';

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
        
        safePrint('✅ Remote Config Loaded: Interval=$_quoteIntervalMs, Version=$_latestVersion, AuthUsers=$_authenticatedUsersCount');
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
