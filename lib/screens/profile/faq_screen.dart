import 'package:mindpilot/export.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'FAQs',
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
                _faqItem(theme, 'What is MindPilot?', 'MindPilot is an AI-powered mental clarity and productivity app designed to help you organize your thoughts, make better decisions, and stay focused on your goals.'),
                16.verticalSpace,
                _faqItem(theme, 'How does the Decision Analyzer work?', 'The Decision Analyzer uses advanced AI to evaluate your situation based on framework analysis. It helps you see pros, cons, and psychological factors you might have missed.'),
                16.verticalSpace,
                _faqItem(theme, 'What is a Focus Session?', 'Focus Sessions use time-blocking techniques to help you dedicate uninterrupted time to your most important tasks, improving your consistency and output.'),
                16.verticalSpace,
                _faqItem(theme, 'Is my data private?', 'Yes. We take privacy seriously. Your personal journals and decision analyses are encrypted and stored securely. We do not sell your personal data.'),
                16.verticalSpace,
                _faqItem(theme, 'How do I upgrade to Pro?', 'You can upgrade by visiting the "Upgrade to Pro" section in the app. Currently, we offer manual activation via WhatsApp for premium access.'),
                16.verticalSpace,
                _faqItem(theme, 'What happens if I forget my password?', 'You can reset your password using the "Forgot Password" link on the login screen, which will send a reset link to your registered email.'),
                40.verticalSpace,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqItem(AppTheme theme, String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.accentTxt.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          colorScheme: ColorScheme.fromSeed(
            seedColor: theme.primaryBase,
            brightness: Brightness.dark,
          ),
        ),
        child: ExpansionTile(
          iconColor: theme.primaryBase,
          collapsedIconColor: theme.accentTxt.withOpacity(0.5),
          title: PrimaryText(
            text: question,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: theme.accentTxt,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SecondaryText(
                text: answer,
                fontSize: 14,
                height: 1.5,
                color: theme.accentTxt.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
