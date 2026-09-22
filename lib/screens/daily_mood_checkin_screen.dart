import 'package:mindpilot/export.dart';

class DailyMoodCheckInScreen extends StatefulWidget {
  final int? initialSelectedEmoji;
  const DailyMoodCheckInScreen({super.key, this.initialSelectedEmoji});

  @override
  State<DailyMoodCheckInScreen> createState() => _DailyMoodCheckInScreenState();
}

class _DailyMoodCheckInScreenState extends State<DailyMoodCheckInScreen> {
  late int _selectedEmoji;
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
    _selectedEmoji = widget.initialSelectedEmoji ?? 3;
  }

  Future<void> _submitCheckIn() async {
    setState(() => _isLoading = true);

    final moodLabel = emojiLabels[_selectedEmoji];
    final moodEmoji = emojis[_selectedEmoji];
    
    try {
      // Save to journal entries
      await context.read<JournalProvider>().addEntry(
        text: "Checked in feeling $moodEmoji $moodLabel today.",
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
        } else {
          Navigator.pop(context);
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
      barrierDismissible: false,
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
              onPressed: () {
                Navigator.pop(dialogContext);
                if (mounted) Navigator.pop(context);
              },
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
                if (mounted) {
                  context.replace(AiChatScreen(proactiveMood: mood));
                }
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
                      text: "Select your current emotional state to log your check-in in your journal.",
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
                            setState(() => _selectedEmoji = index);
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

                    CustomButton(
                      label: 'Check In',
                      onPressed: _submitCheckIn,
                    ),
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
