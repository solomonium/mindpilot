import 'package:mindpilot/export.dart';

class AnalysisResultScreen extends StatefulWidget {
  final String analysis;
  final String? title;
  const AnalysisResultScreen({super.key, required this.analysis, this.title});

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  late String _currentAnalysis;
  bool _isContinuing = false;

  @override
  void initState() {
    super.initState();
    _currentAnalysis = widget.analysis;
  }

  Future<void> _continueAnalysis() async {
    setState(() => _isContinuing = true);
    try {
      final response = await GeminiService().sendMessage("Please continue the previous analysis since it was not complete. Provide the remaining parts.");
      if (response != null) {
        setState(() {
          _currentAnalysis = "$_currentAnalysis\n\n$response";
        });
      }
    } catch (e) {
      safePrint("Continue Error: $e");
      context.showInAppNotification("Failed to fetch more analysis. Please try again.");
    } finally {
      setState(() => _isContinuing = false);
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
          text: 'Analysis Result',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Icon(
          Icons.chevron_left,
          color: theme.accentTxt,
        ).rippleClick(() => context.pop()),
        actions: [
          Icon(Icons.ios_share, color: theme.accentTxt),
          20.horizontalSpace,
        ],
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
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: theme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryBase.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SecondaryText(
                                text: 'Overall Recommendation',
                                color: theme.accentTxt.withOpacity(0.7),
                                fontSize: 12,
                              ),
                              8.verticalSpace,
                              PrimaryText(
                                text: widget.title ?? 'MindPilot Analysis',
                                color: theme.accentTxt,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              12.verticalSpace,
                              SecondaryText(
                                text:
                                    'Based on your input, here is the structured clarity you need.',
                                color: theme.accentTxt.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ],
                          ),
                        ),
                        16.horizontalSpace,
                        Icon(
                          Icons.track_changes,
                          color: theme.accentTxt,
                          size: 40,
                        ),
                      ],
                    ),
                  ),
                  32.verticalSpace,
                  PrimaryText(
                    text: 'Analysis Breakdown',
                    color: theme.accentTxt,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  20.verticalSpace,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.accentTxt.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
                    ),
                    child: MarkdownBody(
                      data: _currentAnalysis,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: theme.accentTxt,
                          fontSize: 16,
                          height: 1.6,
                        ),
                        strong: TextStyle(
                          color: theme.accentTxt,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        h1: TextStyle(
                          color: theme.accentTxt,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: TextStyle(
                          color: theme.accentTxt,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: TextStyle(
                          color: theme.accentTxt,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        listBullet: TextStyle(color: theme.accentTxt, fontSize: 16),
                      ),
                    ),
                  ),
                  if (_isContinuing) ...[
                    20.verticalSpace,
                    const Center(child: CircularProgressIndicator()),
                  ],
                  40.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          label: 'Continue',
                          loading: _isContinuing,
                          onPressed: _isContinuing ? null : _continueAnalysis,
                          backgroundColor: theme.accentTxt.withOpacity(0.1),
                          textColor: theme.accentTxt,
                        ),
                      ),
                      16.horizontalSpace,
                      Expanded(
                        child: CustomButton(
                          label: 'Done',
                          onPressed: () async {
                            try {
                              await context.read<JournalProvider>().addEntry(
                                text: _currentAnalysis,
                                mood: "Analyzed 🧠",
                                title: widget.title,
                              );
                              context.showInAppNotification(
                                'Decision saved to Journal!',
                                type: InAppNotificationType.success,
                              );
                              context.pop();
                              context.pop(); // Go back to Home/Journal tab
                            } catch (e) {
                              safePrint("Save Error: $e");
                              context.showInAppNotification(
                                'Failed to save decision. Please try again.',
                              );
                            }
                          },
                          backgroundColor: theme.primaryBase,
                        ),
                      ),
                    ],
                  ),
                  20.verticalSpace,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
