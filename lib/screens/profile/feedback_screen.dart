import 'package:mindpilot/export.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;

  Future<void> _submitFeedback() async {
    final message = _feedbackController.text.trim();
    if (message.isEmpty) {
      context.showInAppNotification('Please enter your feedback message.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = context.read<AppAuthProvider>().user;
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user?.uid,
        'userEmail': user?.email,
        'userName': user?.displayName,
        'message': message,
        'rating': _rating,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        context.showInAppNotification(
          'Thank you for your feedback!',
          type: InAppNotificationType.success,
        );
        final url = ConfigService().updateUrl;
        AppHelper.launchURL(url);
        context.pop();
      }
    } catch (e) {
      if (mounted) context.showInAppNotification('Error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
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
          text: 'App Feedback',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.arrow_back_ios, color: theme.accentTxt),
        ).rippleClick(() => context.pop()),
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
                PrimaryText(
                  text: 'How are we doing?',
                  color: theme.accentTxt,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                12.verticalSpace,
                SecondaryText(
                  text:
                      'Please tell us about your experience with MindPilot so far, and share any ideas or thoughts on how we can improve to meet your needs!',
                  color: theme.accentTxt.withOpacity(0.7),
                  fontSize: 14,
                ),
                32.verticalSpace,
                PrimaryText(
                  text: 'Rate your experience',
                  color: theme.accentTxt,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                16.verticalSpace,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final isSelected = index < _rating;
                    return IconButton(
                      onPressed: () => setState(() => _rating = index + 1),
                      icon: Icon(
                        isSelected
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: isSelected
                            ? const Color(0xFFF59E0B)
                            : theme.accentTxt.withOpacity(0.3),
                        size: 40,
                      ),
                    );
                  }),
                ),
                32.verticalSpace,
                PrimaryText(
                  text: 'Share your thoughts & ideas',
                  color: theme.accentTxt,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                16.verticalSpace,
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  gradient: theme.glassGradient,
                  child: TextField(
                    controller: _feedbackController,
                    maxLines: 6,
                    style: GoogleFonts.inter(color: theme.accentTxt),
                    decoration: InputDecoration(
                      hintText:
                          'Describe your experience and any suggestions...',
                      hintStyle: TextStyle(
                        color: theme.accentTxt.withOpacity(0.3),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                40.verticalSpace,
                CustomButton(
                  label: 'Submit Feedback',
                  loading: _isSubmitting,
                  onPressed: _submitFeedback,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
