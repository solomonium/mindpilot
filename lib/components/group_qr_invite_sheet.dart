import 'dart:io';
import 'dart:ui';
import 'package:mindpilot/export.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppShareSheet
// A universal bottom sheet that offers two sharing options:
//  1. Share as QR code image (scan-to-join, no scary link)
//  2. Share as text / link (existing behaviour)
//
// Use [AppShareSheet.showForGroup] for group-quiz invites.
// Use [AppShareSheet.showForReferral] for app-download / referral invites.
// ─────────────────────────────────────────────────────────────────────────────

class AppShareSheet extends StatefulWidget {
  /// Data to encode inside the QR code (a deep-link or URL).
  final String qrData;

  /// The human-readable title shown at the top of the sheet.
  final String title;

  /// Subtitle / caption below the title (e.g. group name or user name).
  final String subtitle;

  /// The full invite / share text sent via the native share sheet.
  final String shareText;

  /// Subject line for the share sheet.
  final String shareSubject;

  /// Label displayed on the QR card (e.g. group name or "MindPilot").
  final String qrCardLabel;

  /// Secondary label under the card label (e.g. scope or tagline).
  final String qrCardSublabel;

  const AppShareSheet._({
    super.key,
    required this.qrData,
    required this.title,
    required this.subtitle,
    required this.shareText,
    required this.shareSubject,
    required this.qrCardLabel,
    required this.qrCardSublabel,
  });

  // ── Group-quiz invite factory ──────────────────────────────────────────────
  static void showForGroup(
    BuildContext context, {
    required String groupId,
    required String groupName,
    required String scopeType,
    String scopeValue = '',
  }) {
    final qrData = ShareService.buildGroupQrData(
      groupId: groupId,
      groupName: groupName,
    );
    final shareText = ShareService.buildGroupInviteContent(
      groupId: groupId,
      groupName: groupName,
      scopeType: scopeType,
      scopeValue: scopeValue,
    );
    final scopeLabel = _scopeLabel(scopeType, scopeValue);

    _show(
      context,
      qrData: qrData,
      title: 'Invite Friends to Quiz 🎯',
      subtitle: groupName,
      shareText: shareText,
      shareSubject: 'Join my $scopeLabel Quiz on MindPilot!',
      qrCardLabel: groupName,
      qrCardSublabel: scopeLabel,
    );
  }

  // ── App referral / download invite factory ─────────────────────────────────
  static void showForReferral(
    BuildContext context, {
    required String referralCode,
    required String downloadUrl,
  }) {
    final shareText =
        'Join me on MindPilot — the AI clarity assistant for focus, decisions, and '
        'growth! 🧠\n\nUse my code: $referralCode for a bonus decision credit.\n\n'
        'Download: $downloadUrl';

    _show(
      context,
      qrData: downloadUrl,
      title: 'Invite Friends to MindPilot 🚀',
      subtitle: 'Your referral code: $referralCode',
      shareText: shareText,
      shareSubject: 'Join MindPilot with my referral code!',
      qrCardLabel: 'MindPilot',
      qrCardSublabel: 'Code: $referralCode',
    );
  }

  static void _show(
    BuildContext context, {
    required String qrData,
    required String title,
    required String subtitle,
    required String shareText,
    required String shareSubject,
    required String qrCardLabel,
    required String qrCardSublabel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87,
      builder: (_) => AppShareSheet._(
        qrData: qrData,
        title: title,
        subtitle: subtitle,
        shareText: shareText,
        shareSubject: shareSubject,
        qrCardLabel: qrCardLabel,
        qrCardSublabel: qrCardSublabel,
      ),
    );
  }

  // ── Scope label helper (reused internally) ────────────────────────────────
  static String _scopeLabel(String scopeType, String scopeValue) {
    switch (scopeType) {
      case 'general':
        return 'General Bible Knowledge';
      case 'chapter':
        return scopeValue.isNotEmpty
            ? 'Bible Chapter · $scopeValue'
            : 'Bible Chapter Study';
      case 'tech':
        return 'Technology & Coding';
      case 'science':
        return 'Science & Physics';
      case 'english':
        return 'English & Literature';
      case 'economics':
        return 'Economics & Finance';
      case 'mindfulness':
        return 'Personality & Mindfulness';
      case 'custom':
        return scopeValue.isNotEmpty ? scopeValue : 'Custom Topic';
      default:
        return 'Quiz';
    }
  }

  @override
  State<AppShareSheet> createState() => _AppShareSheetState();
}

// ─────────────────────────────────────────────────────────────────────────────

class _AppShareSheetState extends State<AppShareSheet>
    with SingleTickerProviderStateMixin {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharingQr = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  static const _accent = Color(0xFFCCFF00); // MindPilot lime

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Share QR as image ─────────────────────────────────────────────────────
  Future<void> _shareQrImage() async {
    setState(() => _isSharingQr = true);
    try {
      final bytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 120),
      );
      if (bytes == null) throw Exception('Screen capture returned null');

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/mp_invite_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: widget.shareText,
        subject: widget.shareSubject,
      );
    } catch (e) {
      if (mounted) {
        context.showInAppNotification(
          'Could not share QR code: $e',
          type: InAppNotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingQr = false);
    }
  }

  // ── Share as text/link ────────────────────────────────────────────────────
  Future<void> _shareText() async {
    Navigator.of(context).pop();
    await ShareService.shareText(
      widget.shareText,
      subject: widget.shareSubject,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: theme.brandDark.withOpacity(0.96),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(
                  color: _accent.withOpacity(0.18),
                  width: 1.5,
                ),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    // ── Drag handle ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Header row ──────────────────────────────
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _accent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _accent.withOpacity(0.3),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.qr_code_2_rounded,
                                  color: _accent,
                                  size: 26,
                                ),
                              ),
                              14.horizontalSpace,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    PrimaryText(
                                      text: widget.title,
                                      color: theme.accentTxt,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    4.verticalSpace,
                                    SecondaryText(
                                      text: widget.subtitle,
                                      color: _accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white38,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),

                          20.verticalSpace,

                          // ── QR Card (captured by Screenshot) ─────────
                          ScaleTransition(
                            scale: _scaleAnim,
                            child: Screenshot(
                              controller: _screenshotController,
                              child: _QrCard(
                                qrData: widget.qrData,
                                cardLabel: widget.qrCardLabel,
                                cardSublabel: widget.qrCardSublabel,
                              ),
                            ),
                          ),

                          20.verticalSpace,

                          // ── How-to steps ─────────────────────────────
                          _HowToCard(),

                          20.verticalSpace,

                          // ── Share options ─────────────────────────────
                          _SectionLabel(
                            text: 'Choose how to share',
                            theme: theme,
                          ),
                          12.verticalSpace,

                          // Option 1: QR image
                          _ShareOptionTile(
                            icon: Icons.qr_code_rounded,
                            iconColor: _accent,
                            title: 'Share as QR Image',
                            subtitle:
                                'Scan with any camera — no link needed. Great for WhatsApp & Instagram.',
                            isLoading: _isSharingQr,
                            onTap: _shareQrImage,
                            theme: theme,
                            highlighted: true,
                          ),
                          10.verticalSpace,

                          // Option 2: Text / link
                          _ShareOptionTile(
                            icon: Icons.link_rounded,
                            iconColor: Colors.white54,
                            title: 'Share as Link / Text',
                            subtitle:
                                'Send the full invite message with download link.',
                            isLoading: false,
                            onTap: _shareText,
                            theme: theme,
                            highlighted: false,
                          ),

                          32.verticalSpace,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR card widget (also the screenshot target)
// ─────────────────────────────────────────────────────────────────────────────

class _QrCard extends StatelessWidget {
  final String qrData;
  final String cardLabel;
  final String cardSublabel;

  static const _accent = Color(0xFFCCFF00);
  static const _darkBg = Color(0xFF0D1117);
  static const _cardBg = Color(0xFF1A1F2E);

  const _QrCard({
    required this.qrData,
    required this.cardLabel,
    required this.cardSublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cardBg, _darkBg],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accent.withOpacity(0.22), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.07),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App branding
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, color: _accent, size: 15),
              8.horizontalSpace,
              const PrimaryText(
                text: 'MindPilot',
                color: _accent,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
              8.horizontalSpace,
              const Icon(Icons.auto_awesome, color: _accent, size: 15),
            ],
          ),
          14.verticalSpace,

          // QR code in white container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.18),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 190,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: _darkBg,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: _darkBg,
              ),
            ),
          ),

          16.verticalSpace,

          // Label pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                PrimaryText(
                  text: cardLabel,
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  textAlign: TextAlign.center,
                ),
                4.verticalSpace,
                SecondaryText(
                  text: cardSublabel,
                  color: _accent.withOpacity(0.8),
                  fontSize: 11,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          12.verticalSpace,

          // Scan hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.camera_alt_outlined, color: Colors.white30, size: 13),
              SizedBox(width: 5),
              SecondaryText(
                text: 'Point your camera here to join',
                color: Colors.white30,
                fontSize: 11,
              ),
            ],
          ),
          6.verticalSpace,
          SecondaryText(
            text: 'Download MindPilot free 🚀',
            color: Colors.white.withOpacity(0.2),
            fontSize: 10,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// How-to steps card
// ─────────────────────────────────────────────────────────────────────────────

class _HowToCard extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Step(
            icon: Icons.looks_one_rounded,
            text: 'Share the QR image — your friend scans it with their camera',
          ),
          10.verticalSpace,
          _Step(
            icon: Icons.looks_two_rounded,
            text: 'They download MindPilot, open the app, and are taken straight in',
          ),
          10.verticalSpace,
          _Step(
            icon: Icons.looks_3_rounded,
            text: 'No mysterious links, no copy-pasting — just a simple scan',
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String text;
  static const _accent = Color(0xFFCCFF00);

  const _Step({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _accent, size: 18),
        8.horizontalSpace,
        Expanded(
          child: SecondaryText(text: text, color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable share option tile
// ─────────────────────────────────────────────────────────────────────────────

class _ShareOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;
  final AppTheme theme;
  final bool highlighted;

  const _ShareOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
    required this.theme,
    required this.highlighted,
  });

  static const _accent = Color(0xFFCCFF00);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: highlighted
              ? _accent.withOpacity(0.07)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted
                ? _accent.withOpacity(0.35)
                : Colors.white.withOpacity(0.1),
            width: highlighted ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: iconColor,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 20),
            ),
            14.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PrimaryText(
                    text: title,
                    color: highlighted ? _accent : theme.accentTxt,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  4.verticalSpace,
                  SecondaryText(
                    text: subtitle,
                    color: theme.accentTxt.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: highlighted ? _accent.withOpacity(0.6) : Colors.white.withOpacity(0.2),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label helper
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppTheme theme;
  const _SectionLabel({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SecondaryText(
      text: text.toUpperCase(),
      color: theme.accentTxt.withOpacity(0.4),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
    );
  }
}
