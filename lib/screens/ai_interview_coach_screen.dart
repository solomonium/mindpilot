import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:mindpilot/export.dart';

class AiInterviewCoachScreen extends StatefulWidget {
  const AiInterviewCoachScreen({super.key});

  @override
  State<AiInterviewCoachScreen> createState() => _AiInterviewCoachScreenState();
}

class _AiInterviewCoachScreenState extends State<AiInterviewCoachScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final GeminiService _geminiService = GeminiService();

  // Setup state
  String _selectedField = 'Software Engineering';
  String _selectedLevel = 'Mid-level';
  int _selectedLength = 3; // 3, 5, 10
  bool _isSetupMode = true;

  // Active interview state
  int _currentQuestionIndex = 0;
  List<String> _questions = [];
  final List<String> _userAnswers = [];
  bool _isSpeakingQuestion = false;
  bool _isListeningResponse = false;
  bool _isAnalyzing = false;
  String _activeRecordingText = "";
  String _previouslySpokenText = "";

  // Result state
  String _overallFeedback = "";
  int _score = 0;
  List<String> _individualFeedbacks = [];
  bool _isPlayingResultTts = false;

  final List<String> _fields = [
    'Software Engineering',
    'Medicine & Healthcare',
    'Finance & Investment',
    'General HR & Leadership',
    'Marketing & Strategy'
  ];

  final List<String> _levels = ['Entry-level', 'Mid-level', 'Senior/Lead'];

  @override
  void initState() {
    super.initState();
    _initializeGemini();
    _initSpeech();
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  void _initializeGemini() async {
    final apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
    _geminiService.init(apiKey);
  }

  void _initSpeech() async {
    try {
      await _speech.initialize();
    } catch (e) {
      safePrint("STT initialization failed: $e");
    }
  }

  Future<void> _startInterview() async {
    setState(() {
      _isSetupMode = false;
      _isAnalyzing = true;
    });

    // Generate tailored interview questions via Gemini
    final prompt = """
You are an expert HR Manager and Technical Recruiter.
Generate exactly $_selectedLength interview questions for a candidate applying for a $_selectedLevel position in $_selectedField.
The questions must be highly realistic, covering technical concepts, architectural thinking, or behavioral scenarios relevant to $_selectedField.

Return ONLY a valid JSON list of strings representing the questions. Do not include markdown code block formatting (no ```json or ```). Just raw JSON.
""";

    try {
      final response = await _geminiService.sendMessageOneShot(
        prompt,
        systemInstruction: "You are an interview recruiter. Generate raw JSON list of questions.",
        feature: 'interview_prep',
        maxTokens: 1000,
      );

      if (response != null) {
        final cleanJson = response.replaceAll(RegExp(r'```json|```'), '').trim();
        final List decoded = jsonDecode(cleanJson);
        setState(() {
          _questions = List<String>.from(decoded);
          _isAnalyzing = false;
        });
        _playQuestion();
      }
    } catch (e) {
      safePrint("Error generating questions: $e");
      // Fallback questions
      setState(() {
        _questions = [
          "Could you introduce yourself and describe a challenging project you worked on recently?",
          "How do you handle disagreements or conflicting opinions within a project team?",
          "What is your approach to handling deadlines under high stress or workload?"
        ];
        _isAnalyzing = false;
      });
      _playQuestion();
    }
  }

  void _playQuestion() async {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) return;
    try {
      setState(() {
        _isSpeakingQuestion = true;
        _isListeningResponse = false;
        _activeRecordingText = "";
        _previouslySpokenText = "";
      });

      final question = _questions[_currentQuestionIndex];
      await _tts.stop();
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.48);

      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _isSpeakingQuestion = false);
          _startListeningAnswer();
        }
      });

      await _tts.speak(question);
    } catch (e) {
      safePrint("TTS play question error: $e");
      if (mounted) setState(() => _isSpeakingQuestion = false);
    }
  }

  void _startListeningAnswer() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          safePrint("Interview STT status: $status");
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListeningResponse) {
              setState(() => _isListeningResponse = false);
            }
          }
        },
        onError: (error) => safePrint("STT error: $error"),
      );

      if (available) {
        setState(() {
          _previouslySpokenText = _activeRecordingText;
          _isListeningResponse = true;
        });
        await _speech.listen(
          onResult: (val) {
            setState(() {
              final currentWords = val.recognizedWords.trim();
              if (_previouslySpokenText.isEmpty) {
                _activeRecordingText = currentWords;
              } else {
                _activeRecordingText = "$_previouslySpokenText $currentWords";
              }
            });
          },
          listenOptions: stt.SpeechListenOptions(
            listenFor: const Duration(seconds: 120),
            pauseFor: const Duration(seconds: 8),
            listenMode: stt.ListenMode.dictation,
          ),
        );
      }
    } catch (e) {
      safePrint("Error listening to answer: $e");
    }
  }

  void _submitAnswer() {
    _speech.stop();
    setState(() {
      _userAnswers.add(_activeRecordingText.isNotEmpty ? _activeRecordingText : "No verbal response provided.");
      _isListeningResponse = false;
    });

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _playQuestion();
    } else {
      _analyzeInterview();
    }
  }

  Future<void> _analyzeInterview() async {
    setState(() {
      _isAnalyzing = true;
    });

    // Send Q&A data to Gemini to evaluate
    StringBuffer qaBlock = StringBuffer();
    for (int i = 0; i < _questions.length; i++) {
      qaBlock.writeln("Question ${i + 1}: ${_questions[i]}");
      qaBlock.writeln("Answer ${i + 1}: ${_userAnswers[i]}\n");
    }

    final prompt = """
You are an elite Executive Career Coach and Technical Recruiter.
Analyze this mock interview session for a $_selectedLevel position in $_selectedField:

$qaBlock

Evaluate the candidate's performance. Return a JSON map with exactly three keys:
1. "score": An integer from 1 to 10.
2. "coaching": A brief, spoken feedback summary (under 80 words) evaluating their general clarity, confidence, and content accuracy.
3. "breakdown": A list of strings corresponding to each question, giving specific constructive advice for improving that answer.

Return ONLY the raw JSON map. Do not include markdown code block formatting.
""";

    try {
      final response = await _geminiService.sendMessageOneShot(
        prompt,
        systemInstruction: "You are an executive interviewer coach. Return raw JSON map of the evaluation.",
        feature: 'interview_coaching',
        maxTokens: 1500,
      );

      if (response != null) {
        final cleanJson = response.replaceAll(RegExp(r'```json|```'), '').trim();
        final Map<String, dynamic> decoded = jsonDecode(cleanJson);
        setState(() {
          _score = decoded['score'] as int;
          _overallFeedback = decoded['coaching'] as String;
          _individualFeedbacks = List<String>.from(decoded['breakdown']);
          _isAnalyzing = false;
        });
        _speakOverallFeedback();
      }
    } catch (e) {
      safePrint("Error evaluating interview: $e");
      setState(() {
        _score = 7;
        _overallFeedback = "You demonstrated solid knowledge under mock pressure. Focus on structure and expanding key details.";
        _individualFeedbacks = List.generate(_questions.length, (index) => "Practice structuring this answer with the STAR method (Situation, Task, Action, Result).");
        _isAnalyzing = false;
      });
      _speakOverallFeedback();
    }
  }

  void _speakOverallFeedback() async {
    try {
      setState(() => _isPlayingResultTts = true);
      await _tts.stop();
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.48);

      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isPlayingResultTts = false);
      });

      await _tts.speak("Interview Completed. Your overall score is $_score out of 10. Here is your coaching summary. $_overallFeedback");
    } catch (e) {
      safePrint("TTS feedback error: $e");
    }
  }

  void _toggleResultTts() async {
    if (_isPlayingResultTts) {
      await _tts.stop();
      setState(() => _isPlayingResultTts = false);
    } else {
      _speakOverallFeedback();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'AI Interview Recruiter 🎤',
          color: theme.accentTxt,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Icon(Icons.arrow_back_ios, color: theme.accentTxt, size: 20)
            .rippleClick(() {
          _tts.stop();
          _speech.stop();
          Navigator.of(context).pop();
        }),
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
            child: _isSetupMode
                ? _buildSetupView(theme)
                : (_isAnalyzing
                    ? _buildLoadingView(theme)
                    : (_overallFeedback.isNotEmpty ? _buildResultView(theme) : _buildActiveInterviewView(theme))),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupView(AppTheme theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryText(
            text: 'Configure Mock Interview',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.accentTxt,
          ),
          8.verticalSpace,
          SecondaryText(
            text: 'Face dynamic recruitment questions, answer verbally, and receive an instant recruiter report.',
            color: theme.accentTxt.withOpacity(0.6),
          ),
          24.verticalSpace,
          
          // Field selection
          PrimaryText(text: 'Career Field', color: theme.accentTxt, fontSize: 14, fontWeight: FontWeight.bold),
          12.verticalSpace,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedField,
                dropdownColor: theme.brandDark,
                style: TextStyle(color: theme.accentTxt, fontSize: 15),
                items: _fields.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedField = v);
                },
              ),
            ),
          ),
          20.verticalSpace,

          // Level selection
          PrimaryText(text: 'Experience Level', color: theme.accentTxt, fontSize: 14, fontWeight: FontWeight.bold),
          12.verticalSpace,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLevel,
                dropdownColor: theme.brandDark,
                style: TextStyle(color: theme.accentTxt, fontSize: 15),
                items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedLevel = v);
                },
              ),
            ),
          ),
          20.verticalSpace,

          // Interview Length selector
          PrimaryText(text: 'Questions Count', color: theme.accentTxt, fontSize: 14, fontWeight: FontWeight.bold),
          12.verticalSpace,
          Row(
            children: [3, 5, 10].map((len) {
              final isSelected = _selectedLength == len;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => setState(() => _selectedLength = len),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                          text: '$len Questions',
                          fontSize: 13,
                          color: theme.accentTxt,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          40.verticalSpace,

          CustomButton(
            label: 'Start Verbal Interview',
            onPressed: _startInterview,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(AppTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.primaryBase)),
            24.verticalSpace,
            PrimaryText(
              text: _questions.isEmpty
                  ? 'Recruiting tailored questions from database...'
                  : 'Analyzing spoken transcripts & scoring...',
              textAlign: TextAlign.center,
              color: Colors.white,
              fontSize: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveInterviewView(AppTheme theme) {
    final activeQuestion = _questions[_currentQuestionIndex];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SecondaryText(
                text: 'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                color: theme.accentTxt.withOpacity(0.6),
                fontWeight: FontWeight.bold,
              ),
              SecondaryText(
                text: '$_selectedField',
                color: theme.primaryBase,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          12.verticalSpace,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              minHeight: 6,
              backgroundColor: theme.accentTxt.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryBase),
            ),
          ),
          32.verticalSpace,

          // Recruiter card
          GlassContainer(
            padding: const EdgeInsets.all(20),
            border: Border.all(color: theme.primaryBase.withOpacity(0.2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    if (!_isSpeakingQuestion && !_isListeningResponse) {
                      _startListeningAnswer();
                    } else if (_isListeningResponse) {
                      _speech.stop();
                      setState(() => _isListeningResponse = false);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSpeakingQuestion
                              ? Icons.volume_up
                              : (_isListeningResponse ? Icons.mic : Icons.mic_off),
                          color: _isSpeakingQuestion
                              ? theme.primaryBase
                              : (_isListeningResponse ? Colors.green : Colors.white54),
                        ),
                        8.horizontalSpace,
                        PrimaryText(
                          text: _isSpeakingQuestion
                              ? "Recruiter speaking..."
                              : (_isListeningResponse ? "Listening... speak now" : "Microphone off (Tap to speak)"),
                          fontSize: 13,
                          color: _isListeningResponse ? Colors.green : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ),
                16.verticalSpace,
                PrimaryText(
                  text: activeQuestion,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          24.verticalSpace,

          // Your Transcript panel
          PrimaryText(text: 'Your spoken transcript', color: theme.accentTxt, fontSize: 14, fontWeight: FontWeight.bold),
          12.verticalSpace,
          Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: PrimaryText(
                  text: _activeRecordingText.isEmpty
                      ? "Start speaking your response. It will be transcribed here in real-time."
                      : _activeRecordingText,
                  color: _activeRecordingText.isEmpty ? Colors.white30 : Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          24.verticalSpace,

          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white60),
                onPressed: _playQuestion,
                tooltip: "Repeat question",
              ),
              12.horizontalSpace,
              Expanded(
                child: CustomButton(
                  label: _currentQuestionIndex < _questions.length - 1 ? 'Submit & Next' : 'Finish Interview',
                  onPressed: _submitAnswer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(AppTheme theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.primaryBase, width: 4),
              ),
              child: Center(
                child: PrimaryText(
                  text: '$_score/10',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryBase,
                ),
              ),
            ),
          ),
          16.verticalSpace,
          Center(
            child: PrimaryText(
              text: 'Interview Report Card',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          8.verticalSpace,
          Center(
            child: SecondaryText(
              text: '$_selectedField ($_selectedLevel)',
              color: Colors.white60,
            ),
          ),
          24.verticalSpace,

          // Overall Coaching card
          GlassContainer(
            padding: const EdgeInsets.all(16),
            border: Border.all(color: theme.primaryBase.withOpacity(0.2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PrimaryText(
                      text: 'Overall Recruiter Report',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryBase,
                    ),
                    IconButton(
                      icon: Icon(
                        _isPlayingResultTts ? Icons.volume_up : Icons.volume_mute,
                        color: _isPlayingResultTts ? theme.primaryBase : Colors.white60,
                      ),
                      onPressed: _toggleResultTts,
                    ),
                  ],
                ),
                8.verticalSpace,
                SecondaryText(
                  text: _overallFeedback,
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ],
            ),
          ),
          24.verticalSpace,

          // Detailed Breakdown
          PrimaryText(text: 'Question-by-Question Advice', color: theme.accentTxt, fontSize: 15, fontWeight: FontWeight.bold),
          12.verticalSpace,
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questions.length,
            itemBuilder: (context, idx) {
              final advice = _individualFeedbacks.length > idx 
                  ? _individualFeedbacks[idx] 
                  : "Practice refining your articulation using structure.";
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SecondaryText(
                        text: 'Q: ${_questions[idx]}',
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      8.verticalSpace,
                      SecondaryText(
                        text: 'Your Answer: ${_userAnswers[idx]}',
                        color: Colors.white30,
                        fontSize: 12,
                      ),
                      8.verticalSpace,
                      SecondaryText(
                        text: 'Coaching Advice: $advice',
                        color: theme.primaryBase,
                        fontSize: 12,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          32.verticalSpace,

          CustomButton(
            label: 'Back to Setup',
            onPressed: () {
              setState(() {
                _isSetupMode = true;
                _currentQuestionIndex = 0;
                _questions.clear();
                _userAnswers.clear();
                _overallFeedback = "";
                _score = 0;
                _individualFeedbacks.clear();
              });
            },
          ),
        ],
      ),
    );
  }
}
