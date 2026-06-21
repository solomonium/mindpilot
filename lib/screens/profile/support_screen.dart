import 'package:mindpilot/export.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _showExitDialog(
    BuildContext context,
    String appName,
    VoidCallback onConfirm,
  ) async {
    AppTheme theme = context.read();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.brandDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: PrimaryText(
          text: 'Leave MindPilot?',
          color: theme.accentTxt,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        content: SecondaryText(
          text:
              'You are about to be redirected to $appName to continue this action.',
          color: theme.accentTxt.withOpacity(0.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: SecondaryText(
              text: 'Cancel',
              color: theme.accentTxt.withOpacity(0.5),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: PrimaryText(
              text: 'Continue',
              color: theme.primaryBase,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    _showExitDialog(context, 'WhatsApp', () async {
      String rawPhone = ConfigService().supportPhone;
      // Remove all non-numeric characters
      String cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');

      // If it starts with 0 (e.g. 090...), replace with 234
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '234${cleanPhone.substring(1)}';
      } else if (!cleanPhone.startsWith('234') && cleanPhone.length <= 11) {
        // Fallback for Nigerian numbers without 234 or leading 0
        cleanPhone = '234$cleanPhone';
      }

      final message = Uri.encodeComponent(
        "Hello MindPilot Support, I need assistance with...",
      );
      final url = "https://wa.me/$cleanPhone?text=$message";

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          context.showInAppNotification(
            'Could not launch WhatsApp. Please contact ${ConfigService().supportPhone}.',
          );
        }
      }
    });
  }

  Future<void> _launchEmail(BuildContext context) async {
    _showExitDialog(context, 'your Email app', () async {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: 'solteqinnovationsltd@gmail.com',
        queryParameters: {'subject': 'MindPilot Support Request'},
      );

      try {
        if (await canLaunchUrl(emailLaunchUri)) {
          await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch email app';
        }
      } catch (e) {
        if (context.mounted) {
          context.showInAppNotification(
            'Could not open email app. Please contact solteqinnovationsltd@gmail.com',
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'Help & Support',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Icon(
            Icons.arrow_back_ios,
            color: theme.accentTxt,
            size: 20,
          ).rippleClick(() => context.pop()),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.6,
              child: Image.asset(R.png.loginBg.png, fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.brandDark.withOpacity(0.4),
                    theme.brandDark.withOpacity(0.8),
                    theme.brandDark,
                  ],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _supportOption(
                  theme,
                  Icons.rate_review_outlined,
                  'Share Feedback',
                  'Tell us what you love or what we can improve. Your thoughts shape the future of MindPilot.',
                  const Color(0xFF8B5CF6),
                  onTap: () => context.push(const FeedbackScreen()),
                ),
                20.verticalSpace,
                _supportOption(
                  theme,
                  Icons.chat_bubble,
                  'WhatsApp Support',
                  'Chat with our support team directly on WhatsApp for quick assistance.',
                  const Color(0xFF25D366),
                  onTap: () => _launchWhatsApp(context),
                ),
                20.verticalSpace,
                _supportOption(
                  theme,
                  Icons.email_outlined,
                  'Email Support',
                  'Send us an email at solteqinnovationsltd@gmail.com and we will get back to you within 24 hours.',
                  theme.primaryBase,
                  onTap: () => _launchEmail(context),
                ),
                20.verticalSpace,
                _supportOption(
                  theme,
                  Icons.question_answer_outlined,
                  'Frequently Asked Questions',
                  'Find quick answers to common questions about MindPilot features and billing.',
                  const Color(0xFFF59E0B),
                  onTap: () => context.push(const FAQScreen()),
                ),
                40.verticalSpace,
                Center(
                  child: Column(
                    children: [
                      PrimaryText(
                        text: 'App Version',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.accentTxt,
                      ),
                      8.verticalSpace,
                      SecondaryText(
                        text: 'MindPilot v${ConfigService().latestVersion}',
                        fontSize: 14,
                        color: theme.accentTxt.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportOption(
    AppTheme theme,
    IconData icon,
    String title,
    String description,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          20.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrimaryText(
                  text: title,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.accentTxt,
                ),
                8.verticalSpace,
                SecondaryText(
                  text: description,
                  fontSize: 13,
                  height: 1.4,
                  color: theme.accentTxt.withOpacity(0.7),
                ),
              ],
            ),
          ),
        ],
      ),
    ).rippleClick(onTap);
  }
}
