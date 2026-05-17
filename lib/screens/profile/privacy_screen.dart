import 'package:mindpilot/export.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'Privacy & Security',
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
                _section(theme, 'Data Security', 'Your data is encrypted and stored securely in our private cloud. We use industry-standard encryption protocols to ensure that your personal journals, tasks, and decision analyses remain private to you.'),
                24.verticalSpace,
                _section(theme, 'AI Privacy', 'When you interact with our AI, your data is processed anonymously. We do not use your personal entries to train public AI models. Your thoughts are yours alone.'),
                24.verticalSpace,
                _section(theme, 'Account Protection', 'We recommend using strong authentication methods. Your account is tied to your Google identity, providing a high level of security out of the box.'),
                24.verticalSpace,
                _section(theme, 'Your Rights', 'You have the right to access, export, or delete your data at any time. We believe in complete transparency regarding how your information is used to provide you with mental clarity.'),
                40.verticalSpace,
                Center(
                  child: SecondaryText(
                    text: 'Last Updated: May 2026',
                    fontSize: 12,
                    color: theme.accentTxt.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _section(AppTheme theme, String title, String content) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrimaryText(
            text: title,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.accentTxt,
          ),
          12.verticalSpace,
          SecondaryText(
            text: content,
            fontSize: 14,
            height: 1.6,
            color: theme.accentTxt.withOpacity(0.8),
          ),
        ],
      ),
    );
  }
}
