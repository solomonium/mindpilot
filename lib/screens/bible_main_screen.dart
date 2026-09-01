import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:mindpilot/export.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  String _selectedTranslation = 'NLT';
  final Map<String, String> _translations = {
    'NLT': 'NLT',
    'NIV': 'NIV',
    'ESV': 'ESV',
    'KJV': 'KJV',
    'WEB': 'WEB',
  };
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
    try {
      context.read<GroupQuizProvider>().leaveVoiceRoom();
    } catch (_) {}
  }

  void _connectSoloQuizVoiceRoom() {
    try {
      final provider = context.read<GroupQuizProvider>();
      String normalizedScope = _quizScopeType;
      if (_quizScopeType == 'chapter' || _quizScopeType == 'deep_learning' || _quizScopeType == 'custom') {
        normalizedScope = _chapterOrTopicController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      }
      if (normalizedScope.isEmpty) {
        normalizedScope = 'general';
      }
      final roomName = 'study_room_$normalizedScope';
      provider.joinCustomVoiceRoom(roomName);
    } catch (e) {
      safePrint("Error joining solo quiz voice room: $e");
    }
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

  // Voice quiz mode state
  bool _voiceQuizMode = false;
  final FlutterTts _quizTts = FlutterTts();
  final stt.SpeechToText _quizSpeech = stt.SpeechToText();
  bool _isQuizSpeechListening = false;

  // Bible & Explanation TTS state
  final FlutterTts _bibleTts = FlutterTts();
  String _bibleTtsState = 'stopped'; // 'stopped', 'playing', 'paused'
  String _explanationTtsState = 'stopped'; // 'stopped', 'playing', 'paused'
  String _riddleJokeTtsState = 'stopped'; // 'stopped', 'playing', 'paused'
  double _bibleSpeechRate = 0.48;

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
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _bibleTts.stop();
        _quizTts.stop();
        if (mounted) {
          setState(() {
            _bibleTtsState = 'stopped';
            _explanationTtsState = 'stopped';
            _riddleJokeTtsState = 'stopped';
          });
        }
      }
    });
    _initializeGemini();
    _initData();
    _initAudioContext();
    _initVoiceQuiz();
  }

  Future<void> _loadSavedTranslation() async {
    final val = await SharedPrefs.getString('SELECTED_BIBLE_TRANSLATION');
    if (mounted && val.isNotEmpty && _translations.containsKey(val)) {
      setState(() {
        _selectedTranslation = val;
      });
    }
  }

  Future<void> _initData() async {
    await _loadSavedTranslation();
    await _loadLastReadChapter();
    await _fetchBibleChapter();
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRate = prefs.getDouble('bible_speech_rate');
      if (savedRate != null) {
        setState(() {
          _bibleSpeechRate = savedRate;
        });
      }
    } catch (e) {
      safePrint("Error loading bible speech rate: $e");
    }
  }

  Future<void> _saveSpeechRate(double rate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('bible_speech_rate', rate);
    } catch (e) {
      safePrint("Error saving bible speech rate: $e");
    }
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
    _quizTts.stop();
    _quizSpeech.stop();
    _bibleTts.stop();
    try {
      context.read<GroupQuizProvider>().leaveVoiceRoom();
    } catch (_) {}
    super.dispose();
  }

  void _initializeGemini() {
    final apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
    _geminiService.init(apiKey);
  }

  void _initVoiceQuiz() async {
    try {
      await _quizSpeech.initialize();
    } catch (e) {
      safePrint("Quiz Speech failed to init: $e");
    }
  }

  Future<void> _toggleBibleTts({bool isStop = false}) async {
    if (isStop) {
      await _bibleTts.stop();
      if (mounted) setState(() => _bibleTtsState = 'stopped');
      return;
    }

    if (_bibleTtsState == 'playing') {
      await _bibleTts.pause();
      if (mounted) setState(() => _bibleTtsState = 'paused');
    } else {
      if (_chapterText == null || _chapterText!.trim().isEmpty) return;
      
      // Stop quiz or other TTS first
      await _quizTts.stop();
      _toggleExplanationTts(isStop: true);
      _toggleRiddleOrJokeTts(isStop: true);

      final wasPaused = _bibleTtsState == 'paused';
      if (mounted) setState(() => _bibleTtsState = 'playing');
      try {
        if (!wasPaused) {
          await _bibleTts.stop();
          await _bibleTts.setLanguage("en-US");
          await _bibleTts.setSpeechRate(_bibleSpeechRate);
          _bibleTts.setCompletionHandler(() {
            if (mounted) setState(() => _bibleTtsState = 'stopped');
          });
        }
        
        String spokenPassage;
        if (_verses.isNotEmpty) {
          spokenPassage = _verses.map((v) {
            String text = (v['text'] ?? '').toString();
            text = text.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'[*#_`]'), '');
            // Strip leading verse numbers e.g. "1 ", "1. ", "[1] ", "(1) ", "1:1 "
            text = text.replaceAll(RegExp(r'^\s*\(?\[?\d+(?:\:\d+)?\]?\)?[\.\:]?\s*'), '');
            return text.trim();
          }).where((t) => t.isNotEmpty).join(' ');
        } else {
          String text = _chapterText ?? '';
          text = text.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'[*#_`]'), '');
          // Strip verse numbers at start of text or lines
          text = text.replaceAll(RegExp(r'(?:^|\s)\(?\[?\d+(?:\:\d+)?\]?\)?[\.\:]?(?=\s+[A-Za-z"“\(])'), ' ');
          spokenPassage = text.replaceAll(RegExp(r'\s+'), ' ').trim();
        }

        String textToSpeak = "$_selectedBook chapter $_selectedChapter. $spokenPassage";
        await _bibleTts.speak(textToSpeak.replaceAll(RegExp(r'[*#_`]'), ''));
      } catch (e) {
        safePrint("TTS Read Chapter Error: $e");
        if (mounted) setState(() => _bibleTtsState = 'stopped');
      }
    }
  }

  Future<void> _toggleExplanationTts({bool isStop = false}) async {
    if (isStop) {
      await _bibleTts.stop();
      if (mounted) setState(() => _explanationTtsState = 'stopped');
      return;
    }

    if (_explanationTtsState == 'playing') {
      await _bibleTts.pause();
      if (mounted) setState(() => _explanationTtsState = 'paused');
    } else {
      if (_aiExplanation == null || _aiExplanation!.trim().isEmpty) return;

      // Stop quiz or other TTS first
      await _quizTts.stop();
      _toggleBibleTts(isStop: true);
      _toggleRiddleOrJokeTts(isStop: true);

      final wasPaused = _explanationTtsState == 'paused';
      if (mounted) setState(() => _explanationTtsState = 'playing');
      try {
        if (!wasPaused) {
          await _bibleTts.stop();
          await _bibleTts.setLanguage("en-US");
          await _bibleTts.setSpeechRate(_bibleSpeechRate);
          _bibleTts.setCompletionHandler(() {
            if (mounted) setState(() => _explanationTtsState = 'stopped');
          });
        }
        
        await _bibleTts.speak(_aiExplanation!.replaceAll(RegExp(r'[*#_`]'), ''));
      } catch (e) {
        safePrint("TTS Read Explanation Error: $e");
        if (mounted) setState(() => _explanationTtsState = 'stopped');
      }
    }
  }

  Future<void> _toggleRiddleOrJokeTts({bool isStop = false}) async {
    if (isStop) {
      await _bibleTts.stop();
      if (mounted) setState(() => _riddleJokeTtsState = 'stopped');
      return;
    }

    if (_riddleJokeTtsState == 'playing') {
      await _bibleTts.pause();
      if (mounted) setState(() => _riddleJokeTtsState = 'paused');
    } else {
      String textToSpeak = "";
      if (_riddlesMode == 'riddle') {
        if (_currentRiddleText == null || _currentRiddleText!.trim().isEmpty) return;
        textToSpeak = "Here is a ${_riddlesCategory} riddle: $_currentRiddleText. ";
        if (_riddleChecked && _currentRiddleAnswer != null) {
          textToSpeak += "The answer is $_currentRiddleAnswer. ";
          if (_currentRiddleExplanation != null) {
            textToSpeak += "Explanation: $_currentRiddleExplanation. ";
          }
        }
      } else {
        if (_currentJokeSetup == null || _currentJokeSetup!.trim().isEmpty) return;
        textToSpeak = "Here is a ${_riddlesCategory} joke: $_currentJokeSetup. ";
        if (_punchlineShown && _currentJokePunchline != null) {
          textToSpeak += "Punchline: $_currentJokePunchline. ";
        }
      }

      if (textToSpeak.trim().isEmpty) return;

      // Stop quiz or other TTS first
      await _quizTts.stop();
      _toggleBibleTts(isStop: true);
      _toggleExplanationTts(isStop: true);

      final wasPaused = _riddleJokeTtsState == 'paused';
      if (mounted) setState(() => _riddleJokeTtsState = 'playing');
      try {
        if (!wasPaused) {
          await _bibleTts.stop();
          await _bibleTts.setLanguage("en-US");
          await _bibleTts.setSpeechRate(_bibleSpeechRate);
          _bibleTts.setCompletionHandler(() {
            if (mounted) setState(() => _riddleJokeTtsState = 'stopped');
          });
        }
        
        await _bibleTts.speak(textToSpeak.replaceAll(RegExp(r'[*#_`]'), ''));
      } catch (e) {
        safePrint("TTS Riddle/Joke Error: $e");
        if (mounted) setState(() => _riddleJokeTtsState = 'stopped');
      }
    }
  }

  void _speakActiveQuestion() async {
    if (!_voiceQuizMode || _quizQuestions.isEmpty || _quizFinished) return;
    try {
      final currentQuestion = _quizQuestions[_currentQuestionIndex];
      final questionText = currentQuestion['question'] as String;

      String textToSpeak = "Question ${_currentQuestionIndex + 1}. $questionText. ";

      await _quizTts.stop();
      await _quizTts.setLanguage("en-US");
      await _quizTts.setSpeechRate(0.45);
      
      // Stop listening while speaking is active
      if (_isQuizSpeechListening) {
        await _quizSpeech.stop();
        if (mounted) setState(() => _isQuizSpeechListening = false);
      }

      _quizTts.setCompletionHandler(() {
        if (mounted) {
          _onQuestionSpeechCompleted();
        }
      });

      await _quizTts.speak(textToSpeak.replaceAll(RegExp(r'[*#_`]'), ''));
    } catch (e) {
      safePrint("Error speaking question: $e");
    }
  }

  void _onQuestionSpeechCompleted() async {
    if (!_voiceQuizMode || _quizQuestions.isEmpty || _quizFinished) return;
    
    // Start the timer after the question is completed, but before options are read
    _startQuestionTimer();

    try {
      final currentQuestion = _quizQuestions[_currentQuestionIndex];
      final options = List<String>.from(currentQuestion['options']);
      final List<String> letters = ["A", "B", "C", "D"];
      
      String optionsText = "";
      for (int i = 0; i < options.length; i++) {
        optionsText += "Option ${letters[i]}: ${options[i]}. ";
      }

      _quizTts.setCompletionHandler(() {
        if (mounted) {
          _onOptionsSpeechCompleted();
        }
      });

      await _quizTts.speak(optionsText.replaceAll(RegExp(r'[*#_`]'), ''));
    } catch (e) {
      safePrint("Error speaking options: $e");
    }
  }

  void _onOptionsSpeechCompleted() {
    if (mounted && _voiceQuizMode && !_isAnswerSubmitted) {
      _listenForAnswer();
    }
  }

  void _listenForAnswer() async {
    if (!_voiceQuizMode || _isAnswerSubmitted || _quizFinished) return;
    try {
      bool available = await _quizSpeech.initialize(
        onStatus: (status) {
          safePrint("Quiz STT status: $status");
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isQuizSpeechListening) {
              setState(() => _isQuizSpeechListening = false);
            }
          }
        },
        onError: (error) => safePrint("Quiz STT error: $error"),
      );
      if (available) {
        setState(() => _isQuizSpeechListening = true);
        await _quizSpeech.listen(
          onResult: (val) {
            final spoken = val.recognizedWords.toLowerCase().trim();
            safePrint("Spoken: $spoken");
            _processSpokenAnswer(spoken);
          },
          listenOptions: stt.SpeechListenOptions(
            listenFor: const Duration(seconds: 20),
            pauseFor: const Duration(seconds: 4),
            listenMode: stt.ListenMode.confirmation,
          ),
        );
      }
    } catch (e) {
      safePrint("Error starting STT: $e");
    }
  }

  void _processSpokenAnswer(String spoken) {
    if (_quizQuestions.isEmpty || _isAnswerSubmitted) return;
    final currentQuestion = _quizQuestions[_currentQuestionIndex];
    final options = List<String>.from(currentQuestion['options']);

    int matchedIndex = -1;
    // 1. Direct letter or number matching
    if (spoken.startsWith("option a") || spoken == "a" || spoken == "option 1" || spoken == "one") {
      matchedIndex = 0;
    } else if (spoken.startsWith("option b") || spoken == "b" || spoken == "option 2" || spoken == "two") {
      matchedIndex = 1;
    } else if (spoken.startsWith("option c") || spoken == "c" || spoken == "option 3" || spoken == "three") {
      matchedIndex = 2;
    } else if (spoken.startsWith("option d") || spoken == "d" || spoken == "option 4" || spoken == "four") {
      matchedIndex = 3;
    } else {
      // 2. Keyword/Option Text matching
      for (int i = 0; i < options.length; i++) {
        if (spoken.contains(options[i].toLowerCase())) {
          matchedIndex = i;
          break;
        }
      }
    }

    if (matchedIndex != -1 && matchedIndex < options.length) {
      _submitSpokenAnswer(matchedIndex);
    }
  }

  void _submitSpokenAnswer(int index) {
    if (_isAnswerSubmitted) return;
    _questionTimer?.cancel();

    final currentQuestion = _quizQuestions[_currentQuestionIndex];
    final correctAnswerIndex = currentQuestion['answer'] as int;
    final isCorrect = index == correctAnswerIndex;

    setState(() {
      _selectedAnswerIndex = index;
      _isAnswerSubmitted = true;
      if (isCorrect) {
        _score++;
      }
    });

    _speakFeedback(isCorrect, currentQuestion['explanation'] as String);
  }

  void _speakFeedback(bool isCorrect, String explanation) async {
    if (!_voiceQuizMode) return;
    try {
      await _quizSpeech.stop();
      setState(() => _isQuizSpeechListening = false);

      String textToSpeak = isCorrect ? "Correct! " : "Incorrect. ";
      textToSpeak += explanation;

      await _quizTts.stop();
      await _quizTts.speak(textToSpeak.replaceAll(RegExp(r'[*#_`]'), ''));
    } catch (e) {
      safePrint("Error speaking feedback: $e");
    }
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
    final correctAnswer = _quizQuestions[_currentQuestionIndex]['answer'] as int;
    final isCorrect = index == correctAnswer;

    setState(() {
      _selectedAnswerIndex = index;
      _isAnswerSubmitted = true;
      if (isCorrect) {
        _score++;
      }
    });

    if (_voiceQuizMode) {
      _speakFeedback(isCorrect, _quizQuestions[_currentQuestionIndex]['explanation'] as String);
    }

    // Automatically transition to next question after 6 seconds in Voice Mode to allow explanation to be heard
    final delay = _voiceQuizMode ? 6000 : 2500;
    Future.delayed(Duration(milliseconds: delay), () {
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
    _bibleTts.stop();
    setState(() {
      _bibleTtsState = 'stopped';
      _explanationTtsState = 'stopped';
      _riddleJokeTtsState = 'stopped';
      _isLoadingChapter = true;
      _aiExplanation = null;
      _verses = [];
      _selectedText = null;
      _chapterText = null;
    });

    try {
      final dio = Dio();
      final bookId = _books.indexOf(_selectedBook) + 1;
      final url = 'https://bolls.life/get-text/$_selectedTranslation/$bookId/$_selectedChapter/';
      final response = await dio.get(url);

      if (response.statusCode == 200 && response.data is List) {
        final rawList = response.data as List;
        final list = rawList.map((v) {
          String textStr = v['text']?.toString() ?? '';
          textStr = textStr.replaceAll(RegExp(r'<[^>]*>'), '').trim();
          return {
            'verse': v['verse'] ?? 1,
            'text': textStr,
          };
        }).toList();

        setState(() {
          _verses = list;
          _chapterText = list.map((v) => "${v['verse']} ${v['text']}").join('\n');
        });

        // Save last read chapter
        final chapterStr = '$_selectedBook $_selectedChapter';
        await SharedPrefs.setString('LAST_READ_BIBLE_CHAPTER', chapterStr);
        await _loadLastReadChapter();
        
        // Log daily streak / action complete
        await EngagementService().recordAction(EngagementAction.bibleChapterRead);
      } else {
        throw Exception("Failed to load from Bolls.life");
      }
    } catch (e) {
      safePrint("Bolls.life fetch failed, falling back to bible-api.com: $e");
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
          
          await EngagementService().recordAction(EngagementAction.bibleChapterRead);
        } else {
          if (mounted) {
            context.showInAppNotification('Failed to load chapter. Status: ${response.statusCode}');
          }
        }
      } catch (err) {
        if (mounted) {
          context.showInAppNotification('Connection required to load Bible.');
        }
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
      final response = await _geminiService.sendMessageOneShot(
        prompt,
        feature: 'bible_explanation',
        maxTokens: 1500,
        cacheKey: 'bible_chapter:$_selectedBook:$_selectedChapter',
      );
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
      final response = await _geminiService.sendMessageOneShot(
        prompt,
        feature: 'bible_verse_explanation',
        maxTokens: 800,
        cacheKey: 'bible_verse:$_selectedBook:$_selectedChapter:$vNum',
      );
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
      final response = await _geminiService.sendMessageOneShot(
        prompt,
        feature: 'bible_highlight_explanation',
        maxTokens: 800,
        cacheKey: 'bible_highlight:$text',
      );
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
      
      String chapterContent = '';
      if (_chapterText != null && _chapterText!.trim().isNotEmpty &&
          (_lastReadChapter == targetChapter || '$_selectedBook $_selectedChapter' == targetChapter)) {
        chapterContent = '\n\nHere is the text of the chapter for reference:\n"""\n$_chapterText\n"""\n';
      }
      
      targetContext = 'application and critical thinking lessons inspired by the Bible chapter "$targetChapter"$chapterContent';
      styleInstructions = """
The questions should NOT be direct trivia or fact recall from the chapter (e.g., do not ask who said what or specific verse numbers).
Instead, generate **learnable, reflective, and application-oriented questions** based strictly on the provided chapter "$targetChapter" that make the user think widely about the moral, philosophical, or practical life lessons of the chapter, and explain what they have learnt.
The 4 options (answers) must fall around the practical application of those concepts, and the correct option should represent the most meaningful, constructive takeaway or life application.
Ensure the "explanation" for each question explains the lesson clearly and how it relates to what they read in "$targetChapter".
Ensure all questions generated are completely unique, deep, and never repetitive compared to standard prompts.
""";
      systemInstruction = "You are a precise Bible study application generator. You generate deep, reflective multiple-choice questions focusing on practical takeaways and moral application of scripture based strictly on the chapter: '$targetChapter'. Under no circumstances do you generate questions about other topics.";
    } else if (_quizScopeType == 'chapter') {
      final targetChapter = _chapterOrTopicController.text.trim().isNotEmpty
          ? _chapterOrTopicController.text.trim()
          : (_lastReadChapter ?? 'John 3');
      
      String chapterContent = '';
      if (_chapterText != null && _chapterText!.trim().isNotEmpty &&
          (_lastReadChapter == targetChapter || '$_selectedBook $_selectedChapter' == targetChapter)) {
        chapterContent = '\n\nHere is the text of the chapter for reference:\n"""\n$_chapterText\n"""\n';
      }
      
      targetContext = 'the Bible chapter "$targetChapter"$chapterContent';
      styleInstructions = """
Generate standard comprehension and contextual questions strictly from the chapter: "$targetChapter".
CRITICAL: Every question must be directly answerable from the text of "$targetChapter" alone.
Do NOT generate general Bible trivia questions (e.g. "Who built the ark?", "What is the first book of the Bible?", "How many disciples did Jesus choose?") unless they are specifically mentioned in this chapter.
Ensure the questions target specific details, verses, characters, or events that occur within "$targetChapter".
""";
      systemInstruction = "You are a precise Bible quiz generator. You generate high-quality Bible trivia questions based strictly on the specified chapter: '$targetChapter'. Under no circumstances do you generate questions about any other topic. Only facts from the specified chapter are allowed.";
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

    final calculatedMaxTokens = (_questionCount * 250).clamp(2500, 6000);

    final prompt = """
You are the **MindPilot Quiz Generator**. Generate a JSON array of multiple choice questions based on: $targetContext.
The JSON array MUST contain EXACTLY $_questionCount questions. Do NOT wrap the array in an outer JSON object or key.

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
- "explanation": A brief explanation of the correct answer. ${
  (_quizScopeType == 'general' || _quizScopeType == 'chapter')
    ? 'For Bible-related questions, the "explanation" MUST start with the specific Bible book, chapter, and verse backing it up (e.g., "John 3:16"), followed by a one-line short explanation of the answer (e.g., "John 3:16 - God so loved the world that He gave His only Son...").'
    : ''
}

CRITICAL ACCURACY REQUIREMENT:
- You MUST double check the correctness of the generated "answer" index.
- The "answer" index MUST correspond exactly to the index (0 to 3) of the correct answer in the "options" array.
- For example, if Jesus is the correct option and is placed at index 1 of the options list, the "answer" index MUST be 1. Do not mismatch them.
- Ensure the question details are completely accurate, using undisputed facts.
${
  (_quizScopeType == 'general' || _quizScopeType == 'chapter')
    ? '- For Bible-related questions, you MUST verify the facts strictly against the actual Bible text and state the exact verse reference to prevent incorrect answers.'
    : ''
}

Return ONLY the raw JSON array containing exactly $_questionCount items. Do not include markdown code block formatting (no ```json or ```). Just raw JSON.
""";

    try {
      if (_activeQuizGenerationToken != currentToken) return;
      final response = await _geminiService.sendMessageOneShot(
        prompt,
        systemInstruction: systemInstruction,
        feature: 'bible_quiz',
        maxTokens: calculatedMaxTokens,
        cacheKey: 'bible_quiz:$_quizScopeType:${_chapterOrTopicController.text.trim()}:$_questionCount',
      );
      
      if (_activeQuizGenerationToken != currentToken) return;
      if (response != null) {
        final cleanJson = _cleanJsonString(response);
        dynamic decoded;
        try {
          decoded = jsonDecode(cleanJson);
        } catch (e) {
          safePrint("JSON decode error, attempting object extraction: $e");
          final objectMatches = RegExp(r'\{[^{}]*"question"[^{}]*\}', dotAll: true).allMatches(response);
          if (objectMatches.isNotEmpty) {
            final List<Map<String, dynamic>> extracted = [];
            for (var m in objectMatches) {
              try {
                final item = jsonDecode(m.group(0)!);
                if (item is Map) extracted.add(Map<String, dynamic>.from(item));
              } catch (_) {}
            }
            if (extracted.isNotEmpty) {
              decoded = extracted;
            }
          }
        }

        List rawList = [];
        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map) {
          if (decoded['questions'] is List) {
            rawList = decoded['questions'];
          } else if (decoded['data'] is List) {
            rawList = decoded['data'];
          } else if (decoded['quiz'] is List) {
            rawList = decoded['quiz'];
          } else if (decoded['items'] is List) {
            rawList = decoded['items'];
          } else if (decoded.containsKey('question')) {
            rawList = [decoded];
          }
        }

        final List<Map<String, dynamic>> parsed = [];
        for (var item in rawList) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final questionText = map['question'] ?? map['questionText'] ?? '';
            final optionsList = List<String>.from(map['options'] ?? []);
            final answerIdx = map['answer'] ?? map['correctAnswerIndex'] ?? 0;
            final explText = map['explanation'] ?? '';
            if (questionText.isNotEmpty && optionsList.isNotEmpty) {
              parsed.add({
                'question': questionText,
                'options': optionsList,
                'answer': answerIdx,
                'explanation': explText,
              });
            }
          }
        }

        // Top up with fallback questions if AI response was truncated or fewer questions were generated
        if (parsed.length < _questionCount) {
          final fallbacks = _getFallbackQuestions(_quizScopeType, _chapterOrTopicController.text.trim(), _questionCount);
          for (var fb in fallbacks) {
            if (parsed.length >= _questionCount) break;
            parsed.add(fb);
          }
        }

        if (_activeQuizGenerationToken != currentToken) return;
        if (parsed.isNotEmpty) {
          setState(() {
            _quizQuestions = parsed;
          });
          _playQuizStartedSoundAndVibrate();
          if (!_voiceQuizMode) {
            _startQuestionTimer();
          }
          _connectSoloQuizVoiceRoom();
          _speakActiveQuestion();
          return;
        }
      }
    } catch (e) {
      safePrint("Solo quiz generation/parsing failed: $e");
      if (_activeQuizGenerationToken != currentToken) return;
      setState(() {
        _quizQuestions = _getFallbackQuestions(_quizScopeType, _chapterOrTopicController.text.trim(), _questionCount);
      });
      _playQuizStartedSoundAndVibrate();
      if (!_voiceQuizMode) {
        _startQuestionTimer();
      }
      _connectSoloQuizVoiceRoom();
      _speakActiveQuestion();
      if (mounted) {
        context.showInAppNotification(
          'Dynamic quiz error. Loaded fallback ${_getScopeFriendlyName(_quizScopeType)} Quiz.',
          type: InAppNotificationType.info,
        );
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

    final correctAnswer = _quizQuestions[_currentQuestionIndex]['answer'] as int;
    final isCorrect = _selectedAnswerIndex == correctAnswer;

    setState(() {
      _isAnswerSubmitted = true;
      if (isCorrect) {
        _score++;
      }
    });

    if (_voiceQuizMode) {
      _speakFeedback(isCorrect, _quizQuestions[_currentQuestionIndex]['explanation'] as String);
    }
  }

  void _nextQuestion() {
    _questionTimer?.cancel();
    setState(() {
      if (_currentQuestionIndex < _quizQuestions.length - 1) {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _isAnswerSubmitted = false;
        if (!_voiceQuizMode) {
          _startQuestionTimer();
        }
      } else {
        _quizFinished = true;
        _completeQuizEngagement();
      }
    });
    if (!_quizFinished) {
      _speakActiveQuestion();
    }
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
                try {
                  context.read<GroupQuizProvider>().leaveVoiceRoom();
                } catch (_) {}
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

    final groupQuizProvider = context.watch<GroupQuizProvider>();
    final isQuizActive = _quizQuestions.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: isQuizActive ? 'Solo Quiz Room' : 'Bible Study & Quiz',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.arrow_back_ios, color: theme.accentTxt, size: 20),
        ).rippleClick(() {
          if (isQuizActive) {
            _confirmCancelQuiz();
          } else {
            context.pop();
          }
        }),
        actions: [
          if (isQuizActive && groupQuizProvider.liveKitService.isConnected) ...[
            IconButton(
              icon: Icon(
                groupQuizProvider.liveKitService.isMicrophoneEnabled()
                    ? Icons.mic
                    : Icons.mic_off,
                color: groupQuizProvider.liveKitService.isMicrophoneEnabled()
                    ? Colors.greenAccent
                    : theme.accentTxt.withOpacity(0.5),
              ),
              onPressed: () {
                final enabled = groupQuizProvider.liveKitService.isMicrophoneEnabled();
                groupQuizProvider.liveKitService.toggleMicrophone(!enabled);
              },
            ),
            12.horizontalSpace,
          ],
        ],
        bottom: isQuizActive
            ? null
            : TabBar(
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
              // Translation, Book & Chapter Selectors
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: theme.accentTxt.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedTranslation,
                        dropdownColor: theme.brandDark,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: TextStyle(color: theme.accentTxt, fontSize: 14),
                        items: _translations.keys
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              _selectedTranslation = val;
                            });
                            await SharedPrefs.setString('SELECTED_BIBLE_TRANSLATION', val);
                            _fetchBibleChapter();
                          }
                        },
                      ),
                    ),
                  ),
                  8.horizontalSpace,
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        style: TextStyle(color: theme.accentTxt, fontSize: 14),
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
                  8.horizontalSpace,
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        style: TextStyle(color: theme.accentTxt, fontSize: 14),
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
              16.verticalSpace,
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VoiceBibleStudyScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: Border.all(color: theme.primaryBase.withOpacity(0.3)),
                  child: Row(
                    children: [
                      Icon(Icons.mic, color: theme.primaryBase),
                      12.horizontalSpace,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PrimaryText(
                              text: 'Conversational Bible Study 🎙️',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryBase,
                            ),
                            4.verticalSpace,
                            SecondaryText(
                              text: 'Tap to have a natural verbal Q&A about scripture',
                              fontSize: 10,
                              color: theme.accentTxt.withOpacity(0.6),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: theme.primaryBase, size: 14),
                    ],
                  ),
                ),
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
                      if (_bibleTtsState == 'stopped') ...[
                        InkWell(
                          onTap: () => _toggleBibleTts(),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.transparent,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.volume_up, size: 14, color: theme.accentTxt.withOpacity(0.8)),
                                4.horizontalSpace,
                                SecondaryText(
                                  text: 'Read',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.accentTxt,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        InkWell(
                          onTap: () => _toggleBibleTts(),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.primaryBase),
                              borderRadius: BorderRadius.circular(16),
                              color: theme.primaryBase.withOpacity(0.1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _bibleTtsState == 'playing' ? Icons.pause : Icons.play_arrow,
                                  size: 14,
                                  color: theme.primaryBase,
                                ),
                                4.horizontalSpace,
                                SecondaryText(
                                  text: _bibleTtsState == 'playing' ? 'Pause' : 'Resume',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryBase,
                                ),
                              ],
                            ),
                          ),
                        ),
                        6.horizontalSpace,
                        InkWell(
                          onTap: () => _toggleBibleTts(isStop: true),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.transparent,
                            ),
                            child: Icon(Icons.stop, size: 14, color: theme.accentTxt.withOpacity(0.8)),
                          ),
                        ),
                      ],
                      12.horizontalSpace,
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
              12.verticalSpace,
              Row(
                children: [
                  Icon(Icons.speed, color: theme.accentTxt.withOpacity(0.6), size: 16),
                  8.horizontalSpace,
                  SecondaryText(
                    text: 'Speed:',
                    fontSize: 11,
                    color: theme.accentTxt.withOpacity(0.8),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        activeTrackColor: theme.primaryBase,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: theme.primaryBase,
                        overlayColor: theme.primaryBase.withOpacity(0.2),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: _bibleSpeechRate,
                        min: 0.2,
                        max: 0.8,
                        onChanged: (val) {
                          setState(() {
                            _bibleSpeechRate = val;
                          });
                          _bibleTts.setSpeechRate(val);
                          _saveSpeechRate(val);
                        },
                      ),
                    ),
                  ),
                  SecondaryText(
                    text: '${_bibleSpeechRate.toStringAsFixed(2)}x',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.accentTxt.withOpacity(0.8),
                  ),
                ],
              ),
              12.verticalSpace,
              
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
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        label: 'Explanation',
                        prefixIcon: Icon(Icons.auto_awesome, size: 18, color: theme.primaryBase),
                        onPressed: _explainChapter,
                        isGlass: true,
                      ),
                    ),
                    if (_aiExplanation != null) ...[
                      12.horizontalSpace,
                      if (_explanationTtsState == 'stopped') ...[
                        Expanded(
                          child: CustomButton(
                            label: 'Read Explanation',
                            prefixIcon: Icon(Icons.volume_up, size: 18, color: theme.primaryBase),
                            onPressed: () => _toggleExplanationTts(),
                            isGlass: true,
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: CustomButton(
                            label: _explanationTtsState == 'playing' ? 'Pause' : 'Resume',
                            prefixIcon: Icon(_explanationTtsState == 'playing' ? Icons.pause : Icons.play_arrow, size: 18, color: theme.primaryBase),
                            onPressed: () => _toggleExplanationTts(),
                            isGlass: true,
                          ),
                        ),
                        8.horizontalSpace,
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.stop, color: theme.accentTxt, size: 18),
                            onPressed: () => _toggleExplanationTts(isStop: true),
                          ),
                        ),
                      ],
                    ],
                  ],
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
              16.verticalSpace,
              const Divider(color: Colors.white12, height: 1),
              16.verticalSpace,
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
                              text: 'Voice Assistant Mode 🎙️',
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
                          text: 'Quiz Master reads questions & listens to answers',
                          fontSize: 11,
                          color: theme.accentTxt.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _voiceQuizMode,
                    activeThumbColor: theme.primaryBase,
                    activeTrackColor: theme.primaryBase.withOpacity(0.3),
                    inactiveThumbColor: theme.accentTxt.withOpacity(0.4),
                    inactiveTrackColor: Colors.white12,
                    onChanged: (val) {
                      final authStore = context.read<AppAuthProvider>();
                      if (!authStore.isPro) {
                        AppHelper.showPaywall(context, feature: 'Voice Quiz Master Mode');
                        return;
                      }
                      setState(() {
                        _voiceQuizMode = val;
                      });
                    },
                  ),
                ],
              ),
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
          if (_voiceQuizMode) ...[
            12.verticalSpace,
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: Border.all(color: theme.primaryBase.withOpacity(0.2)),
              child: Row(
                children: [
                  Icon(
                    _isQuizSpeechListening ? Icons.mic : Icons.volume_up,
                    color: _isQuizSpeechListening ? theme.errorPrimary : theme.primaryBase,
                  ),
                  12.horizontalSpace,
                  Expanded(
                    child: SecondaryText(
                      text: _isQuizSpeechListening 
                          ? "Quiz Master Listening... Speak your choice (e.g. 'Option A')" 
                          : "Quiz Master Speaking...",
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  if (!_isAnswerSubmitted)
                    IconButton(
                      icon: Icon(Icons.refresh, color: theme.accentTxt.withOpacity(0.5), size: 18),
                      onPressed: () {
                        _speakActiveQuestion();
                      },
                      tooltip: "Repeat question",
                    ),
                ],
              ),
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
                      text: "$scopeName Quiz completed on MindPilot!$emoji Score: $_score/${_quizQuestions.length}.\n\n$downloadUrl",
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
                    try {
                      context.read<GroupQuizProvider>().leaveVoiceRoom();
                    } catch (_) {}
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
    _bibleTts.stop();
    setState(() {
      _riddleJokeTtsState = 'stopped';
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
      final response = await _geminiService.sendMessageOneShot(
        prompt,
        systemInstruction: systemInstruction,
        feature: 'riddle_joke',
        maxTokens: 800,
        cacheKey: 'riddle_joke:$_riddlesMode:$categoryText',
      );
      if (response != null && response.trim().isNotEmpty) {
        final cleanJson = _cleanJsonString(response);
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_riddleJokeTtsState == 'stopped') ...[
                            IconButton(
                              icon: Icon(
                                Icons.volume_up,
                                color: theme.accentTxt.withOpacity(0.7),
                                size: 18,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () => _toggleRiddleOrJokeTts(),
                            ),
                          ] else ...[
                            IconButton(
                              icon: Icon(
                                _riddleJokeTtsState == 'playing' ? Icons.pause : Icons.play_arrow,
                                color: theme.primaryBase,
                                size: 18,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () => _toggleRiddleOrJokeTts(),
                            ),
                            8.horizontalSpace,
                            IconButton(
                              icon: Icon(
                                Icons.stop,
                                color: theme.accentTxt.withOpacity(0.7),
                                size: 18,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () => _toggleRiddleOrJokeTts(isStop: true),
                            ),
                          ],
                          8.horizontalSpace,
                          Icon(
                            _riddlesMode == 'riddle' ? Icons.help_outline : Icons.sentiment_satisfied,
                            color: theme.primaryBase,
                            size: 18,
                          ),
                        ],
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

  List<Map<String, dynamic>> _getFallbackQuestions(String scopeType, String scopeValue, int count) {
    List<Map<String, dynamic>> basePool = [];
    switch (scopeType) {
      case 'tech':
        basePool = [
          {
            "question": "Which programming language is known for its safety and concurrency features, often used in systems programming?",
            "options": ["Python", "JavaScript", "Rust", "PHP"],
            "answer": 2,
            "explanation": "Rust is designed for performance and safety, especially safe concurrency."
          },
          {
            "question": "What does HTTP stand for?",
            "options": [
              "Hyper Text Transfer Protocol",
              "High Transfer Text Protocol",
              "Hyperlink Text Technology Protocol",
              "Home Tool Transfer Protocol"
            ],
            "answer": 0,
            "explanation": "HTTP stands for Hyper Text Transfer Protocol."
          },
          {
            "question": "In Flutter, which widget is the root of the widget tree for most applications?",
            "options": ["Row", "Container", "MaterialApp", "Column"],
            "answer": 2,
            "explanation": "MaterialApp wraps the app to provide routing, theme, and material design structures."
          },
          {
            "question": "What is the primary role of a version control system like Git?",
            "options": ["Compile code", "Track file changes over time", "Deploy apps to server", "Manage database queries"],
            "answer": 1,
            "explanation": "Git tracks changes in source code during software development."
          },
          {
            "question": "Which data structure uses LIFO (Last In, First Out) ordering?",
            "options": ["Queue", "Stack", "Array", "Linked List"],
            "answer": 1,
            "explanation": "A Stack operates on a Last In, First Out (LIFO) basis."
          },
        ];
        break;
      case 'science':
        basePool = [
          {
            "question": "What is the chemical symbol for gold?",
            "options": ["Ag", "Au", "Fe", "Pb"],
            "answer": 1,
            "explanation": "Au is the symbol for gold, derived from the Latin word aurum."
          },
          {
            "question": "Which planet is known as the Red Planet?",
            "options": ["Venus", "Mars", "Jupiter", "Saturn"],
            "answer": 1,
            "explanation": "Mars is called the Red Planet because of iron oxide (rust) on its surface."
          },
          {
            "question": "What is the speed of light in a vacuum approximately?",
            "options": ["300,000 km/s", "150,000 km/s", "1,000,000 km/s", "30,000 km/s"],
            "answer": 0,
            "explanation": "Light travels at approximately 300,000 kilometers per second in a vacuum."
          },
          {
            "question": "Which particle has a negative electric charge?",
            "options": ["Proton", "Neutron", "Electron", "Photon"],
            "answer": 2,
            "explanation": "Electrons carry a negative fundamental electric charge."
          },
          {
            "question": "What process do plants use to convert sunlight into food energy?",
            "options": ["Respiration", "Photosynthesis", "Fermentation", "Transpiration"],
            "answer": 1,
            "explanation": "Photosynthesis converts light energy into chemical energy in plants."
          },
        ];
        break;
      case 'english':
        basePool = [
          {
            "question": "Who wrote the play 'Romeo and Juliet'?",
            "options": ["Charles Dickens", "William Shakespeare", "Jane Austen", "Mark Twain"],
            "answer": 1,
            "explanation": "William Shakespeare wrote the tragedy Romeo and Juliet early in his career."
          },
          {
            "question": "Which of the following is a synonym for 'ephemeral'?",
            "options": ["Eternal", "Fleeting", "Substantial", "Constant"],
            "answer": 1,
            "explanation": "Ephemeral means lasting for a very short time; fleeting."
          },
          {
            "question": "What literary device involves attributing human characteristics to non-human things?",
            "options": ["Metaphor", "Simile", "Personification", "Alliteration"],
            "answer": 2,
            "explanation": "Personification assigns human traits and emotions to non-human entities."
          },
          {
            "question": "Identify the adjective in the sentence: 'The courageous knight defeated the dragon.'",
            "options": ["courageous", "knight", "defeated", "dragon"],
            "answer": 0,
            "explanation": "'Courageous' describes the noun 'knight'."
          },
          {
            "question": "Who wrote the epic poem 'Paradise Lost'?",
            "options": ["John Milton", "Geoffrey Chaucer", "Lord Byron", "T.S. Eliot"],
            "answer": 0,
            "explanation": "John Milton published Paradise Lost in 1667."
          },
        ];
        break;
      case 'economics':
        basePool = [
          {
            "question": "What is the term for a general increase in prices and fall in the purchasing value of money?",
            "options": ["Deflation", "Stagnation", "Inflation", "Recession"],
            "answer": 2,
            "explanation": "Inflation is a general rise in price levels over time."
          },
          {
            "question": "Which principle states that as price increases, quantity supplied increases?",
            "options": ["Law of Demand", "Law of Supply", "Law of Diminishing Utility", "Fiscal Balance"],
            "answer": 1,
            "explanation": "The Law of Supply states that higher prices encourage suppliers to produce more."
          },
          {
            "question": "What term describes a market structure dominated by a single seller?",
            "options": ["Oligopoly", "Monopoly", "Monopsony", "Perfect Competition"],
            "answer": 1,
            "explanation": "A monopoly exists when a single seller controls the supply of a commodity."
          },
          {
            "question": "What does GDP stand for?",
            "options": ["Gross Domestic Product", "General Development Process", "Global Debt Ratio", "Government Direct Purchase"],
            "answer": 0,
            "explanation": "GDP stands for Gross Domestic Product."
          },
          {
            "question": "Which institution regulates national monetary policy and money supply in many countries?",
            "options": ["Stock Exchange", "Central Bank", "Commercial Bank", "Treasury Department"],
            "answer": 1,
            "explanation": "Central Banks oversee national monetary policy and money supply."
          },
        ];
        break;
      case 'mindfulness':
        basePool = [
          {
            "question": "Which of the following is a key component of mindfulness practice?",
            "options": ["Dwelling on the past", "Worrying about the future", "Non-judgmental present moment awareness", "Suppressing all thoughts"],
            "answer": 2,
            "explanation": "Mindfulness involves paying attention to the present moment without judgment."
          },
          {
            "question": "What is emotional intelligence primarily concerned with?",
            "options": ["IQ scores", "Recognizing and managing emotions", "Memory retention", "Physical strength"],
            "answer": 1,
            "explanation": "Emotional intelligence is the ability to perceive, understand, and manage emotions."
          },
          {
            "question": "Which technique helps calm the nervous system during stress?",
            "options": ["Deep diaphragmatic breathing", "Rapid shallow breathing", "Avoiding rest", "Consuming caffeine"],
            "answer": 0,
            "explanation": "Deep breathing activates the parasympathetic nervous system to promote relaxation."
          },
          {
            "question": "What is the practice of expressing appreciation for good things in life called?",
            "options": ["Gratitude", "Resentment", "Perfectionism", "Stoicism"],
            "answer": 0,
            "explanation": "Gratitude involves recognizing and feeling thankful for positive aspects of life."
          },
          {
            "question": "How does growth mindset view challenges and failures?",
            "options": ["As proof of inadequacy", "As opportunities to learn and grow", "As reasons to quit", "As permanent defects"],
            "answer": 1,
            "explanation": "A growth mindset sees challenges as pathways to developing skill and resilience."
          },
        ];
        break;
      case 'custom':
        final topic = scopeValue.isNotEmpty ? scopeValue : 'General Knowledge';
        basePool = [
          {
            "question": "When studying '$topic', what is an effective foundational strategy?",
            "options": ["Build core concepts step-by-step", "Skip fundamental principles", "Memorize without understanding", "Avoid practice exercises"],
            "answer": 0,
            "explanation": "Building core concepts step-by-step establishes a solid understanding of $topic."
          },
          {
            "question": "Which method best reinforces long-term retention of concepts in '$topic'?",
            "options": ["Active recall and spaced repetition", "Passive re-reading once", "Cramming overnight", "Skimming table of contents"],
            "answer": 0,
            "explanation": "Active recall combined with spaced repetition boosts long-term memory for $topic."
          },
          {
            "question": "How can one deepen mastery in key areas of '$topic'?",
            "options": ["Teach or explain the topic to others", "Never ask questions", "Ignore feedback", "Rely solely on intuition"],
            "answer": 0,
            "explanation": "Explaining concepts to others identifies knowledge gaps and solidifies mastery in $topic."
          },
          {
            "question": "What is an effective approach to tackling complex problems in '$topic'?",
            "options": ["Break the problem down into smaller parts", "Guess randomly", "Abandon difficult parts", "Rush without analyzing"],
            "answer": 0,
            "explanation": "Decomposing complex problems into smaller manageable steps leads to clearer solutions."
          },
          {
            "question": "Why is regular self-assessment valuable when learning '$topic'?",
            "options": ["It highlights strengths and areas for improvement", "It proves you know everything", "It replaces study time", "It prevents critical thinking"],
            "answer": 0,
            "explanation": "Self-assessment helps track progress and targets weak spots in $topic."
          },
        ];
        break;
      default:
        // Bible general / chapter fallback
        basePool = [
          {
            "question": "Who built the ark as commanded by God?",
            "options": ["Moses", "Abraham", "Noah", "David"],
            "answer": 2,
            "explanation": "Genesis 6:14 - Noah built the ark to save his family and animals from the flood."
          },
          {
            "question": "What is the first book of the Bible?",
            "options": ["Exodus", "Genesis", "Matthew", "John"],
            "answer": 1,
            "explanation": "Genesis 1:1 - Genesis is the opening book of the Bible, detailing creation."
          },
          {
            "question": "How many disciples did Jesus choose?",
            "options": ["10", "12", "7", "40"],
            "answer": 1,
            "explanation": "Matthew 10:1-4 - Jesus chose 12 Apostles to follow him and spread his gospel."
          },
          {
            "question": "Where was Jesus born according to scripture?",
            "options": ["Nazareth", "Jerusalem", "Bethlehem", "Capernaum"],
            "answer": 2,
            "explanation": "Micah 5:2 / Matthew 2:1 - Jesus was born in Bethlehem as prophesied."
          },
          {
            "question": "Which commandment comes with a promise of long life?",
            "options": ["Honor your father and mother", "You shall not steal", "Remember the Sabbath day", "You shall not murder"],
            "answer": 0,
            "explanation": "Ephesians 6:2-3 / Exodus 20:12 - Honor your father and mother is the first commandment with a promise."
          },
        ];
        break;
    }

    if (basePool.isEmpty) return [];

    final List<Map<String, dynamic>> result = [];
    while (result.length < count) {
      for (var q in basePool) {
        if (result.length >= count) break;
        result.add(Map<String, dynamic>.from(q));
      }
    }
    return result;
  }

  String _cleanJsonString(String response) {
    String clean = response.trim();
    if (clean.startsWith('```')) {
      final firstNewLine = clean.indexOf('\n');
      if (firstNewLine != -1) {
        clean = clean.substring(firstNewLine + 1);
      }
      if (clean.endsWith('```')) {
        clean = clean.substring(0, clean.length - 3);
      }
      clean = clean.trim();
    }

    int firstList = clean.indexOf('[');
    int lastList = clean.lastIndexOf(']');
    if (firstList != -1 && lastList != -1 && lastList > firstList) {
      return clean.substring(firstList, lastList + 1);
    }

    int firstObj = clean.indexOf('{');
    int lastObj = clean.lastIndexOf('}');
    if (firstObj != -1 && lastObj != -1 && lastObj > firstObj) {
      return clean.substring(firstObj, lastObj + 1);
    }
    return clean;
  }
}
