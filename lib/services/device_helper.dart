import 'dart:io';
import 'package:flutter/foundation.dart';

class DeviceHelper {
  /// Returns a clean, user-friendly device name e.g. "iPhone", "Android", "Web"
  static String get currentDevice {
    if (kIsWeb) return 'Web';
    try {
      if (Platform.isIOS) return 'iPhone';
      if (Platform.isAndroid) return 'Android';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isLinux) return 'Linux';
    } catch (_) {}
    return 'Unknown Device';
  }

  /// Returns normalized device label given raw stored string or user data
  static String formatDevice(dynamic rawDevice, [Map<String, dynamic>? userData]) {
    if (rawDevice != null) {
      final str = rawDevice.toString().trim();
      if (str.isNotEmpty && str.toLowerCase() != 'unknown' && str.toLowerCase() != 'null') {
        if (str.toLowerCase().contains('ios') ||
            str.toLowerCase().contains('iphone') ||
            str.toLowerCase().contains('apple')) {
          return 'iPhone';
        }
        if (str.toLowerCase().contains('android')) {
          return 'Android';
        }
        return str;
      }
    }

    // Intelligent inference for existing users who logged in before device logging
    if (userData != null) {
      final email = (userData['email'] as String? ?? '').toLowerCase();
      if (email.contains('privaterelay.appleid.com') ||
          userData['provider'] == 'apple.com' ||
          userData['appleId'] != null) {
        return 'iPhone';
      }
    }

    return 'Not recorded yet';
  }

  /// Returns true if device is Apple / iOS
  static bool isApple(String device) {
    final lower = device.toLowerCase();
    return lower.contains('iphone') || lower.contains('ios') || lower.contains('apple');
  }

  /// Returns true if device is Android
  static bool isAndroid(String device) {
    return device.toLowerCase().contains('android');
  }
}
