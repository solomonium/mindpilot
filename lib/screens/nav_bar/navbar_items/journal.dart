import 'package:mindpilot/export.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
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
    final apiKey = 'AIzaSyCjYNWFh9g0XspukeBSRm86HpbyEoa4IhU';
    final models = await _geminiService.listModels(apiKey);
    String selectedModel = 'gemini-1.5-flash';
    if (models.isNotEmpty) {
      selectedModel = models.first;
    }
    _geminiService.init(apiKey, modelName: selectedModel);
  }

  Future<void> _analyzeDecision() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      context.showInAppNotification('Please describe your situation first.');
      return;
    }

    setState(() => _isLoading = true);

    final intent = ChatProcessor.classifyIntent(text);
    final emotion = ChatProcessor.detectEmotion(text);
    final framework = ChatProcessor.generateFramework(intent);
    final title = ChatProcessor.generateTitle(text, intent);

    final prompt = """
Topic: $title
${ChatProcessor.buildDecisionAnalysisPrompt(
      userMessage: text,
      intent: intent,
      emotion: emotion,
      framework: framework,
      importance: importance,
      selectedFeeling: emojiLabels[selectedEmoji],
    )}
""";

    // Logging for debugging
    safePrint("--- DECISION ANALYSIS START ---");
    safePrint("Title: $title");
    safePrint("Intent: $intent");
    safePrint("Emotion: $emotion");
    safePrint("Importance: $importance");
    safePrint("Final Prompt: $prompt");
    safePrint("--- DECISION ANALYSIS END ---");

    final response = await _geminiService.sendMessage(prompt);

    setState(() => _isLoading = false);

    if (mounted && response != null) {
      context.push(AnalysisResultScreen(
        analysis: response,
        title: title,
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
            text: 'Decision Analyzer',
            color: theme.accentTxt,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          actions: [
            Icon(Icons.info_outline, color: theme.accentTxt),
            20.horizontalSpace,
          ],
        ),
        body: SingleChildScrollView(
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
                text: 'Describe your situation in detail. The AI will analyze and guide you.',
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
                text: 'How important is this decision?',
                color: theme.accentTxt,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              16.verticalSpace,
              Slider(
                value: importance,
                onChanged: (v) => setState(() => importance = v),
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
                        Text(emojis[index], style: const TextStyle(fontSize: 24)),
                        4.verticalSpace,
                        SecondaryText(
                          text: emojiLabels[index],
                          fontSize: 10,
                          color: isSelected ? theme.accentTxt : theme.accentTxt.withOpacity(0.5),
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
      ),
    );
  }
}
