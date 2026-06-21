import 'dart:convert';
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

  // Quiz tab state
  int _questionCount = 5;
  String _quizScope = 'General Bible Knowledge'; // or 'Last Read Chapter'
  String? _lastReadChapter;
  bool _isLoadingQuiz = false;
  List<Map<String, dynamic>> _quizQuestions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _isAnswerSubmitted = false;
  int _score = 0;
  bool _quizFinished = false;
  int _selectionVersion = 0;
  final Set<String> _savedQuestions = {};

  final TextEditingController _customReadController = TextEditingController();

  final List<String> _books = [
    'Genesis', 'Exodus', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Isaiah', 
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans', 'Philippians', 'Revelation'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeGemini();
    _loadLastReadChapter();
    _fetchBibleChapter();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customReadController.dispose();
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
      });
    }
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

    if (_quizScope == 'Deep Learning & Application') {
      if (!isPro) {
        AppHelper.watchAdForAction(
          context,
          promptText: 'Watch a video ad to unlock this Deep Learning & Application Quiz session.',
          onReward: () {
            _startQuizGeneration();
          },
        );
        return;
      }
    } else {
      if (!isPro) {
        final prefs = await SharedPreferences.getInstance();
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final lastDate = prefs.getString('QUIZ_FREE_LAST_DATE') ?? '';
        int count = prefs.getInt('QUIZ_FREE_USED_COUNT') ?? 0;

        if (lastDate != todayStr) {
          count = 0;
          await prefs.setString('QUIZ_FREE_LAST_DATE', todayStr);
          await prefs.setInt('QUIZ_FREE_USED_COUNT', 0);
        }

        if (count >= 3) {
          if (mounted) {
            AppHelper.watchAdForAction(
              context,
              promptText: 'You have used your 3 free quiz sessions for today. Watch a video ad to unlock another session!',
              onReward: () {
                _startQuizGeneration();
              },
            );
          }
          return;
        }

        // Increment count
        await prefs.setInt('QUIZ_FREE_USED_COUNT', count + 1);
      }
    }

    _startQuizGeneration();
  }

  Future<void> _startQuizGeneration() async {
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

    if (_quizScope == 'Deep Learning & Application' && _lastReadChapter != null) {
      targetContext = 'application and critical thinking lessons inspired by the Bible chapter "$_lastReadChapter"';
      styleInstructions = """
The questions should NOT be direct trivia or fact recall from the chapter (e.g., do not ask who said what or specific verse numbers).
Instead, generate **learnable, reflective, and application-oriented questions** that make the user think widely about the moral, philosophical, or practical life lessons of the chapter, and explain what they have learnt.
The 4 options (answers) must fall around the practical application of those concepts, and the correct option should represent the most meaningful, constructive takeaway or life application.
Ensure the "explanation" for each question explains the lesson clearly and how it relates to what they read.
""";
    } else if (_quizScope == 'Last Read Chapter' && _lastReadChapter != null) {
      targetContext = 'the Bible chapter "$_lastReadChapter"';
      styleInstructions = "Generate standard comprehension and contextual questions from this chapter.";
    } else {
      targetContext = 'general Bible knowledge (covering both Old and New Testaments)';
      styleInstructions = "Generate standard Bible trivia and knowledge questions.";
    }

    final prompt = """
You are the **MindPilot Bible Quiz Generator**. Generate a JSON array of multiple choice questions based on: $targetContext.
The JSON array must contain exactly $_questionCount questions.

$styleInstructions

Each question object in the array must have the following keys:
- "question": The question text.
- "options": An array of exactly 4 strings for choices.
- "answer": The index (0 to 3) of the correct option.
- "explanation": A brief explanation of the correct answer.

Return ONLY the raw JSON array. Do not include markdown code block formatting (no ```json or ```). Just raw JSON.
""";

    try {
      final response = await _geminiService.sendMessage(prompt);
      if (response != null) {
        String cleanJson = response.trim();
        if (cleanJson.startsWith('```')) {
          final lines = cleanJson.split('\n');
          if (lines.first.startsWith('```')) lines.removeAt(0);
          if (lines.last.startsWith('```')) lines.removeLast();
          cleanJson = lines.join('\n').trim();
        }
        
        final List decoded = jsonDecode(cleanJson);
        setState(() {
          _quizQuestions = List<Map<String, dynamic>>.from(decoded);
        });
      }
    } catch (e) {
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
      if (mounted) {
        context.showInAppNotification('Dynamic quiz error. Loaded fallback Bible Quiz.', type: InAppNotificationType.info);
      }
    } finally {
      if (mounted) {
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

    final title = 'Scripture Reflection: ${_lastReadChapter ?? "Bible study"}';
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
    setState(() {
      if (_currentQuestionIndex < _quizQuestions.length - 1) {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _isAnswerSubmitted = false;
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
      final quiz = {
        'date': DateTime.now().toIso8601String(),
        'chapter': _quizScope == 'General Bible Knowledge' ? 'General Knowledge' : (_lastReadChapter ?? 'Unknown'),
        'score': _score,
        'total_questions': _quizQuestions.length,
        'quiz_type': _quizScope,
      };
      await DatabaseHelper().insertQuizResult(quiz);
    } catch (e) {
      debugPrint('Error logging quiz results: $e');
    }
  }

  void _confirmCancelQuiz() {
    showDialog(
      context: context,
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
              onPressed: () => Navigator.pop(ctx),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadTab(AppTheme theme) {
    final activeColor = _customExplanationColor ?? theme.accentTxt;
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
                              _selectedChapter = 1;
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
                        items: List.generate(50, (index) => index + 1)
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
                                  fontSize: 12,
                                ),
                              ),
                              TextSpan(
                                text: '${v['text']}'.trim(),
                                style: TextStyle(
                                  color: theme.accentTxt.withOpacity(0.9),
                                  fontSize: 14,
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
                text: 'Your questions are being generated, please sit back and be prepared...',
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
          24.verticalSpace,
          
          // Scope selection
          PrimaryText(
            text: 'Quiz Scope',
            color: theme.accentTxt,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          12.verticalSpace,
          _scopeTile(theme, 'General Bible Knowledge', 'Covers Old and New Testament questions'),
          12.verticalSpace,
          _scopeTile(theme, 'Last Read Chapter', 'Test yourself on: ${_lastReadChapter ?? "No chapter read yet"}'),
          12.verticalSpace,
          _scopeTile(theme, 'Deep Learning & Application', 'Critical thinking and life application questions based on: ${_lastReadChapter ?? "No chapter read yet"}'),
          
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
          if ((_quizScope == 'Last Read Chapter' || _quizScope == 'Deep Learning & Application') && _lastReadChapter == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.errorPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.errorPrimary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  SecondaryText(
                    text: 'Please read or manually log a Bible chapter first to use this quiz mode.',
                    color: theme.accentTxt,
                    textAlign: TextAlign.center,
                  ),
                  12.verticalSpace,
                  CustomButton(
                    label: 'Go Read a Chapter',
                    onPressed: () => _tabController.animateTo(0),
                  ),
                ],
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

  Widget _scopeTile(AppTheme theme, String scope, String desc) {
    final isSelected = _quizScope == scope;
    final isPro = context.read<AppAuthProvider>().isPro;
    final isPremiumOnly = scope == 'Deep Learning & Application';

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      gradient: isSelected ? theme.glassGradient : null,
      border: Border.all(
        color: isSelected ? theme.primaryBase : Colors.white12,
        width: isSelected ? 2.0 : 1.0,
      ),
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isSelected ? theme.primaryBase : theme.accentTxt.withOpacity(0.4),
          ),
          16.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PrimaryText(
                      text: scope,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.accentTxt,
                    ),
                    if (isPremiumOnly) ...[
                      8.horizontalSpace,
                      const Icon(
                        Icons.star,
                        color: Color(0xFFF59E0B),
                        size: 14,
                      ),
                    ],
                  ],
                ),
                4.verticalSpace,
                SecondaryText(
                  text: desc,
                  fontSize: 11,
                  color: theme.accentTxt.withOpacity(0.5),
                ),
              ],
            ),
          ),
          if (isPremiumOnly && !isPro)
            Icon(
              Icons.lock_outline,
              color: theme.accentTxt.withOpacity(0.6),
              size: 18,
            ),
        ],
      ),
    ).rippleClick(() {
      setState(() => _quizScope = scope);
    });
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
                text: 'Question ${_currentQuestionIndex + 1} of ${_quizQuestions.length}',
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
                  color: theme.accentTxt,
                ),
                if (_quizScope == 'Deep Learning & Application') ...[
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
                  setState(() => _selectedAnswerIndex = index);
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
                        _selectedAnswerIndex == correctAnswerIndex ? Icons.check_circle : Icons.error,
                        color: _selectedAnswerIndex == correctAnswerIndex ? theme.successPrimary : theme.errorPrimary,
                        size: 20,
                      ),
                      8.horizontalSpace,
                      PrimaryText(
                        text: _selectedAnswerIndex == correctAnswerIndex ? 'Correct!' : 'Incorrect',
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
                    ShareService.captureAndShare(
                      context,
                      text: "Bible Quiz completed on MindPilot! 📖 Score: $_score/${_quizQuestions.length}. Ready to test your Bible knowledge and build focus? Join me on MindPilot!\n\nDownload: $downloadUrl",
                      widget: ShareableCard(
                        mode: ShareableCardMode.insight,
                        insightTitle: 'Bible Quiz Score: $_score/${_quizQuestions.length}',
                        insightContent: 'I scored $_score out of ${_quizQuestions.length} questions on the MindPilot Bible Quiz! Knowledge level: ${_score == _quizQuestions.length ? "Master 🌟" : "Scholar 📖"}.',
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
}
