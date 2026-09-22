import 'dart:io';

import 'package:flutter/services.dart';

import 'package:mindpilot/export.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  static Future<void> shareText(String text, {String? subject}) async {
    await Share.share(
      text,
      subject: subject,
    );
  }

  static Future<void> shareToWhatsApp(String text) async {
    try {
      final encoded = Uri.encodeComponent(text);
      final url = Uri.parse("https://wa.me/?text=$encoded");
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await shareText(text);
      }
    } catch (_) {
      await shareText(text);
    }
  }

  /// Returns a human-readable label for a quiz scope type key.
  static String _getScopeLabel(String scopeType, String scopeValue) {
    switch (scopeType) {
      case 'general':     return 'General Bible Knowledge';
      case 'chapter':     return 'Bible Chapter Study';
      case 'tech':        return 'Technology & Coding';
      case 'science':     return 'Science & Physics';
      case 'english':     return 'English & Literature';
      case 'economics':   return 'Economics & Finance';
      case 'mindfulness': return 'Personality & Mindfulness';
      case 'custom':      return scopeValue.isNotEmpty ? scopeValue : 'Custom Topic';
      default:            return scopeType;
    }
  }

  static String buildGroupInviteContent({
    required String groupId,
    required String groupName,
    required String scopeType,
    String scopeValue = '',
  }) {
    final scopeLabel = _getScopeLabel(scopeType, scopeValue);
    final shareUrl = ConfigService().shareUrl;
    return '🎯 Join my $scopeLabel quiz challenge on MindPilot!\n\n'
        '$shareUrl\n\n'
        'Use my invite code to join: mindpilot-group-invite:$groupId:$groupName';
  }

  /// Returns the compact deep-link encoded into the QR code.
  /// Format: mindpilot://group/<groupId>/<encodedName>
  static String buildGroupQrData({
    required String groupId,
    required String groupName,
  }) {
    final encoded = Uri.encodeComponent(groupName);
    return 'mindpilot://group/$groupId/$encoded';
  }

  /// Compose the invite text and show a multi-platform share bottom sheet.
  static Future<void> shareGroupInvite({
    required BuildContext context,
    required String groupId,
    required String groupName,
    required String scopeType,
    String scopeValue = '',
  }) async {
    final inviteText = buildGroupInviteContent(
      groupId: groupId,
      groupName: groupName,
      scopeType: scopeType,
      scopeValue: scopeValue,
    );

    await Share.share(
      inviteText,
      sharePositionOrigin: AppHelper.getSharePositionOrigin(context),
    );
  }

  static Future<void> captureAndShare(
    BuildContext context, {
    required Widget widget,
    String? text,
    String? subject,
  }) async {
    if (!await AppHelper.isOnline()) {
      if (context.mounted) {
        context.showInAppNotification('Network required to share.');
      }
      return;
    }

    if (!context.mounted) return;

    // Capture screen info early to avoid View.of() errors in background
    final mediaQuery = MediaQuery.of(context);
    final theme = context.read<AppTheme>();

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFADFF2F)),
        ),
      );

      // 1. Create a fresh controller for every capture to avoid state corruption
      final controller = ScreenshotController();

      // 2. Capture with hard constraints and explicit pixel ratio injection
      final Uint8List imageBytes = await controller.captureFromWidget(
        MediaQuery(
          data: mediaQuery.copyWith(
            devicePixelRatio: mediaQuery.devicePixelRatio,
          ),
          child: Provider.value(
            value: theme,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: widget,
              ),
            ),
          ),
        ),
        context: context,
        delay: const Duration(milliseconds: 500),
      );

      // Pop loading
      if (context.mounted) Navigator.pop(context);

      final directory = await getTemporaryDirectory();
      final imagePath = File(
        '${directory.path}/mindpilot_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await imagePath.writeAsBytes(imageBytes);

      final shareText = text ?? 'Check out my progress on MindPilot! 🚀';
      try {
        await Clipboard.setData(ClipboardData(text: shareText));
        if (context.mounted) {
          context.showInAppNotification(
            'Caption copied to clipboard! You can paste it into your post.',
            type: InAppNotificationType.info,
          );
        }
      } catch (_) {}
      if (!context.mounted) return;
      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: shareText,
        subject: subject,
        sharePositionOrigin: AppHelper.getSharePositionOrigin(context),
      );
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (context.mounted) {
        context.showInAppNotification("Sharing failed: $e");
      }
      safePrint("Sharing Error: $e");
    }
  }
}
