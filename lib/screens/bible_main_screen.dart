import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:mindpilot/export.dart';

class BibleMainScreen extends StatefulWidget {
  const BibleMainScreen({super.key});

  @override
  State<BibleMainScreen> createState() => _BibleMainScreenState();
}

class _BibleMainScreenState extends State<BibleMainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GeminiService _geminiService = GeminiService();

  // Reading tab state
  String _selectedBook = 'John';
  int _selectedChapter = 3;
  bool _isLoadingChapter = false;
  List<Map<String, dynamic>> _verses = [];
  String? _selectedText;
  String? _chapterText;
  String? _aiExplanation;
  bool _isExplaining = false;
  Color? _customExplanationColor;
  String _bibleFontSizeCategory = 'medium';
  Color? _customBibleColor;

  // Quiz tab state
  int _questionCount = 5;
  String _quizScopeType = 'general'; // 'general', 'chapter', 'deep_learning', 'tech', 'science', 'english', 'economics', 'mindfulness', 'custom'
  final TextEditingController _chapterOrTopicController = TextEditingController(text: 'John 3');
  String? _lastReadChapter;
  bool _isLoadingQuiz = false;
  String? _activeQuizGenerationToken;
  final AudioPlayer _quizAudioPlayer = AudioPlayer();

  // Riddles & Jokes state
  String _riddlesMode = 'riddle'; // 'riddle', 'joke'
  String _riddlesCategory = 'bible'; // 'bible', 'logic', 'tech', 'general'
  bool _isLoadingRiddle = false;
  String? _currentRiddleText;
  String? _currentRiddleAnswer;
  String? _currentRiddleHint;
  String? _currentRiddleExplanation;
  String? _currentJokeSetup;
  String? _currentJokePunchline;
  final TextEditingController _riddleGuessController = TextEditingController();
  bool _riddleChecked = false;
  bool _riddleCorrect = false;
  bool _hintShown = false;
  bool _punchlineShown = false;
  String? _jokeRating;

  void _cancelQuizGeneration() {
    setState(() {
      _activeQuizGenerationToken = null;
      _isLoadingQuiz = false;
    });
  }

  Future<void> _playQuizStartedSoundAndVibrate() async {
    try {
      await _quizAudioPlayer.setSource(AssetSource('audio/quiz_started.wav'));
      await _quizAudioPlayer.resume();
    } catch (e) {
      safePrint("Error playing quiz started sound: $e");
    }
    try {
      await HapticFeedback.vibrate();
      await HapticFeedback.heavyImpact();
    } catch (e) {
      safePrint("Error triggering haptic: $e");
    }
  }

  List<Map<String, dynamic>> _quizQuestions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _isAnswerSubmitted = false;
  int _score = 0;
  bool _quizFinished = false;
  int _selectionVersion = 0;
  final Set<String> _savedQuestions = {};

  // Timed quiz state
  bool _isTimed = false;
  int _selectedTimeLimit = 10; // 5, 10, or 15 seconds
  int _secondsRemainingForQuestion = 0;
  Timer? _questionTimer;

  final TextEditingController _customReadController = TextEditingController();

  final List<String> _books = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua', 'Judges', 'Ruth',
    '1 Samuel', '2 Samuel', '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah',
    'Esther', 'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah',
    'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah',
    'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans', '1 Corinthians', '2 Corinthians',
    'Galatians', 'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter',
    '1 John', '2 John', '3 John', 'Jude', 'Revelation'
  ];

  static const Map<String, int> _bibleBookChapters = {
    'Genesis': 50, 'Exodus': 40, 'Leviticus': 27, 'Numbers': 36, 'Deuteronomy': 34,
    'Joshua': 24, 'Judges': 21, 'Ruth': 4, '1 Samuel': 31, '2 Samuel': 24,
    '1 Kings': 22, '2 Kings': 25, '1 Chronicles': 29, '2 Chronicles': 36,
    'Ezra': 10, 'Nehemiah': 13, 'Esther': 10, 'Job': 42, 'Psalms': 150,
    'Proverbs': 31, 'Ecclesiastes': 12, 'Song of Solomon': 8, 'Isaiah': 66,
    'Jeremiah': 52, 'Lamentations': 5, 'Ezekiel': 48, 'Daniel': 12, 'Hosea': 14,
    'Joel': 3, 'Amos': 9, 'Obadiah': 1, 'Jonah': 4, 'Micah': 7, 'Nahum': 3,
    'Habakkuk': 3, 'Zephaniah': 3, 'Haggai': 2, 'Zechariah': 14, 'Malachi': 4,
    'Matthew': 28, 'Mark': 16, 'Luke': 24, 'John': 21, 'Acts': 28, 'Romans': 16,
    '1 Corinthians': 16, '2 Corinthians': 13, 'Galatians': 6, 'Ephesians': 6,
    'Philippians': 4, 'Colossians': 4, '1 Thessalonians': 5, '2 Thessalonians': 3,
    '1 Timothy': 6, '2 Timothy': 4, 'Titus': 3, 'Philemon': 1, 'Hebrews': 13,
    'James': 5, '1 Peter': 5, '2 Peter': 3, '1 John': 5, '2 John': 1, '3 John': 1,
    'Jude': 1, 'Revelation': 22
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeGemini();
    _initData();
    _initAudioContext();
  }

  Future<void> _initData() async {
    await _loadLastReadChapter();
    await _fetchBibleChapter();
  }

  void _initAudioContext() {
    try {
      _quizAudioPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
    } catch (e) {
      safePrint("Error initializing audio context: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customReadController.dispose();
    _chapterOrTopicController.dispose();
    _riddleGuessController.dispose();
    _questionTimer?.cancel();
    _quizAudioPlayer.dispose();
    super.dispose();
  }

  void _initializeGemini() {
    final apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
    _geminiService.init(apiKey);
  }

  Future<void> _loadLastReadChapter() async {
    final val = await SharedPrefs.getString('LAST_READ_BIBLE_CHAPTER');
    if (mounted) {
      setState(() {
        _lastReadChapter = val.isNotEmpty ? val : null;
        _chapterOrTopicController.text = _lastReadChapter ?? '$_selectedBook $_selectedChapter';
        final targetChapter = _chapterOrTopicController.text;
        final parts = targetChapter.split(' ');
        if (parts.length >= 2) {
          final chapterStr = parts.last;
          final chapter = int.tryParse(chapterStr);
          if (chapter != null) {
            final bookName = parts.sublist(0, parts.length - 1).join(' ');
            if (_books.contains(bookName)) {
              _selectedBook = bookName;
              _selectedChapter = chapter;
            }
          }
        }
      });
    }
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    if (!_isTimed || _quizQuestions.isEmpty || _quizFinished) return;

    setState(() {
      _secondsRemainingForQuestion = _selectedTimeLimit;
    });

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemainingForQuestion > 1) {
        setState(() {
          _secondsRemainingForQuestion--;
        });
      } else {
        timer.cancel();
        setState(() {
          _secondsRemainingForQuestion = 0;
        });
        _handleTimeOut();
      }
    });
  }

  void _handleTimeOut() {
    _questionTimer?.cancel();
    setState(() {
      _selectedAnswerIndex = -1; // -1 represents timeout
      _isAnswerSubmitted = true;
    });

    // Automatically transition to next question after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _isAnswerSubmitted && _isTimed) {
        _nextQuestion();
      }
    });
  }

  void _selectAndSubmitTimedAnswer(int index) {
    _questionTimer?.cancel();
    setState(() {
      _selectedAnswerIndex = index;
      _isAnswerSubmitted = true;
      final correctAnswer = _quizQuestions[_currentQuestionIndex]['answer'] as int;
      if (_selectedAnswerIndex == correctAnswer) {
        _score++;
      }
    });

    // Automatically transition to next question after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _isAnswerSubmitted && _isTimed) {
        _nextQuestion();
      }
    });
  }

  Future<void> _saveCustomReadChapter() async {
    final text = _customReadController.text.trim();
    if (text.isEmpty) {
      context.showInAppNotification(
        'Please enter a chapter or verse.',
        type: InAppNotificationType.error,
      );
      return;
    }

    await SharedPrefs.setString('LAST_READ_BIBLE_CHAPTER', text);
    await _loadLastReadChapter();
    _customReadController.clear();
    FocusScope.of(context).unfocus();
    context.showInAppNotification(
      'Successfully logged: $text',
      type: InAppNotificationType.success,
    );
  }

  Future<void> _fetchBibleChapter() async {
    setState(() {
      _isLoadingChapter = true;
      _aiExplanation = null;
      _verses = [];
      _selectedText = null;
      _chapterText = null;
    });

    try {
      final dio = Dio();
      final url = 'https://bible-api.com/${Uri.encodeComponent(_selectedBook)}+$_selectedChapter';
      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        final list = List<Map<String, dynamic>>.from(data['verses']);
        setState(() {
          _verses = list;
          _chapterText = data['text'] as String?;
        });

        // Save last read chapter
        final chapterStr = '$_selectedBook $_selectedChapter';
        await SharedPrefs.setString('LAST_READ_BIBLE_CHAPTER', chapterStr);
        await _loadLastReadChapter();
        
        // Log daily streak / action complete
        await EngagementService().recordAction(EngagementAction.bibleChapterRead);
      } else {
        if (mounted) {
          context.showInAppNotification('Failed to load chapter. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showInAppNotification('Connection required to load Bible.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingChapter = false);
      }
    }
  }

  void _explainChapter() {
    if (_chapterText == null || _chapterText!.trim().isEmpty) return;

    final authStore = context.read<AppAuthProvider>();
    final isPro = authStore.isPro;
    if (!isPro && authStore.explanationCount >= 3) {
      AppHelper.watchAdForAction(
        context,
        promptText: 'You have used your 3 free explanations for today. Watch a video ad to unlock another explanation!',
        onReward: () async {
          await authStore.rewardExplanationCount();
          _startExplainChapter();
        },
      );
    } else {
      _startExplainChapter();
    }
  }

  Future<void> _startExplainChapter() async {
    final authStore = context.read<AppAuthProvider>();
    final isPro = authStore.isPro;

    setState(() => _isExplaining = true);
    
    final prompt = """
You are the **MindPilot Bible Scholar**. The user has just read the chapter: "$_selectedBook $_selectedChapter".
Here is the text of the chapter:
"$_chapterText"

Please provide a clean, highly insightful explanation and mindfulness takeaway of this chapter (max 4 paragraphs).
Highlight:
1. **Core Message**: The primary theological or moral message.
2. **Key Verses**: Highlight 1 or 2 pivotal verses and explain their significance.
3. **Mindfulness & Life Application**: How can the user apply this lesson to build clarity, peace, or focus in their daily life?

Ensure the output is beautifully styled in Markdown. Crucial: Make sure all section titles and headers are explicitly wrapped in bold markdown (e.g. **Core Message**, **Key Verses**, **Mindfulness & Life Application**). Make sure all quoted verses (especially in the Key Verses section) are formatted as blockquotes starting with '>' (e.g. '> "For God so loved the world..."') so they are rendered as distinct blockquotes in red.
""";

    try {
      final response = await _geminiService.sendMessage(prompt);
      if (mounted && response != null) {
        setState(() {
          _aiExplanation = response;
        });
        if (!isPro) {
          await authStore.incrementExplanationCount();
        }
      }
    } catch (e) {
      if (mounted) {
        context.showInAppNotification('Failed to generate explanation: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExplaining = false);
      }
    }
  }

  void _explainSpecificVerse(Map<String, dynamic> verse) {
    final authStore = context.read<AppAuthProvider>();
    final isPro = authStore.isPro;
    if (!isPro && authStore.explanationCount >= 3) {
      AppHelper.watchAdForAction(
        context,
        promptText: 'You have used your 3 free explanations for today. Watch a video ad to unlock another explanation!',
        onReward: () async {
          await authStore.rewardExplanationCount();
          _startExplainSpecificVerse(verse);
        },
      );
    } else {
      _startExplainSpecificVerse(verse);
    }
  }

  Future<void> _startExplainSpecificVerse(Map<String, dynamic> verse) async {
    final authStore = context.read<AppAuthProvider>();
    final isPro = authStore.isPro;

    setState(() => _isExplaining = true);

    final vNum = verse['verse'];
    final vText = verse['text'];
    final prompt = """
You are the **MindPilot Bible Scholar**. Provide a very brief, summarized, encouraging, and clear explanation of this specific verse:
"$_selectedBook $_selectedChapter:$vNum - $vText"

Provide:
1. **Context & Meaning**: Summarize what this verse means in a single short paragraph.
2. **Practical Takeaway**: Give 1 brief actionable tip to practice this wisdom today.

Format nicely using Markdown. Crucial: Make sure the Bible verse text itself is formatted as a blockquote starting with '>' (e.g. '> "For God so loved the world..."') so it is rendered as a distinct blockquote in red. Keep the entire response extremely short, concise, and summarized (max 150 words total).
""";

    try {
      final response = await _geminiService.sendMessage(prompt);
      if (mounted && response != null) {
        if (!isPro) {
          await authStore.incrementExplanationCount();
        }
        showDialog(
          context: context,
          builder: (ctx) {
            AppTheme theme = ctx.watch();
            return AlertDialog(
              backgroundColor: theme.brandDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: PrimaryText(
                text: 'Verse $vNum Explanation',
                color: theme.accentTxt,
                fontWeight: FontWeight.bold,
              ),
              content: SingleChildScrollView(
                child: MarkdownBody(
                  data: response,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: theme.accentTxt, fontSize: 14, height: 1.5),
                    strong: TextStyle(color: theme.primaryBase, fontWeight: FontWeight.bold),
                    blockquote: TextStyle(
                      color: theme.errorPrimary,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: theme.errorPrimary.withOpacity(0.05),
                      border: Border(
                        left: BorderSide(color: theme.errorPrimary, width: 3),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: PrimaryText(text: 'Close', color: theme.primaryBase, fontWeight: FontWeight.bold),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        context.showInAppNotification('Failed to explain verse: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExplaining = false);
      }
    }
  }

  void _explainSelectedText(String text) {
    if (text.trim().isEmpty) return;

    final authStore = context.read<AppAuthProvider>();
    final isPro = authStore.isPro;
    if (!isPro && authStore.explanationCount >= 3) {
      AppHelper.watchAdForAction(
        context,
        promptText: 'You have used your 3 free explanations for today. Watch a video ad to unlock another explanation!',
        onReward: () async {
          await authStore.rewardExplanationCount();
          _startExplainSelectedText(text);
        },
      );
    } else {
      _startExplainSelectedText(text);
    }
  }

  Future<void> _startExplainSelectedText(String text) async {
    final authStore = context.read<AppAuthProvider>();
    final isPro = authStore.isPro;

    setState(() => _isExplaining = true);

    final prompt = """
You are the **MindPilot Bible Scholar**. Provide a very brief, summarized, encouraging, and clear explanation of the following highlighted scripture text from the book "$_selectedBook $_selectedChapter":

"$text"

Provide:
1. **Theological Context & Meaning**: Summarize what this scripture means in a single short paragraph.
2. **Actionable Takeaway**: Give 1 brief actionable tip to practice this wisdom today to build peace/focus.

Format the response beautifully in Markdown. Crucial: Make sure any quoted Bible verses are explicitly formatted as blockquotes starting with '>' (e.g. '> "For God so loved the world..."') so they are rendered as distinct blockquotes in red. Keep the entire response extremely short, concise, and summarized (max 150 words total).
""";

    try {
      final response = await _geminiService.sendMessage(prompt);
      if (mounted && response != null) {
        if (!isPro) {
          await authStore.incrementExplanationCount();
        }
        showDialog(
          context: context,
          builder: (ctx) {
            AppTheme theme = ctx.watch();
            return AlertDialog(
              backgroundColor: theme.brandDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: PrimaryText(
                text: 'MindPilot Explanation',
                color: theme.accentTxt,
                fontWeight: FontWeight.bold,
              ),
              content: SizedBox(
                width: MediaQuery.of(ctx).size.width * 0.85,
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: response,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: theme.accentTxt, fontSize: 14, height: 1.5),
                      strong: TextStyle(color: theme.primaryBase, fontWeight: FontWeight.bold),
                      blockquote: TextStyle(
                        color: theme.errorPrimary,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: theme.errorPrimary.withOpacity(0.05),
                        border: Border(
                          left: BorderSide(color: theme.errorPrimary, width: 3),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: PrimaryText(text: 'Close', color: theme.primaryBase, fontWeight: FontWeight.bold),
                ),
              ],
            );
          },
        );
        if (mounted) {
          setState(() {
            _selectedText = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        context.showInAppNotification('Failed to explain text: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExplaining = false);
      }
    }
  }

  Future<void> _generateQuiz() async {
    final isPro = context.read<AppAuthProvider>().isPro;
    final isFreeScope = _quizScopeType == 'general' || _quizScopeType == 'chapter';

    if (!isPro && (!isFreeScope || _isTimed)) {
      if (mounted) {
        AppHelper.watchAdForAction(
          context,
          promptText: 'Watch a video ad to unlock this quiz session!',
          onReward: () {
            _startQuizGeneration();
          },
        );
      }
      return;
    }

    _startQuizGeneration();
  }

  Future<void> _startQuizGeneration() async {
    final currentToken = DateTime.now().microsecondsSinceEpoch.toString();
    _activeQuizGenerationToken = currentToken;

    setState(() {
      _isLoadingQuiz = true;
      _quizQuestions = [];
      _currentQuestionIndex = 0;
      _selectedAnswerIndex = null;
      _isAnswerSubmitted = false;
      _score = 0;
      _quizFinished = false;
      _savedQuestions.clear();
    });

    String targetContext = '';
    String styleInstructions = '';
    String systemInstruction = 'You are a precise Bible quiz generator. You generate high-quality Bible trivia questions. Under no circumstances do you generate questions about any other topic, including the MindPilot application or technology. Only biblical facts are allowed.';

    if (_quizScopeType == 'deep_learning') {
      final targetChapter = _chapterOrTopicController.text.trim().isNotEmpty
          ? _chapterOrTopicController.text.trim()
          : (_lastReadChapter ?? 'John 3');
      targetContext = 'application and critical thinking lessons inspired by the Bible chapter "$targetChapter"';
      styleInstructions = """
The questions should NOT be direct trivia or fact recall from the chapter (e.g., do not ask who said what or specific verse numbers).
Instead, generate **learnable, reflective, and application-oriented questions** that make the user think widely about the moral, philosophical, or practical life lessons of the chapter, and explain what they have learnt.
The 4 options (answers) must fall around the practical application of those concepts, and the correct option should represent the most meaningful, constructive takeaway or life application.
Ensure the "explanation" for each question explains the lesson clearly and how it relates to what they read.
Ensure all questions generated are completely unique, deep, and never repetitive compared to standard prompts.
""";
      systemInstruction = "You are a precise Bible study application generator. You generate deep, reflective multiple-choice questions focusing on practical takeaways and moral application of scripture. Under no circumstances do you generate questions about other topics.";
    } else if (_quizScopeType == 'chapter') {
      final targetChapter = _chapterOrTopicController.text.trim().isNotEmpty
          ? _chapterOrTopicController.text.trim()
          : (_lastReadChapter ?? 'John 3');
      targetContext = 'the Bible chapter "$targetChapter"';
      styleInstructions = "Generate standard comprehension and contextual questions from this chapter. Avoid repeating questions; cover different verses and concepts in the chapter to make it highly unique.";
      systemInstruction = "You are a precise Bible quiz generator. You generate high-quality Bible trivia questions based strictly on the specified chapter. Under no circumstances do you generate questions about any other topic. Only facts from the specified chapter are allowed.";
    } else if (_quizScopeType == 'tech') {
      targetContext = 'technology, computer science, software engineering, and programming';
      styleInstructions = "Generate educational, accurate multiple-choice questions about software engineering, programming languages, computer science, and digital technology. Avoid repeating questions; ensure all questions are completely unique.";
      systemInstruction = "You are a precise technology and coding quiz generator. You generate educational, accurate multiple-choice questions about tech and coding. Do not include any inappropriate, mature, or irrelevant content.";
    } else if (_quizScopeType == 'science') {
      targetContext = 'science, physics, chemistry, astronomy, and biology';
      styleInstructions = "Generate educational, accurate multiple-choice questions about science and physics. Avoid repeating questions; ensure all questions are completely unique.";
      systemInstruction = "You are a precise science quiz generator. You generate educational, accurate multiple-choice questions about science and physics. Do not include any inappropriate, mature, or irrelevant content.";
    } else if (_quizScopeType == 'english') {
      targetContext = 'English grammar, vocabulary, classic literature, famous authors, and literary devices';
      styleInstructions = "Generate educational, accurate multiple-choice questions about English language and literature. Avoid repeating questions; ensure all questions are completely unique.";
      systemInstruction = "You are a precise English and literature quiz generator. You generate educational, accurate multiple-choice questions. Do not include any inappropriate, mature, or irrelevant content.";
    } else if (_quizScopeType == 'economics') {
      targetContext = 'economics, microeconomics, macroeconomics, finance, and investment principles';
      styleInstructions = "Generate educational, accurate multiple-choice questions about economics and finance. Avoid repeating questions; ensure all questions are completely unique.";
      systemInstruction = "You are a precise economics and finance quiz generator. You generate educational, accurate multiple-choice questions. Do not include any inappropriate, mature, or irrelevant content.";
    } else if (_quizScopeType == 'mindfulness') {
      targetContext = 'personality development, emotional intelligence, mindfulness practices, and positive psychology';
      styleInstructions = "Generate constructive, inspiring multiple-choice questions that help players build self-awareness and positive traits. Avoid repeating questions; ensure all questions are completely unique.";
      systemInstruction = "You are a precise mindfulness and personality development quiz generator. You generate educational, constructive multiple-choice questions that help players build self-awareness and positive traits. Do not include any inappropriate, mature, or irrelevant content.";
    } else if (_quizScopeType == 'custom') {
      final customTopic = _chapterOrTopicController.text.trim();
      final topic = customTopic.isNotEmpty ? customTopic : 'World History';
      targetContext = 'the topic: "$topic"';
      styleInstructions = "Generate educational, accurate multiple-choice questions about this topic. CRITICAL: Ensure the questions are highly educational, accurate, and completely free of inappropriate or offensive content. Under no circumstances should you output any inappropriate, political, offensive, or adult topics.";
      systemInstruction = "You are a precise quiz generator. You generate educational, accurate multiple-choice questions about the specified topic: '$topic'. You must ensure there is absolutely no inappropriate, offensive, or mature content. Ensure the quiz remains clean and educational.";
    } else {
      targetContext = 'general Bible knowledge (covering both Old and New Testaments)';
      styleInstructions = """
Generate standard Bible trivia and knowledge questions.
CRITICAL: To tap into the vast breadth of the entire Bible (capable of generating over 1 million unique questions), you MUST avoid repeating common, generic, or obvious trivia questions (e.g., do not ask 'Who built the ark?', 'Who was the first man?', 'Who was swallowed by a whale?', 'What is the first book of the Bible?', or other generic Sunday school questions).
Instead, select widely diverse books, chapters, minor characters, obscure events, specific theological facts, prophecy details, historical context, and deep scriptural concepts from the Old and New Testaments.
Every time you are called, randomize the target books and generate a completely fresh, unique, and deep set of questions to ensure a highly educational and non-repetitive learning experience.
""";
    }

    final prompt = """
You are the **MindPilot Quiz Generator**. Generate a JSON array of multiple choice questions based on: $targetContext.
The JSON array must contain exactly $_questionCount questions.

$styleInstructions

CRITICAL REQUIREMENT ON REPETITION: 
- You MUST ensure all questions in this batch are completely unique and have absolutely no repetition.
- Do NOT repeat questions from previous runs. Assume the user has played thousands of times. Avoid common, obvious questions.
- Explore the deepest corners, obscure events, historical details, and rich theology of the text to ensure the questions are fresh and varied.
- Avoid repeating structures, questions, or themes. Make every question distinct.

Each question object in the array must have the following keys:
- "question": The question text.
- "options": An array of exactly 4 strings for choices.
- "answer": The index (0 to 3) of the correct option.
- "explanation": A brief explanation of the correct answer.

CRITICAL ACCURACY REQUIREMENT:
- You MUST double check the correctness of the generated "answer" index.
- The "answer" index MUST correspond exactly to the index (0 to 3) of the correct answer in the "options" array.
- For example, if Jesus is the correct option and is placed at index 1 of the options list, the "answer" index MUST be 1. Do not mismatch them.
- Ensure the question details are completely accurate, using undisputed facts.

Return ONLY the raw JSON array. Do not include markdown code block formatting (no ```json or ```). Just raw JSON.
""";

    try {
      if (_activeQuizGenerationToken != currentToken) return;
      final response = await _geminiService.sendMessageOneShot(
        prompt,
        systemInstruction: systemInstruction,
      );
      
      if (_activeQuizGenerationToken != currentToken) return;
      if (response != null) {
        String cleanJson = response.trim();
        if (cleanJson.startsWith('```')) {
          final lines = cleanJson.split('\n');
          if (lines.first.startsWith('```')) lines.removeAt(0);
          if (lines.last.startsWith('```')) lines.removeLast();
          cleanJson = lines.join('\n').trim();
        }
        
        final List decoded = jsonDecode(cleanJson);
        if (_activeQuizGenerationToken != currentToken) return;
        setState(() {
          _quizQuestions = List<Map<String, dynamic>>.from(decoded);
        });
        _playQuizStartedSoundAndVibrate();
        _startQuestionTimer();
      }
    } catch (e) {
      if (_activeQuizGenerationToken != currentToken) return;
      // Fallback questions if AI fails
      setState(() {
        _quizQuestions = [
          {
            "question": "Who built the ark as commanded by God?",
            "options": ["Moses", "Abraham", "Noah", "David"],
            "answer": 2,
            "explanation": "Noah built the ark to save his family and animals from the flood as commanded in Genesis 6."
          },
          {
            "question": "What is the first book of the Bible?",
            "options": ["Exodus", "Genesis", "Matthew", "John"],
            "answer": 1,
            "explanation": "Genesis is the opening book of the Bible, detailing the creation story."
          },
          {
            "question": "How many disciples did Jesus choose?",
            "options": ["10", "12", "7", "40"],
            "answer": 1,
            "explanation": "Jesus chose 12 Apostles to follow him and spread his teachings."
          },
        ];
      });
      _playQuizStartedSoundAndVibrate();
      _startQuestionTimer();
      if (mounted) {
        context.showInAppNotification('Dynamic quiz error. Loaded fallback Bible Quiz.', type: InAppNotificationType.info);
      }
    } finally {
      if (mounted && _activeQuizGenerationToken == currentToken) {
        setState(() => _isLoadingQuiz = false);
      }
    }
  }

  void _shareQuestion(Map<String, dynamic> question) {
    final text = question['question'] as String;
    final options = List<String>.from(question['options']);
    
    final shareBody = """
Hey! Check out this deep learning question from my Bible study on MindPilot:

"$text"

Options:
A. ${options[0]}
B. ${options[1]}
C. ${options[2]}
D. ${options[3]}

Let's discuss and reflect on this! 📖✨
""";

    ShareService.shareText(shareBody, subject: 'Bible Deep Learning Question');
  }

  Future<void> _saveQuestionToJournal(Map<String, dynamic> question) async {
    final qText = question['question'] as String;
    if (_savedQuestions.contains(qText)) {
      context.showInAppNotification('Question already saved to journal.', type: InAppNotificationType.info);
      return;
    }

    final options = List<String>.from(question['options']);
    final answerIdx = question['answer'] as int;
    final explanation = question['explanation'] as String;

    final targetChapter = _chapterOrTopicController.text.trim().isNotEmpty
        ? _chapterOrTopicController.text.trim()
        : (_lastReadChapter ?? 'Bible study');
    final title = 'Scripture Reflection: $targetChapter';
    final journalText = """
**Reflective Question:**
$qText

**Options:**
A. ${options[0]}
B. ${options[1]}
C. ${options[2]}
D. ${options[3]}

**Correct Answer:** Option ${String.fromCharCode(65 + answerIdx)}: ${options[answerIdx]}

**Theological & Mindfulness Insight:**
$explanation

---
**My Personal Reflections:**
(Type your personal reflections here to build mindfulness...)
""";

    try {
      await context.read<JournalProvider>().addEntry(
        title: title,
        text: journalText,
        mood: 'Mindful 🧘',
      );
      setState(() {
        _savedQuestions.add(qText);
      });
      context.showInAppNotification(
        'Saved to journal! You can reflect on it in the Journal tab.',
        type: InAppNotificationType.success,
      );
    } catch (e) {
      context.showInAppNotification('Failed to save to journal: $e', type: InAppNotificationType.error);
    }
  }

  void _submitAnswer() {
    if (_selectedAnswerIndex == null || _isAnswerSubmitted) return;

    setState(() {
      _isAnswerSubmitted = true;
      final correctAnswer = _quizQuestions[_currentQuestionIndex]['answer'] as int;
      if (_selectedAnswerIndex == correctAnswer) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    _questionTimer?.cancel();
    setState(() {
      if (_currentQuestionIndex < _quizQuestions.length - 1) {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _isAnswerSubmitted = false;
        _startQuestionTimer();
      } else {
        _quizFinished = true;
        _completeQuizEngagement();
      }
    });
  }

  Future<void> _completeQuizEngagement() async {
    // Record completion and award XP
    final earnedXp = _score * 4; // bonus XP per correct answer
    await EngagementService().recordAction(
      EngagementAction.bibleQuizComplete, 
      bonusAmount: earnedXp
    );
    
    try {
      final totalXpGained = 20 + earnedXp;
      final targetChapter = _chapterOrTopicController.text.trim().isNotEmpty
          ? _chapterOrTopicController.text.trim()
          : (_lastReadChapter ?? 'Unknown');
      final quiz = {
        'date': DateTime.now().toIso8601String(),
        'chapter': _quizScopeType == 'general' ? 'General Knowledge' : targetChapter,
        'score': _score,
        'total_questions': _quizQuestions.length,
        'quiz_type': _quizScopeType,
        'xp_earned': totalXpGained,
      };
      await DatabaseHelper().insertQuizResult(quiz);
    } catch (e) {
      debugPrint('Error logging quiz results: $e');
    }
  }

  void _confirmCancelQuiz() {
    _questionTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        AppTheme theme = ctx.watch();
        return AlertDialog(
          backgroundColor: theme.brandDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: PrimaryText(
            text: 'Cancel Quiz?',
            color: theme.accentTxt,
            fontWeight: FontWeight.bold,
          ),
          content: SecondaryText(
            text: 'Are you sure you want to cancel the quiz? Your current progress will be lost.',
            color: theme.accentTxt.withOpacity(0.8),
            fontSize: 14,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _startQuestionTimer();
              },
              child: PrimaryText(
                text: 'Keep Going',
                color: theme.accentTxt.withOpacity(0.5),
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _quizQuestions = [];
                  _currentQuestionIndex = 0;
                  _selectedAnswerIndex = null;
                  _isAnswerSubmitted = false;
                  _score = 0;
                  _quizFinished = false;
                });
              },
              child: PrimaryText(
                text: 'Cancel Quiz',
                color: theme.errorPrimary,
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'Bible Study & Quiz',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.arrow_back_ios, color: theme.accentTxt, size: 20),
        ).rippleClick(() => context.pop()),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.primaryBase,
          unselectedLabelColor: theme.accentTxt.withOpacity(0.5),
          indicatorColor: theme.primaryBase,
          tabs: const [
            Tab(text: 'Read & Learn', icon: Icon(Icons.menu_book)),
            Tab(text: 'Bible Quiz', icon: Icon(Icons.quiz)),
            Tab(text: 'Riddles & Jokes', icon: Icon(Icons.sentiment_very_satisfied)),
          ],
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
          TabBarView(
            controller: _tabController,
            children: [
              _buildReadTab(theme),
              _buildQuizTab(theme),
              _buildRiddlesTab(theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadTab(AppTheme theme) {
    final activeColor = _customExplanationColor ?? theme.accentTxt;
    final activeBibleColor = _customBibleColor ?? theme.accentTxt;
    if (_isLoadingChapter) {
      return const Center(child: CircularProgressIndicator());
    }

    return LoadingOverlay(
      isLoading: _isExplaining,
      child: SelectionArea(
        onSelectionChanged: (SelectedContent? content) {
          final text = content?.plainText;
          _selectionVersion++;
          final currentVersion = _selectionVersion;
          if (text != null && text.trim().isNotEmpty) {
            setState(() {
              _selectedText = text;
            });
          } else {
            Future.delayed(const Duration(milliseconds: 250), () {
              if (mounted && _selectionVersion == currentVersion) {
                setState(() {
                  _selectedText = null;
                });
              }
            });
          }
        },
        contextMenuBuilder: (context, selectableRegionState) {
          final buttonItems = selectableRegionState.contextMenuButtonItems.where((item) {
            return item.type == ContextMenuButtonType.copy ||
                item.type == ContextMenuButtonType.selectAll;
          }).toList();

          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: selectableRegionState.contextMenuAnchors,
            buttonItems: [
              ...buttonItems,
              ContextMenuButtonItem(
                onPressed: () {
                  selectableRegionState.hideToolbar();
                  if (_selectedText != null && _selectedText!.trim().isNotEmpty) {
                    _explainSelectedText(_selectedText!);
                  }
                },
                label: 'Explain with MindPilot',
              ),
            ],
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book & Chapter Selectors
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.accentTxt.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedBook,
                        dropdownColor: theme.brandDark,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: TextStyle(color: theme.accentTxt, fontSize: 15),
                        items: _books.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedBook = val;
                              final maxCh = _bibleBookChapters[val] ?? 50;
                              if (_selectedChapter > maxCh) {
                                _selectedChapter = 1;
                              }
                            });
                            _fetchBibleChapter();
                          }
                        },
                      ),
                    ),
                  ),
                  12.horizontalSpace,
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.accentTxt.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButton<int>(
                        value: _selectedChapter,
                        dropdownColor: theme.brandDark,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: TextStyle(color: theme.accentTxt, fontSize: 15),
                        items: List.generate(_bibleBookChapters[_selectedBook] ?? 50, (index) => index + 1)
                            .map((c) => DropdownMenuItem(value: c, child: Text('Ch. $c')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedChapter = val);
                            _fetchBibleChapter();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              24.verticalSpace,

              // Customize controls bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_size, color: theme.accentTxt.withOpacity(0.6), size: 16),
                      8.horizontalSpace,
                      _fontSizeOption('S', 'small'),
                      6.horizontalSpace,
                      _fontSizeOption('M', 'medium'),
                      6.horizontalSpace,
                      _fontSizeOption('L', 'large'),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, color: theme.accentTxt.withOpacity(0.6), size: 16),
                      8.horizontalSpace,
                      _bibleColorPaletteOption(const Color(0xFFC0FF00), activeBibleColor), // Lemon Green
                      8.horizontalSpace,
                      _bibleColorPaletteOption(const Color(0xFFFF914D), activeBibleColor), // Orange
                      8.horizontalSpace,
                      _bibleColorPaletteOption(theme.accentTxt, activeBibleColor, isReset: true), // Reset / White
                    ],
                  ),
                ],
              ),
              24.verticalSpace,
              
              // Verses view
              if (_verses.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PrimaryText(
                      text: '$_selectedBook $_selectedChapter',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.accentTxt,
                    ),
                    if (_selectedText != null && _selectedText!.trim().isNotEmpty)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryBase,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () {
                          _explainSelectedText(_selectedText!);
                        },
                        icon: const Icon(Icons.auto_awesome, size: 14),
                        label: const Text(
                          'Explain Selected',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                4.verticalSpace,
                SecondaryText(
                  text: 'Longpress and drag to highlight any verses, then select "Explain with AI" from the menu.',
                  fontSize: 11,
                  color: theme.accentTxt.withOpacity(0.5),
                ),
                16.verticalSpace,
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  gradient: theme.glassGradient,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _verses.length,
                    itemBuilder: (context, index) {
                      final v = _verses[index];
                      final bibleFontSize = _getBibleFontSize();
                      final verseFontSize = _getVerseNumberFontSize();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${v['verse']} ',
                                style: TextStyle(
                                  color: theme.primaryBase,
                                  fontWeight: FontWeight.bold,
                                  fontSize: verseFontSize,
                                ),
                              ),
                              TextSpan(
                                text: '${v['text']}'.trim(),
                                style: TextStyle(
                                  color: activeBibleColor.withOpacity(0.9),
                                  fontSize: bibleFontSize,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                24.verticalSpace,
                CustomButton(
                  label: 'Chapter Explanation',
                  onPressed: _explainChapter,
                  isGlass: true,
                ),
              ],
              
              // Explanation block
              if (_aiExplanation != null) ...[
                24.verticalSpace,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PrimaryText(
                      text: 'Theological Insights',
                      color: theme.primaryBase,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    Row(
                      children: [
                        _colorPaletteOption(const Color(0xFFC0FF00), activeColor), // Lemon Green
                        8.horizontalSpace,
                        _colorPaletteOption(const Color(0xFFFF914D), activeColor), // Orange
                        8.horizontalSpace,
                        _colorPaletteOption(theme.accentTxt, activeColor, isReset: true), // Reset / White
                      ],
                    ),
                  ],
                ),
                16.verticalSpace,
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  gradient: theme.glassGradient,
                  child: MarkdownBody(
                    data: _aiExplanation!,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: activeColor, fontSize: 14, height: 1.6),
                      strong: TextStyle(color: theme.primaryBase, fontWeight: FontWeight.bold),
                      blockquote: TextStyle(
                        color: theme.errorPrimary,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: theme.errorPrimary.withOpacity(0.05),
                        border: Border(
                          left: BorderSide(color: theme.errorPrimary, width: 3),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      h1: TextStyle(
                        color: theme.primaryBase,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: TextStyle(
                        color: theme.primaryBase,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      h3: TextStyle(
                        color: theme.primaryBase,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      h4: TextStyle(
                        color: theme.primaryBase,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      listBullet: TextStyle(color: activeColor),
                    ),
                  ),
                ),
              ],
              120.verticalSpace,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizTab(AppTheme theme) {
    final isPro = context.watch<AppAuthProvider>().isPro;
    if (_isLoadingQuiz) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryBase),
                  strokeWidth: 3.0,
                ),
              ),
              32.verticalSpace,
              PrimaryText(
                text: 'Generating ${_getScopeFriendlyName(_quizScopeType)} Quiz... 📖\n\nYour questions are being generated, please sit back and be prepared...',
                textAlign: TextAlign.center,
                fontSize: 16,
                color: theme.accentTxt.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
              32.verticalSpace,
              CustomButton(
                label: 'Cancel',
                isOutline: true,
                borderColor: theme.errorPrimary,
                textColor: theme.errorPrimary,
                onPressed: _cancelQuizGeneration,
              ),
            ],
          ),
        ),
      );
    }

    if (_quizQuestions.isNotEmpty) {
      return _buildActiveQuiz(theme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrimaryText(
            text: 'Test Your Scripture Knowledge',
            color: theme.accentTxt,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          12.verticalSpace,
          SecondaryText(
            text: 'Engage with daily quizzes generated directly by your AI study assistant.',
            color: theme.accentTxt.withOpacity(0.6),
          ),
          16.verticalSpace,
          CustomButton(
            label: 'Group Multiplayer Quiz 👥',
            backgroundColor: theme.primaryBase,
            textColor: Colors.black,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'GroupLobbyScreen'),
                  builder: (_) => const GroupLobbyScreen(),
                ),
              );
            },
          ),
          24.verticalSpace,
          
          // Question count selection
          PrimaryText(
            text: 'Number of Questions',
            color: theme.accentTxt,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          12.verticalSpace,
          Row(
            children: [5, 10, 20].map((count) {
              final isSelected = _questionCount == count;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    gradient: isSelected ? theme.glassGradient : null,
                    border: Border.all(
                      color: isSelected ? theme.primaryBase : Colors.white12,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    child: Center(
                      child: PrimaryText(
                        text: '$count',
                        color: theme.accentTxt,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ).rippleClick(() => setState(() => _questionCount = count)),
                ),
              );
            }).toList(),
          ),
          // Scope selection
          PrimaryText(
            text: 'Quiz Category',
            color: theme.accentTxt,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          12.verticalSpace,
          GlassContainer(
            padding: const EdgeInsets.all(16),
            border: Border.all(color: theme.primaryBase.withOpacity(0.3), width: 1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PrimaryText(
                        text: _getScopeFriendlyName(_quizScopeType),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryBase,
                      ),
                      4.verticalSpace,
                      SecondaryText(
                        text: _getScopeDescription(_quizScopeType),
                        fontSize: 12,
                        color: theme.accentTxt.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: theme.primaryBase, size: 16),
              ],
            ),
          ).rippleClick(() async {
            final result = await Navigator.push<Map<String, String>>(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'QuizScopeSelectionScreen'),
                builder: (_) => QuizScopeSelectionScreen(
                  initialScopeType: _quizScopeType,
                  initialScopeValue: _chapterOrTopicController.text,
                ),
              ),
            );
            if (result != null && mounted) {
              setState(() {
                _quizScopeType = result['scopeType']!;
                _chapterOrTopicController.text = result['scopeValue']!;
              });
              AnalyticsService.logQuizScopeSelected(_quizScopeType, _chapterOrTopicController.text);
            }
          }),
          
          24.verticalSpace,
          // Timed Quiz Settings (Premium Feature)
          Row(
            children: [
              PrimaryText(
                text: 'Timer Settings',
                color: theme.accentTxt,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              8.horizontalSpace,
              const Icon(
                Icons.star,
                color: Color(0xFFF59E0B),
                size: 14,
              ),
            ],
          ),
          12.verticalSpace,
          GlassContainer(
            padding: const EdgeInsets.all(16),
            border: Border.all(color: Colors.white12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PrimaryText(
                                text: 'Timed Quiz',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: theme.accentTxt,
                              ),
                              if (!isPro) ...[
                                8.horizontalSpace,
                                Icon(
                                  Icons.lock_outline,
                                  color: theme.accentTxt.withOpacity(0.5),
                                  size: 14,
                                ),
                              ],
                            ],
                          ),
                          4.verticalSpace,
                          SecondaryText(
                            text: 'Answer each question before time runs out',
                            fontSize: 11,
                            color: theme.accentTxt.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isTimed,
                      activeThumbColor: theme.primaryBase,
                      activeTrackColor: theme.primaryBase.withOpacity(0.3),
                      inactiveThumbColor: theme.accentTxt.withOpacity(0.4),
                      inactiveTrackColor: Colors.white12,
                      onChanged: (val) {
                        final authStore = context.read<AppAuthProvider>();
                        if (!authStore.isPro) {
                          AppHelper.showPaywall(context, feature: 'Timed Quiz Mode');
                          return;
                        }
                        setState(() {
                          _isTimed = val;
                        });
                      },
                    ),
                  ],
                ),
                if (_isTimed && isPro) ...[
                  16.verticalSpace,
                  const Divider(color: Colors.white12, height: 1),
                  16.verticalSpace,
                  SecondaryText(
                    text: 'Time Limit per Question',
                    fontSize: 12,
                    color: theme.accentTxt.withOpacity(0.7),
                  ),
                  12.verticalSpace,
                  Row(
                    children: [5, 10, 15].map((secs) {
                      final isSelected = _selectedTimeLimit == secs;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTimeLimit = secs;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? theme.primaryBase.withOpacity(0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? theme.primaryBase : Colors.white12,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Center(
                                child: PrimaryText(
                                  text: '$secs sec',
                                  color: theme.accentTxt,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          24.verticalSpace,
          PrimaryText(
            text: 'Log Scripture Read Manually',
            color: theme.accentTxt,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          12.verticalSpace,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CustomTextField(
                  textController: _customReadController,
                  autoFocus: false,
                  hintText: 'e.g., John 3:16 or Romans 8',
                  textInputType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  labelText: '',
                ),
              ),
              12.horizontalSpace,
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryBase,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: _saveCustomReadChapter,
                    child: const PrimaryText(
                      text: 'Log Read',
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          32.verticalSpace,
          
          // Action button
          if ((_quizScopeType == 'chapter' || _quizScopeType == 'deep_learning') && _chapterOrTopicController.text.trim().isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.errorPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.errorPrimary.withOpacity(0.3)),
              ),
              child: const Center(
                child: SecondaryText(
                  text: 'Please specify a Bible chapter to start the quiz.',
                  color: Colors.white70,
                ),
              ),
            ),
          ] else if (_quizScopeType == 'custom' && _chapterOrTopicController.text.trim().isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.errorPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.errorPrimary.withOpacity(0.3)),
              ),
              child: const Center(
                child: SecondaryText(
                  text: 'Please enter a custom topic to start the quiz.',
                  color: Colors.white70,
                ),
              ),
            ),
          ] else ...[
            CustomButton(
              label: 'Start Quiz',
              onPressed: _generateQuiz,
            ),
          ],
          120.verticalSpace,
        ],
      ),
    );
  }

  String _getScopeFriendlyName(String scopeType) {
    switch (scopeType) {
      case 'general':
        return 'General Bible Knowledge';
      case 'chapter':
        final val = _chapterOrTopicController.text.trim();
        return 'Specific Chapter Study${val.isNotEmpty ? ": $val" : ""}';
      case 'deep_learning':
        final val = _chapterOrTopicController.text.trim();
        return 'Deep Learning & Application${val.isNotEmpty ? ": $val" : ""}';
      case 'tech':
        return 'Technology & Coding';
      case 'science':
        return 'Science & Physics';
      case 'english':
        return 'English & Literature';
      case 'economics':
        return 'Economics & Finance';
      case 'mindfulness':
        return 'Personality & Mindfulness';
      case 'custom':
        final val = _chapterOrTopicController.text.trim();
        return 'Custom Topic${val.isNotEmpty ? ": $val" : ""}';
      default:
        return 'General Bible Knowledge';
    }
  }

  String _getScopeDescription(String scopeType) {
    switch (scopeType) {
      case 'general':
        return 'Covers Old and New Testament questions';
      case 'chapter':
        return 'Test yourself on a specific Bible book & chapter';
      case 'deep_learning':
        return 'Critical thinking and life application questions based on a specific chapter';
      case 'tech':
        return 'Questions about software engineering, programming, and tech';
      case 'science':
        return 'Questions about physics, chemistry, astronomy, and biology';
      case 'english':
        return 'Questions about grammar, classic literature, and vocabulary';
      case 'economics':
        return 'Questions about finance, economics, and business';
      case 'mindfulness':
        return 'Questions about mindfulness, positive psychology, and emotional intelligence';
      case 'custom':
        return 'Test yourself on any custom topic you specify';
      default:
        return 'Covers Old and New Testament questions';
    }
  }

  Widget _buildActiveQuiz(AppTheme theme) {
    if (_quizFinished) {
      return _buildQuizFinishedScreen(theme);
    }

    final currentQuestion = _quizQuestions[_currentQuestionIndex];
    final questionText = currentQuestion['question'] as String;
    final options = List<String>.from(currentQuestion['options']);
    final correctAnswerIndex = currentQuestion['answer'] as int;
    final explanation = currentQuestion['explanation'] as String;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SecondaryText(
                text: 'Question ${_currentQuestionIndex + 1} of ${_quizQuestions.length} (${_quizQuestions.length - (_currentQuestionIndex + 1)} remaining)',
                color: theme.accentTxt.withOpacity(0.6),
                fontWeight: FontWeight.bold,
              ),
              SecondaryText(
                text: 'Score: $_score',
                color: theme.primaryBase,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          12.verticalSpace,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _quizQuestions.length,
              minHeight: 6,
              backgroundColor: theme.accentTxt.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryBase),
            ),
          ),
          if (_isTimed) ...[
            16.verticalSpace,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer,
                  color: _secondsRemainingForQuestion <= 3 ? theme.errorPrimary : theme.primaryBase,
                  size: 20,
                ),
                8.horizontalSpace,
                PrimaryText(
                  text: '$_secondsRemainingForQuestion seconds remaining',
                  color: _secondsRemainingForQuestion <= 3 ? theme.errorPrimary : theme.accentTxt,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ],
            ),
          ],
          32.verticalSpace,

          // Question Card
          GlassContainer(
            padding: const EdgeInsets.all(20),
            gradient: theme.glassGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrimaryText(
                  text: questionText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFCCFF00),
                ),
                if (_quizScopeType == 'deep_learning') ...[
                  12.verticalSpace,
                  const Divider(color: Colors.white12, height: 1),
                  12.verticalSpace,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Share button
                      IconButton(
                        icon: const Icon(Icons.share, size: 18),
                        color: theme.accentTxt.withOpacity(0.7),
                        tooltip: 'Share Question',
                        onPressed: () => _shareQuestion(currentQuestion),
                      ),
                      12.horizontalSpace,
                      // Save to Journal button
                      IconButton(
                        icon: Icon(
                          _savedQuestions.contains(questionText) 
                              ? Icons.bookmark 
                              : Icons.bookmark_border, 
                          size: 18,
                        ),
                        color: _savedQuestions.contains(questionText) 
                            ? theme.primaryBase 
                            : theme.accentTxt.withOpacity(0.7),
                        tooltip: 'Save to Journal',
                        onPressed: () => _saveQuestionToJournal(currentQuestion),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          24.verticalSpace,

          // Options list
          ...List.generate(options.length, (index) {
            final isSelected = _selectedAnswerIndex == index;
            Color borderColor = Colors.white12;
            Color? tileColor;

            if (_isAnswerSubmitted) {
              if (index == correctAnswerIndex) {
                borderColor = theme.successPrimary;
                tileColor = theme.successPrimary.withOpacity(0.15);
              } else if (isSelected) {
                borderColor = theme.errorPrimary;
                tileColor = theme.errorPrimary.withOpacity(0.15);
              }
            } else if (isSelected) {
              borderColor = theme.primaryBase;
              tileColor = theme.primaryBase.withOpacity(0.1);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GlassContainer(
                padding: const EdgeInsets.all(16),
                color: tileColor,
                border: Border.all(color: borderColor, width: isSelected || _isAnswerSubmitted ? 2.0 : 1.0),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? theme.primaryBase : theme.accentTxt.withOpacity(0.05),
                        border: Border.all(color: isSelected ? theme.primaryBase : Colors.white24),
                      ),
                      child: Center(
                        child: PrimaryText(
                          text: String.fromCharCode(65 + index), // A, B, C, D
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : theme.accentTxt,
                        ),
                      ),
                    ),
                    16.horizontalSpace,
                    Expanded(
                      child: SecondaryText(
                        text: options[index],
                        fontSize: 14,
                        color: theme.accentTxt,
                      ),
                    ),
                  ],
                ),
              ).rippleClick(() {
                if (!_isAnswerSubmitted) {
                  if (_isTimed) {
                    _selectAndSubmitTimedAnswer(index);
                  } else {
                    setState(() => _selectedAnswerIndex = index);
                  }
                }
              }),
            );
          }),

          32.verticalSpace,

          // Action buttons
          if (!_isAnswerSubmitted)
            Row(
              children: [
                TextButton(
                  onPressed: _confirmCancelQuiz,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: SecondaryText(
                    text: 'Cancel',
                    color: theme.accentTxt.withOpacity(0.5),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                12.horizontalSpace,
                Expanded(
                  child: CustomButton(
                    key: const ValueKey('submit_answer_button'),
                    label: 'Submit Answer',
                    onPressed: _selectedAnswerIndex != null ? _submitAnswer : null,
                  ),
                ),
              ],
            )
          else ...[
            // Explanation box
            GlassContainer(
              padding: const EdgeInsets.all(16),
              border: Border.all(color: theme.primaryBase.withOpacity(0.2)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedAnswerIndex == correctAnswerIndex
                            ? Icons.check_circle
                            : (_selectedAnswerIndex == -1 ? Icons.timer_off : Icons.error),
                        color: _selectedAnswerIndex == correctAnswerIndex ? theme.successPrimary : theme.errorPrimary,
                        size: 20,
                      ),
                      8.horizontalSpace,
                      PrimaryText(
                        text: _selectedAnswerIndex == correctAnswerIndex
                            ? 'Correct!'
                            : (_selectedAnswerIndex == -1 ? "Time's Up!" : 'Incorrect'),
                        fontWeight: FontWeight.bold,
                        color: _selectedAnswerIndex == correctAnswerIndex ? theme.successPrimary : theme.errorPrimary,
                      ),
                    ],
                  ),
                  12.verticalSpace,
                  SecondaryText(
                    text: explanation,
                    color: theme.accentTxt.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ],
              ),
            ),
            24.verticalSpace,
            Row(
              children: [
                TextButton(
                  onPressed: _confirmCancelQuiz,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: SecondaryText(
                    text: 'Cancel',
                    color: theme.accentTxt.withOpacity(0.5),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                12.horizontalSpace,
                Expanded(
                  child: CustomButton(
                    key: const ValueKey('next_question_button'),
                    label: _currentQuestionIndex < _quizQuestions.length - 1 ? 'Next Question' : 'Finish Quiz',
                    onPressed: _nextQuestion,
                  ),
                ),
              ],
            ),
          ],
          120.verticalSpace,
        ],
      ),
    );
  }

  Widget _buildQuizFinishedScreen(AppTheme theme) {
    final authStore = context.read<AppAuthProvider>();
    final ratio = _score / _quizQuestions.length;
    String feedback = 'Good effort! Study more scripture chapters to earn a perfect score.';
    if (ratio == 1.0) {
      feedback = 'Perfect! You have demonstrated exceptional Bible knowledge!';
    } else if (ratio >= 0.7) {
      feedback = 'Great job! You have a solid grasp on scripture.';
    }

    final bonusXp = _score * 4;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.stars, color: theme.primaryBase, size: 80),
          16.verticalSpace,
          PrimaryText(
            text: 'Quiz Completed!',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.accentTxt,
          ),
          24.verticalSpace,
          GlassContainer(
            padding: const EdgeInsets.all(24),
            gradient: theme.glassGradient,
            child: Column(
              children: [
                PrimaryText(
                  text: '$_score / ${_quizQuestions.length}',
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryBase,
                ),
                12.verticalSpace,
                SecondaryText(
                  text: feedback,
                  textAlign: TextAlign.center,
                  color: theme.accentTxt.withOpacity(0.8),
                ),
                16.verticalSpace,
                const Divider(color: Colors.white12),
                16.verticalSpace,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flash_on, color: Colors.orange, size: 20),
                    8.horizontalSpace,
                    PrimaryText(
                      text: '+$bonusXp Quiz XP Awarded',
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          32.verticalSpace,
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'Share Score Card',
                  onPressed: () {
                    final downloadUrl = ConfigService().updateUrl;
                    final scopeName = _getScopeFriendlyName(_quizScopeType);
                    final isBible = _quizScopeType == 'general' || _quizScopeType == 'chapter' || _quizScopeType == 'deep_learning';
                    final emoji = isBible ? ' 📖' : '';
                    ShareService.captureAndShare(
                      context,
                      text: "$scopeName Quiz completed on MindPilot!$emoji Score: $_score/${_quizQuestions.length}. Ready to test your knowledge and build focus? Join me on MindPilot!\n\nDownload: $downloadUrl",
                      widget: ShareableCard(
                        mode: ShareableCardMode.insight,
                        insightTitle: '$scopeName Quiz Score: $_score/${_quizQuestions.length}',
                        insightContent: 'I scored $_score out of ${_quizQuestions.length} questions on the MindPilot $scopeName Quiz! Knowledge level: ${_score == _quizQuestions.length ? "Master 🌟" : "Scholar 📖"}.',
                        userName: authStore.user?.displayName,
                      ),
                    );
                  },
                  isGlass: true,
                ),
              ),
              12.horizontalSpace,
              Expanded(
                child: CustomButton(
                  label: 'Close',
                  onPressed: () {
                    _questionTimer?.cancel();
                    setState(() {
                      _quizQuestions = [];
                      _currentQuestionIndex = 0;
                      _selectedAnswerIndex = null;
                      _isAnswerSubmitted = false;
                      _score = 0;
                      _quizFinished = false;
                    });
                  },
                ),
              ),
            ],
          ),
          120.verticalSpace,
        ],
      ),
    );
  }
  Widget _colorPaletteOption(Color color, Color activeColor, {bool isReset = false}) {
    final isSelected = isReset ? (_customExplanationColor == null) : (_customExplanationColor == color);
    AppTheme theme = context.watch();
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.white24,
          width: isSelected ? 2.5 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: isReset
          ? Icon(Icons.refresh, size: 10, color: theme.brandDark)
          : null,
    ).rippleClick(() {
      setState(() {
        _customExplanationColor = isReset ? null : color;
      });
    });
  }

  Widget _bibleColorPaletteOption(Color color, Color activeColor, {bool isReset = false}) {
    final isSelected = isReset ? (_customBibleColor == null) : (_customBibleColor == color);
    AppTheme theme = context.watch();
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.white24,
          width: isSelected ? 2.5 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: isReset
          ? Icon(Icons.refresh, size: 10, color: theme.brandDark)
          : null,
    ).rippleClick(() {
      setState(() {
        _customBibleColor = isReset ? null : color;
      });
    });
  }

  Widget _fontSizeOption(String label, String category) {
    final isSelected = _bibleFontSizeCategory == category;
    AppTheme theme = context.watch();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? theme.primaryBase : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? theme.primaryBase : Colors.white12,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : theme.accentTxt,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ).rippleClick(() {
      setState(() {
        _bibleFontSizeCategory = category;
      });
    });
  }

  double _getBibleFontSize() {
    switch (_bibleFontSizeCategory) {
      case 'small':
        return 12.0;
      case 'large':
        return 18.0;
      case 'medium':
      default:
        return 15.0;
    }
  }

  double _getVerseNumberFontSize() {
    switch (_bibleFontSizeCategory) {
      case 'small':
        return 10.0;
      case 'large':
        return 14.0;
      case 'medium':
      default:
        return 12.0;
    }
  }

  void _checkRiddleOrJokeAccessAndGenerate() async {
    final authStore = context.read<AppAuthProvider>();
    final isPro = authStore.isPro;
    final modeKey = _riddlesMode; // 'riddle' or 'joke'

    if (isPro) {
      if (modeKey == 'riddle') {
        AnalyticsService.logRiddleGenerated(isFree: true, count: 0);
      } else {
        AnalyticsService.logJokeGenerated(isFree: true, count: 0);
      }
      _generateRiddleOrJoke();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final lastDateKey = '${modeKey.toUpperCase()}_FREE_LAST_DATE';
    final countKey = '${modeKey.toUpperCase()}_FREE_USED_COUNT';

    final lastDate = prefs.getString(lastDateKey) ?? '';
    int count = prefs.getInt(countKey) ?? 0;

    if (lastDate != todayStr) {
      count = 0;
      await prefs.setString(lastDateKey, todayStr);
      await prefs.setInt(countKey, 0);
    }

    if (count >= 3) {
      if (mounted) {
        AppHelper.watchAdForAction(
          context,
          promptText: 'You have used your 3 free ${modeKey}s for today. Watch a video ad to unlock another one!',
          onReward: () {
            if (modeKey == 'riddle') {
              AnalyticsService.logRiddleGenerated(isFree: false, count: count + 1);
            } else {
              AnalyticsService.logJokeGenerated(isFree: false, count: count + 1);
            }
            _generateRiddleOrJoke();
          },
        );
      }
      return;
    }

    await prefs.setInt(countKey, count + 1);
    if (modeKey == 'riddle') {
      AnalyticsService.logRiddleGenerated(isFree: true, count: count + 1);
    } else {
      AnalyticsService.logJokeGenerated(isFree: true, count: count + 1);
    }
    _generateRiddleOrJoke();
  }

  Future<void> _generateRiddleOrJoke() async {
    setState(() {
      _isLoadingRiddle = true;
      _currentRiddleText = null;
      _currentRiddleAnswer = null;
      _currentRiddleHint = null;
      _currentRiddleExplanation = null;
      _currentJokeSetup = null;
      _currentJokePunchline = null;
      _riddleGuessController.clear();
      _riddleChecked = false;
      _riddleCorrect = false;
      _hintShown = false;
      _punchlineShown = false;
      _jokeRating = null;
    });

    if (!_geminiService.isInitialized) {
      _initializeGemini();
    }

    String categoryText = '';
    if (_riddlesCategory == 'bible') {
      categoryText = 'the Holy Bible (both Old and New Testaments)';
    } else if (_riddlesCategory == 'logic') {
      categoryText = 'logic, critical thinking, and puzzles';
    } else if (_riddlesCategory == 'tech') {
      categoryText = 'technology, coding, computer science, and software engineering';
    } else {
      categoryText = 'general knowledge, science, literature, history, and life';
    }

    String prompt = '';
    String systemInstruction = '';

    if (_riddlesMode == 'riddle') {
      prompt = """
You are a precise riddle generator. Generate exactly 1 riddle about: $categoryText.
The riddle MUST be clever, engaging, and suitable for improving thinking skills.
CRITICAL: No inappropriate, mature, political, or offensive content under any circumstances. Ensure the content is completely clean and constructive.

You MUST format the output ONLY as a valid JSON object. Do not wrap it in markdown code block formatting. Return only raw JSON.
The JSON object must have exactly these keys:
- "riddle": The riddle question text.
- "answer": A short answer word or phrase.
- "hint": A subtle clue or hint.
- "explanation": A brief explanation of the riddle answer.
""";
      systemInstruction = "You are a precise riddle generator. Generate a clever, clean riddle on the chosen category. Return ONLY raw JSON.";
    } else {
      prompt = """
You are a precise joke generator. Generate exactly 1 joke or pun about: $categoryText.
The joke MUST be clean, lighthearted, and funny.
CRITICAL: No inappropriate, mature, political, or offensive content under any circumstances. Ensure the content is completely clean and constructive.

You MUST format the output ONLY as a valid JSON object. Do not wrap it in markdown code block formatting. Return only raw JSON.
The JSON object must have exactly these keys:
- "setup": The joke setup or question.
- "punchline": The punchline or answer.
""";
      systemInstruction = "You are a precise joke generator. Generate a clean, funny joke on the chosen category. Return ONLY raw JSON.";
    }

    try {
      final response = await _geminiService.sendMessageOneShot(prompt, systemInstruction: systemInstruction);
      if (response != null && response.trim().isNotEmpty) {
        String cleanJson = response.trim();
        if (cleanJson.startsWith('```')) {
          final lines = cleanJson.split('\n');
          if (lines.first.startsWith('```')) lines.removeAt(0);
          if (lines.last.startsWith('```')) lines.removeLast();
          cleanJson = lines.join('\n').trim();
        }

        final Map<String, dynamic> decoded = jsonDecode(cleanJson);
        setState(() {
          if (_riddlesMode == 'riddle') {
            _currentRiddleText = decoded['riddle']?.toString() ?? 'What gets wetter the more it dries?';
            _currentRiddleAnswer = decoded['answer']?.toString() ?? 'A towel';
            _currentRiddleHint = decoded['hint']?.toString() ?? 'You use it after a shower.';
            _currentRiddleExplanation = decoded['explanation']?.toString() ?? 'A towel absorbs water to dry things, so it becomes wet.';
          } else {
            _currentJokeSetup = decoded['setup']?.toString() ?? 'Why did the programmer quit their job?';
            _currentJokePunchline = decoded['punchline']?.toString() ?? 'Because they didn\'t get arrays.';
          }
        });
      }
    } catch (e) {
      setState(() {
        if (_riddlesMode == 'riddle') {
          _currentRiddleText = 'I am something when you cut me you cry, what am I?';
          _currentRiddleAnswer = 'An onion';
          _currentRiddleHint = 'Common kitchen vegetable used in cooking.';
          _currentRiddleExplanation = 'Cutting onions releases a chemical that irritates the eyes, causing tears.';
        } else {
          _currentJokeSetup = 'Why did the laptop go to the doctor?';
          _currentJokePunchline = 'Because it had a virus!';
        }
      });
      if (mounted) {
        context.showInAppNotification('Failed to generate. Loaded a default one instead.', type: InAppNotificationType.info);
      }
    } finally {
      setState(() {
        _isLoadingRiddle = false;
      });
    }
  }

  void _checkRiddleGuess() {
    final guess = _riddleGuessController.text.trim().toLowerCase();
    final answer = (_currentRiddleAnswer ?? '').trim().toLowerCase();

    if (guess.isEmpty) {
      context.showInAppNotification('Please enter a guess first.');
      return;
    }

    String cleanStr(String s) {
      var res = s.replaceAll(RegExp(r'[^\w\s]'), '').trim();
      if (res.startsWith('a ')) res = res.substring(2);
      if (res.startsWith('an ')) res = res.substring(3);
      if (res.startsWith('the ')) res = res.substring(4);
      return res.trim();
    }

    final cleanGuess = cleanStr(guess);
    final cleanAnswer = cleanStr(answer);

    setState(() {
      _riddleChecked = true;
      _riddleCorrect = cleanGuess == cleanAnswer || cleanAnswer.contains(cleanGuess) && cleanGuess.length >= 3;
    });

    if (_riddleCorrect) {
      context.showInAppNotification('Spot on! Correct answer 🎉', type: InAppNotificationType.success);
    } else {
      context.showInAppNotification('Not quite! Try again or reveal the hint/answer.', type: InAppNotificationType.error);
    }
  }

  Widget _buildRiddlesTab(AppTheme theme) {
    if (_isLoadingRiddle) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryBase),
                  strokeWidth: 3.0,
                ),
              ),
              32.verticalSpace,
              PrimaryText(
                text: _riddlesMode == 'riddle'
                    ? 'Thinking of a clever riddle for you...'
                    : 'Crafting a funny joke for you...',
                textAlign: TextAlign.center,
                fontSize: 16,
                color: theme.accentTxt.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
        ),
      );
    }

    final hasContent = _riddlesMode == 'riddle' ? _currentRiddleText != null : _currentJokeSetup != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryText(
            text: 'Riddles & Jokes 🌟',
            color: theme.accentTxt,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          12.verticalSpace,
          SecondaryText(
            text: 'Challenge your mind with riddles or relax with lighthearted jokes generated by Gemini AI.',
            color: theme.accentTxt.withOpacity(0.6),
          ),
          20.verticalSpace,

          // Mode Selection
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    gradient: _riddlesMode == 'riddle' ? theme.glassGradient : null,
                    border: Border.all(
                      color: _riddlesMode == 'riddle' ? theme.primaryBase : Colors.white12,
                      width: _riddlesMode == 'riddle' ? 2.0 : 1.0,
                    ),
                    child: Center(
                      child: PrimaryText(
                        text: '🧠 Riddles',
                        color: theme.accentTxt,
                        fontWeight: _riddlesMode == 'riddle' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ).rippleClick(() => setState(() {
                    _riddlesMode = 'riddle';
                    _currentRiddleText = null;
                    _currentJokeSetup = null;
                  })),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    gradient: _riddlesMode == 'joke' ? theme.glassGradient : null,
                    border: Border.all(
                      color: _riddlesMode == 'joke' ? theme.primaryBase : Colors.white12,
                      width: _riddlesMode == 'joke' ? 2.0 : 1.0,
                    ),
                    child: Center(
                      child: PrimaryText(
                        text: '😂 Jokes',
                        color: theme.accentTxt,
                        fontWeight: _riddlesMode == 'joke' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ).rippleClick(() => setState(() {
                    _riddlesMode = 'joke';
                    _currentRiddleText = null;
                    _currentJokeSetup = null;
                  })),
                ),
              ),
            ],
          ),
          20.verticalSpace,

          // Category Chips
          PrimaryText(
            text: 'Choose Category',
            color: theme.accentTxt,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          12.verticalSpace,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _categoryChip('bible', '📖 Bible', theme),
                8.horizontalSpace,
                _categoryChip('logic', '🧠 Logic', theme),
                8.horizontalSpace,
                _categoryChip('tech', '💻 Tech', theme),
                8.horizontalSpace,
                _categoryChip('general', '🌍 General', theme),
              ],
            ),
          ),
          24.verticalSpace,

          // Content Card
          if (!hasContent) ...[
            GlassContainer(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    _riddlesMode == 'riddle' ? Icons.lightbulb_outline : Icons.sentiment_satisfied_alt,
                    size: 48,
                    color: theme.primaryBase,
                  ),
                  16.verticalSpace,
                  PrimaryText(
                    text: _riddlesMode == 'riddle'
                        ? 'Ready for a challenge?'
                        : 'Need a quick laugh?',
                    color: theme.accentTxt,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center,
                  ),
                  8.verticalSpace,
                  SecondaryText(
                    text: _riddlesMode == 'riddle'
                        ? 'Tap below to generate a riddle and test your logic.'
                        : 'Tap below to generate a lighthearted joke.',
                    color: theme.accentTxt.withOpacity(0.6),
                    textAlign: TextAlign.center,
                  ),
                  24.verticalSpace,
                  CustomButton(
                    label: _riddlesMode == 'riddle' ? 'Generate Riddle' : 'Generate Joke',
                    onPressed: _checkRiddleOrJokeAccessAndGenerate,
                  ),
                ],
              ),
            ),
          ] else ...[
            // Active Riddle / Joke Card
            GlassContainer(
              padding: const EdgeInsets.all(20),
              border: Border.all(color: theme.primaryBase.withOpacity(0.3)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Topic label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primaryBase.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: PrimaryText(
                          text: _riddlesCategory.toUpperCase(),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryBase,
                        ),
                      ),
                      Icon(
                        _riddlesMode == 'riddle' ? Icons.help_outline : Icons.sentiment_satisfied,
                        color: theme.primaryBase,
                        size: 18,
                      ),
                    ],
                  ),
                  20.verticalSpace,

                  if (_riddlesMode == 'riddle') ...[
                    // Riddle Question
                    PrimaryText(
                      text: _currentRiddleText ?? '',
                      fontSize: 17,
                      color: theme.accentTxt,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    24.verticalSpace,

                    // Hint Box if visible
                    if (_hintShown && _currentRiddleHint != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb, color: Colors.amber, size: 18),
                            10.horizontalSpace,
                            Expanded(
                              child: SecondaryText(
                                text: 'Hint: $_currentRiddleHint',
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      16.verticalSpace,
                    ],

                    // Input guess field
                    CustomTextField(
                      textController: _riddleGuessController,
                      autoFocus: false,
                      hintText: 'Type your guess here...',
                      textInputType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      labelText: 'Your Guess',
                      labelColor: Colors.white70,
                      textColor: Colors.white,
                      onDone: _checkRiddleGuess,
                    ),
                    16.verticalSpace,

                    // Guess Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: CustomButton(
                            label: 'Check',
                            onPressed: _checkRiddleGuess,
                          ),
                        ),
                        8.horizontalSpace,
                        Expanded(
                          child: CustomButton(
                            label: _hintShown ? 'Hint On' : 'Hint',
                            isOutline: true,
                            borderColor: _hintShown ? Colors.amber : Colors.white24,
                            textColor: _hintShown ? Colors.amber : Colors.white70,
                            onPressed: () => setState(() => _hintShown = true),
                          ),
                        ),
                        8.horizontalSpace,
                        Expanded(
                          child: CustomButton(
                            label: 'Reveal',
                            isOutline: true,
                            borderColor: theme.errorPrimary.withOpacity(0.5),
                            textColor: theme.errorPrimary,
                            onPressed: () {
                              setState(() {
                                _riddleChecked = true;
                                _riddleCorrect = false;
                                _riddleGuessController.text = _currentRiddleAnswer ?? '';
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    // Explanation / Answer Display
                    if (_riddleChecked) ...[
                      20.verticalSpace,
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _riddleCorrect 
                              ? theme.successPrimary.withOpacity(0.15) 
                              : theme.errorPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _riddleCorrect ? theme.successPrimary : theme.errorPrimary.withOpacity(0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _riddleCorrect ? Icons.check_circle : Icons.info_outline,
                                  color: _riddleCorrect ? theme.successPrimary : theme.errorPrimary,
                                  size: 20,
                                ),
                                8.horizontalSpace,
                                PrimaryText(
                                  text: _riddleCorrect ? 'Correct!' : 'Answer Revealed',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _riddleCorrect ? theme.successPrimary : theme.errorPrimary,
                                ),
                              ],
                            ),
                            8.verticalSpace,
                            PrimaryText(
                              text: 'Answer: $_currentRiddleAnswer',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.accentTxt,
                            ),
                            if (_currentRiddleExplanation != null) ...[
                              8.verticalSpace,
                              SecondaryText(
                                text: _currentRiddleExplanation!,
                                fontSize: 13,
                                color: theme.accentTxt.withOpacity(0.7),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    // Joke Setup
                    PrimaryText(
                      text: _currentJokeSetup ?? '',
                      fontSize: 17,
                      color: theme.accentTxt,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    24.verticalSpace,

                    // Punchline
                    if (!_punchlineShown) ...[
                      CustomButton(
                        label: 'Reveal Punchline 🎭',
                        backgroundColor: theme.primaryBase,
                        textColor: Colors.black,
                        onPressed: () => setState(() => _punchlineShown = true),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.primaryBase.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.primaryBase.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PrimaryText(
                              text: _currentJokePunchline ?? '',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryBase,
                              height: 1.3,
                            ),
                          ],
                        ),
                      ),
                      20.verticalSpace,

                      // Joke interaction rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SecondaryText(
                            text: 'Was this funny?',
                            color: theme.accentTxt.withOpacity(0.6),
                          ),
                          16.horizontalSpace,
                          _jokeRatingButton('Funny 😂', 'funny', theme),
                          8.horizontalSpace,
                          _jokeRatingButton('Meh 😐', 'meh', theme),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
            24.verticalSpace,
            CustomButton(
              label: _riddlesMode == 'riddle' ? 'Next Riddle ➡️' : 'Next Joke ➡️',
              isOutline: true,
              onPressed: _checkRiddleOrJokeAccessAndGenerate,
            ),
          ],
          60.verticalSpace,
        ],
      ),
    );
  }

  Widget _categoryChip(String catKey, String label, AppTheme theme) {
    final isSelected = _riddlesCategory == catKey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? theme.primaryBase : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? theme.primaryBase : Colors.white12,
        ),
      ),
      child: PrimaryText(
        text: label,
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.black : theme.accentTxt,
      ),
    ).rippleClick(() => setState(() {
      _riddlesCategory = catKey;
      _currentRiddleText = null;
      _currentJokeSetup = null;
    }));
  }

  Widget _jokeRatingButton(String label, String ratingKey, AppTheme theme) {
    final isSelected = _jokeRating == ratingKey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? theme.primaryBase.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? theme.primaryBase : Colors.white12,
        ),
      ),
      child: SecondaryText(
        text: label,
        color: isSelected ? theme.primaryBase : theme.accentTxt.withOpacity(0.7),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    ).rippleClick(() {
      if (_jokeRating != null) return;
      setState(() => _jokeRating = ratingKey);
      context.showInAppNotification(
        ratingKey == 'funny' ? 'Glad you liked it! 😄' : 'Thanks for the feedback! We\'ll try harder.',
        type: InAppNotificationType.success,
      );
    });
  }
}
