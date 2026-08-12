import 'package:mindpilot/export.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AnalysisResultScreen extends StatefulWidget {
  final String analysis;
  final String? title;
  final String? situation;
  final String? mood;
  final String? framework;

  const AnalysisResultScreen({
    super.key,
    required this.analysis,
    this.title,
    this.situation,
    this.mood,
    this.framework,
  });

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  Color? _selectedTextColor;
  late String _currentAnalysis;
  bool _isContinuing = false;
  final GeminiService _geminiService = GeminiService();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlayingTts = false;

  @override
  void initState() {
    super.initState();
    _currentAnalysis = widget.analysis;
    _initializeGemini();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  void _toggleTts() async {
    if (_isPlayingTts) {
      await _flutterTts.stop();
      setState(() => _isPlayingTts = false);
    } else {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _isPlayingTts = false);
        }
      });

      setState(() => _isPlayingTts = true);
      final cleanText = _currentAnalysis.replaceAll(RegExp(r'[*#_`]'), '');
      await _flutterTts.speak(cleanText);
    }
  }

  void _initializeGemini() async {
    final apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
    _geminiService.init(apiKey);
  }

  Future<void> _continueAnalysis() async {
    setState(() => _isContinuing = true);

    final prompt =
        """
The previous analysis was cut off. Please continue from where you stopped. 
Context: ${widget.situation}
Current incomplete analysis: $_currentAnalysis

Continue the analysis naturally.
""";

    try {
      final response = await _geminiService.sendMessageOneShot(
        prompt,
        feature: 'decision_continuation',
        maxTokens: 1200,
      );
      if (response != null) {
        setState(() {
          _currentAnalysis += "\n\n$response";
        });
      }
    } catch (e) {
      if (mounted) {
        context.showInAppNotification("Error continuing analysis: $e");
      }
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }

  Future<void> _saveToJournal() async {
    try {
      await context.read<JournalProvider>().addEntry(
        text: _currentAnalysis,
        title: widget.title ?? "Decision Analysis",
        mood: widget.mood,
      );
      if (mounted) {
        context.showInAppNotification(
          'Decision analysis saved to your journal!',
          type: InAppNotificationType.success,
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) context.showInAppNotification("Failed to save: $e");
    }
  }

  Widget _colorPickerItem(
    BuildContext context,
    Color color, {
    bool isReset = false,
  }) {
    AppTheme theme = context.watch();
    final isPro = context.read<AppAuthProvider>().isPro;
    return GestureDetector(
      onTap: () {
        if (!isPro) {
          AppHelper.showPaywall(context, feature: 'Personalization');
          return;
        }
        setState(() {
          _selectedTextColor = isReset ? null : color;
        });
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                _selectedTextColor == color ||
                    (isReset && _selectedTextColor == null)
                ? Colors.white
                : Colors.white24,
            width: 2,
          ),
          boxShadow: [
            if (_selectedTextColor == color ||
                (isReset && _selectedTextColor == null))
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: isReset
            ? Icon(Icons.refresh, size: 14, color: theme.brandDark)
            : null,
      ),
    );
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
          text: widget.title ?? R.S.analysisResult,
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.chevron_left, color: theme.accentTxt),
        ).rippleClick(() => context.pop()),
        actions: [
          IconButton(
            icon: Icon(
              _isPlayingTts ? Icons.volume_up : Icons.volume_mute,
              color: _isPlayingTts ? theme.primaryBase : theme.accentTxt,
            ),
            onPressed: _toggleTts,
          ),
          12.horizontalSpace,
          Icon(Icons.share_outlined, color: theme.accentTxt).rippleClick(() {
            final user = context.read<AppAuthProvider>().user;
            final downloadUrl = ConfigService().updateUrl;
            ShareService.captureAndShare(
              context,
              text:
                  "Making tough choices with clarity! 🧠 Just analyzed a major decision with MindPilot and the path forward is clear. Stop overthinking and start acting.\n\nDownload MindPilot: $downloadUrl\n#MindPilot #Decisions #Clarity",
              widget: ShareableCard(
                mode: ShareableCardMode.insight,
                insightTitle: widget.title ?? 'Decision Analysis',
                insightContent: widget.analysis,
                userName: user?.displayName,
              ),
            );
          }),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrimaryText(
                  text: R.S.analysisBreakdown,
                  color: theme.accentTxt,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                12.verticalSpace,
                SecondaryText(
                  text: R.S.breakdownDesc,
                  color: theme.accentTxt.withOpacity(0.7),
                ),
                24.verticalSpace,
                Row(
                  children: [
                    SecondaryText(
                      text: '${R.S.textColor}:',
                      color: theme.accentTxt.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    16.horizontalSpace,
                    _colorPickerItem(
                      context,
                      const Color(0xFFC0FF00),
                    ), // Lemon Green
                    12.horizontalSpace,
                    _colorPickerItem(
                      context,
                      const Color(0xFFFF914D),
                    ), // Orange
                    12.horizontalSpace,
                    _colorPickerItem(
                      context,
                      theme.accentTxt,
                      isReset: true,
                    ), // Reset
                  ],
                ),
                16.verticalSpace,
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  gradient: theme.glassGradient,
                  child: SelectionArea(
                    child: MarkdownBody(
                      data: _currentAnalysis,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontSize: 15,
                          height: 1.6,
                        ),
                        strong: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontWeight: FontWeight.bold,
                        ),
                        h1: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        listBullet: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                        ),
                        tableBody: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontSize: 14,
                        ),
                        tableHead: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontWeight: FontWeight.bold,
                        ),
                        blockquote: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                        ),
                        code: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ),
                40.verticalSpace,
                if (_isContinuing)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          label: 'Continue',
                          onPressed: _continueAnalysis,
                          isGlass: true,
                          backgroundColor: theme.accentTxt.withOpacity(0.1),
                        ),
                      ),
                      12.horizontalSpace,
                      Expanded(
                        child: CustomButton(
                          label: R.S.done,
                          onPressed: _saveToJournal,
                          isGlass: true,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
