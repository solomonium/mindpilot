import 'package:mindpilot/export.dart';

class DailyMoodCheckInScreen extends StatefulWidget {
  const DailyMoodCheckInScreen({super.key});

  @override
  State<DailyMoodCheckInScreen> createState() => _DailyMoodCheckInScreenState();
}

class _DailyMoodCheckInScreenState extends State<DailyMoodCheckInScreen> {
  int _selectedEmoji = 3; // Neutral default
  bool _isLoading = false;
  String? _aiTip;
  final GeminiService _geminiService = GeminiService();

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
    _geminiService.init(apiKey);
  }

  Future<void> _submitCheckIn() async {
    setState(() => _isLoading = true);

    final moodLabel = emojiLabels[_selectedEmoji];
    final moodEmoji = emojis[_selectedEmoji];
    final auth = context.read<AppAuthProvider>();
    
    // Customize prompt with user name and personalization goals if available
    String userGreeting = auth.user?.displayName != null ? "addressed to ${auth.user!.displayName}" : "";
    final prompt = """
You are the **MindPilot Clarity Coach**. The user has just checked in and logged their mood today as "$moodEmoji $moodLabel".
Please provide a short, highly encouraging, and actionable daily clarity micro-tip or mindfulness recommendation $userGreeting (max 3 sentences).
Keep the tone supportive, premium, and clean. Make it directly actionable today. Avoid any prefix, just write the tip directly.
""";

    try {
      final response = await _geminiService.sendMessage(prompt);

      if (response != null && response.isNotEmpty) {
        setState(() {
          _aiTip = response;
        });

        // Save to journal entries
        await context.read<JournalProvider>().addEntry(
          text: response,
          title: 'Daily Check-in ($moodEmoji $moodLabel)',
          mood: '$moodEmoji $moodLabel',
        );

        if (mounted) {
          context.showInAppNotification(
            'Mood checked in! Reflection saved to your journal.',
            type: InAppNotificationType.success,
          );

          final isDownMood = _selectedEmoji >= 0 && _selectedEmoji <= 2;
          if (isDownMood) {
            _showProactiveChatPrompt(moodLabel);
          }
        }
      } else {
        if (mounted) {
          context.showInAppNotification('Failed to generate tip. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showInAppNotification('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showProactiveChatPrompt(String mood) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = context.read<AppTheme>();
        return AlertDialog(
          backgroundColor: theme.brandDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: PrimaryText(
            text: 'MindPilot Support ❤️',
            color: theme.accentTxt,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          content: SecondaryText(
            text: 'We notice you are feeling $mood today. Would you like to chat with your MindPilot Assistant for comforting scriptures, focus tasks, and guided reflection questions?',
            color: theme.accentTxt.withOpacity(0.8),
            fontSize: 13,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: SecondaryText(
                text: 'Not Now',
                color: theme.accentTxt.withOpacity(0.6),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryBase,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                context.push(AiChatScreen(proactiveMood: mood));
              },
              child: const PrimaryText(
                text: 'Talk to Assistant',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final auth = context.watch<AppAuthProvider>();

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: PrimaryText(
            text: 'Daily Check-In',
            color: theme.accentTxt,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(
              Icons.arrow_back_ios,
              color: theme.accentTxt,
              size: 20,
            ),
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
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryText(
                      text: "How are you feeling today?",
                      color: theme.accentTxt,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    12.verticalSpace,
                    SecondaryText(
                      text: "Select your current emotional state to log your check-in and get a custom AI mindfulness tip.",
                      color: theme.accentTxt.withOpacity(0.7),
                    ),
                    32.verticalSpace,
                    
                    // Mood Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: emojis.length,
                      itemBuilder: (context, index) {
                        final isSelected = _selectedEmoji == index;
                        return GestureDetector(
                          onTap: () {
                            if (_aiTip == null) {
                              setState(() => _selectedEmoji = index);
                            }
                          },
                          child: GlassContainer(
                            padding: const EdgeInsets.all(12),
                            gradient: isSelected ? theme.glassGradient : null,
                            border: Border.all(
                              color: isSelected ? theme.primaryBase : Colors.white12,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  emojis[index],
                                  style: const TextStyle(fontSize: 32),
                                ),
                                8.verticalSpace,
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SecondaryText(
                                    text: emojiLabels[index],
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? theme.accentTxt : theme.accentTxt.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    
                    32.verticalSpace,

                    if (_aiTip == null) ...[
                      CustomButton(
                        label: 'Check In & Get Tip',
                        onPressed: _submitCheckIn,
                      ),
                    ] else ...[
                      PrimaryText(
                        text: "Daily Clarity Insight",
                        color: theme.accentTxt,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      16.verticalSpace,
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        gradient: theme.glassGradient,
                        child: SelectionArea(
                          child: MarkdownBody(
                            data: _aiTip!,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                color: theme.accentTxt,
                                fontSize: 15,
                                height: 1.6,
                              ),
                              strong: TextStyle(
                                color: theme.accentTxt,
                                fontWeight: FontWeight.bold,
                              ),
                              em: TextStyle(
                                color: theme.accentTxt,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ),
                      24.verticalSpace,
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              label: 'Share Insight Card',
                              onPressed: () {
                                final moodLabel = emojiLabels[_selectedEmoji];
                                final moodEmoji = emojis[_selectedEmoji];
                                final downloadUrl = ConfigService().updateUrl;
                                ShareService.captureAndShare(
                                  context,
                                  text: "My daily check-in mood is $moodEmoji $moodLabel! 🧠 Logging daily reflection with MindPilot. Get the app here:\n$downloadUrl",
                                  widget: ShareableCard(
                                    mode: ShareableCardMode.insight,
                                    insightTitle: 'Daily Mood: $moodEmoji $moodLabel',
                                    insightContent: _aiTip!,
                                    userName: auth.user?.displayName,
                                  ),
                                );
                              },
                              isGlass: true,
                            ),
                          ),
                          12.horizontalSpace,
                          Expanded(
                            child: CustomButton(
                              label: 'Done',
                              onPressed: () => context.pop(),
                            ),
                          ),
                        ],
                      ),
                    ],
                    120.verticalSpace,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
