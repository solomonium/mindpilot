import 'package:mindpilot/export.dart';

class DecisionAnalyzerScreen extends StatefulWidget {
  const DecisionAnalyzerScreen({super.key});

  @override
  State<DecisionAnalyzerScreen> createState() => _DecisionAnalyzerScreenState();
}

class _DecisionAnalyzerScreenState extends State<DecisionAnalyzerScreen> {
  double importance = 0.5;
  int selectedEmoji = 1;
  final TextEditingController _controller = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  bool _isLoading = false;

  final emojis = ['😫', '😕', '😐', '😊', '🤩'];
  final emojiLabels = ['Stressed', 'Confused', 'Neutral', 'Calm', 'Excited'];

  @override
  void initState() {
    super.initState();
    _initializeGemini();
  }

  void _initializeGemini() async {
    final apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';

    final models = await _geminiService.listModels(apiKey);
    String selectedModel = 'gemini-1.5-flash';
    if (models.isNotEmpty) {
      selectedModel = models.first;
    }
    _geminiService.init(apiKey, modelName: selectedModel);
  }

  Future<void> _analyzeDecision() async {
    final text = _controller.text.trim();
    final isPro = context.read<AuthProvider>().isPro;

    if (text.isEmpty) {
      context.showInAppNotification('Please describe your situation first.');
      return;
    }

    if (!isPro) {
      AppHelper.showPaywall(context, feature: 'AI Decision Analysis');
      return;
    }

    setState(() => _isLoading = true);

    final intent = ChatProcessor.classifyIntent(text);
    final emotion = ChatProcessor.detectEmotion(text);
    final framework = ChatProcessor.generateFramework(intent);

    final prompt = ChatProcessor.buildDecisionAnalysisPrompt(
      userMessage: text,
      intent: intent,
      emotion: emotion,
      framework: framework,
      importance: importance,
      selectedFeeling: emojiLabels[selectedEmoji],
    );

    final response = await _geminiService.sendMessage(prompt);

    setState(() => _isLoading = false);

    if (mounted && response != null) {
      context.push(AnalysisResultScreen(analysis: response));
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: PrimaryText(
            text: 'Decision Analyzer',
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
            Icon(Icons.info_outline, color: theme.accentTxt),
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
                    text: 'What decision are you\nthinking about?',
                    color: theme.accentTxt,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  12.verticalSpace,
                  SecondaryText(
                    text:
                        'Describe your situation in detail. The AI will analyze and guide you.',
                    color: theme.accentTxt.withOpacity(0.7),
                  ),
                  24.verticalSpace,
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Column(
                      children: [
                        TextField(
                          controller: _controller,
                          maxLines: 5,
                          style: TextStyle(
                            color: theme.accentTxt,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'I am thinking about quitting my job and starting my own business. But I\'m afraid of financial instability.',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: theme.accentTxt.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  32.verticalSpace,
                  PrimaryText(
                    text: 'How important is this decision?',
                    color: theme.accentTxt,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  16.verticalSpace,
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: theme.primaryBase,
                      inactiveTrackColor: theme.accentTxt.withOpacity(0.1),
                      thumbColor: theme.accentTxt,
                      overlayColor: theme.primaryBase.withOpacity(0.1),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                        elevation: 5,
                      ),
                    ),
                    child: Slider(
                      value: importance,
                      onChanged: (v) => setState(() => importance = v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SecondaryText(
                        text: 'Low',
                        fontSize: 12,
                        color: theme.accentTxt.withOpacity(0.6),
                      ),
                      SecondaryText(
                        text: 'High',
                        fontSize: 12,
                        color: theme.accentTxt.withOpacity(0.6),
                      ),
                    ],
                  ),
                  32.verticalSpace,
                  PrimaryText(
                    text: 'How do you feel about this?',
                    color: theme.accentTxt,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  16.verticalSpace,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(emojis.length, (index) {
                      final isSelected = selectedEmoji == index;
                      return GestureDetector(
                        onTap: () => setState(() => selectedEmoji = index),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.accentTxt.withOpacity(0.2)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? theme.accentTxt
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                emojis[index],
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            4.verticalSpace,
                            SecondaryText(
                              text: emojiLabels[index],
                              fontSize: 10,
                              color: isSelected
                                  ? theme.accentTxt
                                  : theme.accentTxt.withOpacity(0.5),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  40.verticalSpace,
                  CustomButton(
                    label: 'Analyze My Decision',
                    onPressed: _analyzeDecision,
                    backgroundColor: theme.primaryBase,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
