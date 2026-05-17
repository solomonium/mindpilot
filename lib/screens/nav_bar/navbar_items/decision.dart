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

  final emojis = ['😫', '😤', '😕', '😐', '😊', '🤩'];
  final emojiLabels = [
    'Stressed',
    'Frustrated',
    'Confused',
    'Neutral',
    'Calm',
    'Excited',
  ];

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
    final auth = context.read<AppAuthProvider>();
    final isPro = auth.isPro;

    if (text.isEmpty) {
      context.showInAppNotification('Please describe your situation first.');
      return;
    }

    if (!isPro) {
      if (auth.decisionCredits <= 0) {
        AppHelper.showPaywall(context, feature: 'AI Decision Analysis');
        return;
      }
    }

    setState(() => _isLoading = true);

    final intent = ChatProcessor.classifyIntent(text);
    final emotion = ChatProcessor.detectEmotion(text);
    final framework = ChatProcessor.generateFramework(intent);
    final title = ChatProcessor.generateTitle(text, intent);

    final prompt = ChatProcessor.buildDecisionAnalysisPrompt(
      userMessage: text,
      intent: intent,
      emotion: emotion,
      framework: framework,
      importance: importance,
      selectedFeeling: emojiLabels[selectedEmoji],
    );

    final response = await _geminiService.sendMessage(prompt);
    
    if (response != null) {
      await auth.useDecisionCredit();
    }

    setState(() => _isLoading = false);

    if (mounted && response != null) {
      context.push(AnalysisResultScreen(
        analysis: response,
        title: title,
        situation: text,
        mood: emojiLabels[selectedEmoji],
        framework: framework,
      ));
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
            text: R.S.decisionAnalyzer,
            color: theme.accentTxt,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(
              Icons.chevron_left,
              color: theme.accentTxt,
            ),
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
                    text: R.S.decisionQuestion,
                    color: theme.accentTxt,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  12.verticalSpace,
                  SecondaryText(
                    text: R.S.decisionDesc,
                    color: theme.accentTxt.withOpacity(0.7),
                  ),
                  if (!context.watch<AppAuthProvider>().isPro) ...[
                    8.verticalSpace,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.primaryBase.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SecondaryText(
                        text: 'Free Daily Credits: ${context.watch<AppAuthProvider>().decisionCredits}/3',
                        color: theme.primaryBase,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  24.verticalSpace,
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    gradient: theme.glassGradient,
                    child: TextField(
                      controller: _controller,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: theme.accentTxt, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'I am thinking about quitting my job...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: theme.accentTxt.withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  32.verticalSpace,
                  PrimaryText(
                    text: R.S.importanceTitle,
                    color: theme.accentTxt,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  16.verticalSpace,
                  Slider(
                    value: importance,
                    onChanged: (v) => setState(() => importance = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SecondaryText(
                          text: R.S.low,
                          color: theme.accentTxt,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        SecondaryText(
                          text: R.S.high,
                          color: theme.accentTxt,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ],
                    ),
                  ),
                  32.verticalSpace,
                  PrimaryText(
                    text: R.S.feelingTitle,
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
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? theme.primaryBase
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                                color: isSelected
                                    ? theme.primaryBase.withOpacity(0.1)
                                    : Colors.transparent,
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
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  40.verticalSpace,
                  CustomButton(
                    label: R.S.analyzeDecision,
                    onPressed: _analyzeDecision,
                    isGlass: true,
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
