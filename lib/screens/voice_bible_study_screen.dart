import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:mindpilot/export.dart';

class VoiceBibleStudyScreen extends StatefulWidget {
  const VoiceBibleStudyScreen({super.key});

  @override
  State<VoiceBibleStudyScreen> createState() => _VoiceBibleStudyScreenState();
}

class _VoiceBibleStudyScreenState extends State<VoiceBibleStudyScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final GeminiService _geminiService = GeminiService();

  bool _isSpeechListening = false;
  bool _isSpeaking = false;
  bool _isLoadingResponse = false;

  final List<Map<String, String>> _conversation = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeGemini();
    _initSpeech();
    _startIntroduction();
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    _scrollController.dispose();
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
      safePrint("Speech initialization failed: $e");
    }
  }

  void _startIntroduction() async {
    const intro = "Welcome to Voice Bible Study. I am your scripture study guide. Ask me any question about the Bible, request a specific verse explanation, or share a reflection.";
    setState(() {
      _conversation.add({'role': 'assistant', 'text': intro});
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
    _speakText(intro);
  }

  void _speakText(String text) async {
    try {
      setState(() => _isSpeaking = true);
      await _tts.stop();
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.48);

      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = false);
          _listenToUser();
        }
      });

      // Clean markdown artifacts
      final cleanText = text.replaceAll(RegExp(r'[*#_`]'), '');
      await _tts.speak(cleanText);
    } catch (e) {
      safePrint("TTS Speak error: $e");
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  void _listenToUser() async {
    if (_isLoadingResponse || _isSpeaking) return;
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          safePrint("STT status: $status");
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isSpeechListening) {
              setState(() => _isSpeechListening = false);
            }
          }
        },
        onError: (error) => safePrint("STT error: $error"),
      );

      if (available) {
        setState(() => _isSpeechListening = true);
        await _speech.listen(
          onResult: (val) {
            if (val.finalResult) {
              final text = val.recognizedWords.trim();
              if (text.isNotEmpty) {
                _processUserMessage(text);
              }
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenFor: const Duration(seconds: 60),
            pauseFor: const Duration(seconds: 5),
            listenMode: stt.ListenMode.dictation,
          ),
        );
      }
    } catch (e) {
      safePrint("STT start error: $e");
    }
  }

  void _processUserMessage(String userText) async {
    setState(() {
      _conversation.add({'role': 'user', 'text': userText});
      _isLoadingResponse = true;
      _isSpeechListening = false;
    });
    _scrollToBottom();

    // Context instructions for scripture guidance
    final prompt = """
You are a warm, wise, and precise Bible study guide. 
The user is speaking to you verbally in a real-time study session.
Explain scriptures, answer theological questions, and provide historical and practical applications based STRICTLY on the Bible. 
At the end of your explanation, ask ONE engaging follow-up reflection question to encourage the user to continue the dialogue.

Keep your response under 100 words so that it is short, engaging, and suitable to be read out loud.

User spoke: "$userText"
""";

    try {
      final response = await _geminiService.sendMessageOneShot(
        prompt,
        systemInstruction: "You are a precise Bible study guide. Only scripture-based discussions are allowed.",
        feature: 'bible_study',
        maxTokens: 1000,
      );

      if (mounted) {
        setState(() => _isLoadingResponse = false);
        if (response != null && response.trim().isNotEmpty) {
          setState(() {
            _conversation.add({'role': 'assistant', 'text': response});
          });
          _scrollToBottom();
          _speakText(response);
        } else {
          _speakText("I didn't quite catch that. Could you ask again?");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingResponse = false);
        _speakText("Sorry, I encountered an issue connecting to the study database. Please try again.");
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
          text: 'Conversational Bible Study 🎙️',
          color: theme.accentTxt,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Icon(Icons.arrow_back_ios, color: theme.accentTxt, size: 20)
            .rippleClick(() => Navigator.of(context).pop()),
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
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    itemCount: _conversation.length,
                    itemBuilder: (context, index) {
                      final item = _conversation[index];
                      final isUser = item['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(14),
                            border: Border.all(
                              color: isUser ? theme.primaryBase.withOpacity(0.2) : Colors.white12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SecondaryText(
                                  text: isUser ? 'You' : 'Bible Guide',
                                  fontSize: 11,
                                  color: isUser ? theme.primaryBase : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                ),
                                6.verticalSpace,
                                PrimaryText(
                                  text: item['text']!,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoadingResponse)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(theme.primaryBase),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (_isSpeechListening) {
                                    _speech.stop();
                                    setState(() => _isSpeechListening = false);
                                  } else {
                                    _listenToUser();
                                  }
                                },
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isSpeechListening
                                        ? theme.errorPrimary
                                        : (_isSpeaking ? Colors.white10 : theme.primaryBase),
                                    boxShadow: _isSpeechListening
                                        ? [
                                            BoxShadow(
                                              color: theme.errorPrimary.withOpacity(0.4),
                                              blurRadius: 15,
                                              spreadRadius: 5,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Icon(
                                    _isSpeechListening
                                        ? Icons.mic
                                        : (_isSpeaking ? Icons.volume_up : Icons.mic_none),
                                    size: 30,
                                    color: _isSpeechListening
                                        ? Colors.white
                                        : (_isSpeaking ? Colors.white70 : Colors.black),
                                  ),
                                ),
                              ),
                              12.verticalSpace,
                              PrimaryText(
                                text: _isSpeechListening
                                    ? "Listening... Speak now"
                                    : (_isSpeaking ? "Bible Guide Speaking..." : "Tap to Speak"),
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ],
                      ),
                      12.verticalSpace,
                      SecondaryText(
                        text: "Ask questions like 'Explain Psalm 23' or 'What does Romans 8:28 mean?'",
                        fontSize: 11,
                        color: Colors.white30,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
