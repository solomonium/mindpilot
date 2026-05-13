import 'package:mindpilot/export.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Default values
  int _quoteIntervalMs = 10800000; // 3 hours
  String _latestVersion = '1.0.0';
  bool _forceUpdate = false;
  String _updateUrl = 'https://play.google.com/store/apps/details?id=com.mindpilot.app';

  int get quoteIntervalMs => _quoteIntervalMs;
  String get latestVersion => _latestVersion;
  bool get forceUpdate => _forceUpdate;
  String get updateUrl => _updateUrl;

  Future<void> fetchRemoteConfig() async {
    try {
      final doc = await _firestore.collection('app_config').doc('settings').get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _quoteIntervalMs = data['quote_interval_ms'] ?? 10800000;
        _latestVersion = data['latest_version'] ?? '1.0.0';
        _forceUpdate = data['force_update'] ?? false;
        _updateUrl = data['update_url'] ?? _updateUrl;
        
        safePrint('✅ Remote Config Loaded: Interval=$_quoteIntervalMs, Version=$_latestVersion');
      } else {
        safePrint('⚠️ Remote Config doc not found. Using defaults.');
      }
    } catch (e) {
      safePrint('❌ Error fetching remote config: $e');
    }
  }

  bool isUpdateRequired(String currentVersion) {
    // Simple version comparison (1.0.0 style)
    return _latestVersion.compareTo(currentVersion) > 0;
  }
}
