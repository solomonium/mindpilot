import 'dart:ui';
import 'package:mindpilot/export.dart';

class GroupQuizScreen extends StatefulWidget {
  final String groupId;
  const GroupQuizScreen({super.key, required this.groupId});

  @override
  State<GroupQuizScreen> createState() => _GroupQuizScreenState();
}

class _GroupQuizScreenState extends State<GroupQuizScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _resultsDialogShown = false;
  bool _isGameCompleted = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupQuizProvider>().listenToGroup(widget.groupId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Helper to dynamically build the chatbot messages list from Firestore state
  List<Map<String, dynamic>> _reconstructChatThread(
      Map<String, dynamic> groupData, Map<String, dynamic> gameData) {
    final List<Map<String, dynamic>> messages = [];

    // 1. Initial Greeting
    messages.add({
      'sender': 'MindPilot Host AI 🤖',
      'text': "Welcome to the Group Bible Quiz! Let's test your scripture knowledge. 📖",
      'isAi': true,
    });

    final questions = gameData['questions'] as List<dynamic>? ?? [];
    final playerAnswers = gameData['playerAnswers'] as Map<String, dynamic>? ?? {};
    final turnOrder = gameData['turnOrder'] as List<dynamic>? ?? [];
    final membersMap = groupData['members'] as Map<String, dynamic>? ?? {};

    final int currentIndex = gameData['currentQuestionIndex'] as int? ?? 0;
    final String status = gameData['status'] as String? ?? 'playing';

    // Walk through all questions up to current active question or all of them if completed
    final int limit = status == 'completed' ? questions.length : currentIndex;

    for (int i = 0; i < limit; i++) {
      if (i >= questions.length) break;

      final playerUid = turnOrder[i % turnOrder.length] as String;
      final playerEmail = membersMap[playerUid]?['email'] ?? 'player';
      final playerName = membersMap[playerUid]?['displayName'] ?? playerEmail;

      final q = questions[i] as Map<String, dynamic>;
      final qText = q['questionText'] ?? q['question'] ?? '';

      // AI asks the question
      messages.add({
        'sender': 'MindPilot Host AI 🤖',
        'text': 'To **@$playerName**, here is your question:',
        'question': qText,
        'isAi': true,
      });

      // Find the answer submitted by this player for their turn
      final answersList = List<int>.from(playerAnswers[playerUid] ?? []);
      final turnIdx = i ~/ turnOrder.length;

      if (turnIdx < answersList.length) {
        final answerVal = answersList[turnIdx];
        final options = List<String>.from(q['options'] ?? []);
        final correctIdx = q['correctAnswerIndex'] as int? ?? 0;

        if (answerVal == -1) {
          final correctText = (correctIdx >= 0 && correctIdx < options.length) ? options[correctIdx] : '';
          messages.add({
            'sender': playerName,
            'text': '**@$playerName** timed out! ⏱️\n\n*(The correct answer is: **$correctText**)*',
            'isAi': false,
            'isCorrect': false,
          });
        } else {
          final isCorrect = answerVal == correctIdx;
          final answerText = (answerVal >= 0 && answerVal < options.length) ? options[answerVal] : 'Skipped';
          final correctText = (correctIdx >= 0 && correctIdx < options.length) ? options[correctIdx] : '';

          String text = 'I choose: **$answerText**\n\nResult: ${isCorrect ? "Correct! +10 XP 🎉" : "Incorrect! ❌"}';
          if (!isCorrect) {
            text += '\n\n*(The correct answer is: **$correctText**)*';
          }

          messages.add({
            'sender': playerName,
            'text': text,
            'isAi': false,
            'isCorrect': isCorrect,
          });
        }
      }
    }

    // 2. Active Question (if game is still playing)
    if (status == 'playing' && currentIndex < questions.length) {
      final currentTurnUid = gameData['currentTurnPlayerUid'] as String?;
      if (currentTurnUid != null) {
        final currentTurnEmail = membersMap[currentTurnUid]?['email'] ?? 'player';
        final currentTurnName = membersMap[currentTurnUid]?['displayName'] ?? currentTurnEmail;
        final q = questions[currentIndex] as Map<String, dynamic>;
        final qText = q['questionText'] ?? q['question'] ?? '';

        messages.add({
          'sender': 'MindPilot Host AI 🤖',
          'text': '**@$currentTurnName**, it is your turn! 🧠',
          'question': qText,
          'isAi': true,
          'isCurrent': true,
        });
      }
    }

    return messages;
  }

  void _showResultsDialog(BuildContext context, Map<String, dynamic> groupData, Map<String, dynamic> gameData) {
    if (_resultsDialogShown) return;
    _resultsDialogShown = true;
    AnalyticsService.logGroupQuizAction('completed', groupId: widget.groupId);

    final scores = gameData['scores'] as Map<String, dynamic>? ?? {};
    final membersMap = groupData['members'] as Map<String, dynamic>? ?? {};
    final creatorUid = groupData['createdBy'] as String?;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isCreator = creatorUid == currentUid;

    // Sort scores descending
    final scoreEntries = scores.entries.toList();
    scoreEntries.sort((a, b) => (b.value as int).compareTo(a.value as int));

    final totalQs = gameData['questionCount'] ?? 5;
    final groupName = groupData['name'] ?? 'Bible Quiz';
    final scopeVal = gameData['scopeValue'] ?? 'General Knowledge';
    final scopeType = gameData['scopeType'] ?? 'general';
    String scopeShortName;
    switch (scopeType) {
      case 'general':
        scopeShortName = 'Bible';
        break;
      case 'chapter':
        scopeShortName = 'Bible Chapter';
        break;
      case 'tech':
        scopeShortName = 'Technology';
        break;
      case 'science':
        scopeShortName = 'Science';
        break;
      case 'english':
        scopeShortName = 'English';
        break;
      case 'economics':
        scopeShortName = 'Economics';
        break;
      case 'mindfulness':
        scopeShortName = 'Mindfulness';
        break;
      case 'custom':
        scopeShortName = scopeVal.trim().isNotEmpty ? scopeVal.trim() : 'Custom Topic';
        break;
      default:
        scopeShortName = 'Bible';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        AppTheme theme = dialogContext.watch();
        final questionsPerPlayer = gameData['questionsPerPlayer'] ?? (totalQs ~/ scoreEntries.length);

        return AlertDialog(
          backgroundColor: theme.brandDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 50),
              12.verticalSpace,
              PrimaryText(
                text: '$scopeShortName Quiz Results 🏆',
                color: theme.accentTxt,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              6.verticalSpace,
              SecondaryText(
                text: 'Total Questions: $totalQs',
                color: theme.accentTxt.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: scoreEntries.length,
              itemBuilder: (context, index) {
                final entry = scoreEntries[index];
                final uid = entry.key;
                final score = entry.value as int;
                final email = membersMap[uid]?['email'] ?? 'player@email.com';
                final name = membersMap[uid]?['displayName'] ?? email;

                String medal = '🥈';
                if (index == 0) medal = '🥇';
                if (index == 2) medal = '🥉';
                if (index > 2) medal = '🎖️';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      PrimaryText(text: medal, fontSize: 18),
                      12.horizontalSpace,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PrimaryText(
                              text: name,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.accentTxt,
                            ),
                            SecondaryText(
                              text: email,
                              fontSize: 11,
                              color: theme.accentTxt.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                      PrimaryText(
                        text: '$score out of $questionsPerPlayer',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryBase,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryBase,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final questionsPerPlayer = gameData['questionsPerPlayer'] ?? (totalQs ~/ scoreEntries.length);
                    final shareCard = Container(
                      width: 360,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.brandDark,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.primaryBase.withOpacity(0.2), width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.emoji_events, color: Colors.amber, size: 56),
                          16.verticalSpace,
                          PrimaryText(
                            text: '$scopeShortName Quiz Results 🏆',
                            color: theme.accentTxt,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            textAlign: TextAlign.center,
                          ),
                          6.verticalSpace,
                          SecondaryText(
                            text: 'Total Questions: $totalQs',
                            color: theme.accentTxt.withOpacity(0.6),
                            fontSize: 12,
                          ),
                          8.verticalSpace,
                          SecondaryText(
                            text: 'Group: "$groupName"',
                            color: theme.accentTxt.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          SecondaryText(
                            text: 'Scope: $scopeVal',
                            color: theme.accentTxt.withOpacity(0.6),
                            fontSize: 12,
                          ),
                          24.verticalSpace,
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: scoreEntries.length,
                            itemBuilder: (context, index) {
                              final entry = scoreEntries[index];
                              final uid = entry.key;
                              final score = entry.value as int;
                              final email = membersMap[uid]?['email'] ?? 'player@email.com';
                              final name = membersMap[uid]?['displayName'] ?? email;

                              String medal = '🥈';
                              if (index == 0) medal = '🥇';
                              if (index == 2) medal = '🥉';
                              if (index > 2) medal = '🎖️';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                child: Row(
                                  children: [
                                    PrimaryText(text: medal, fontSize: 20),
                                    14.horizontalSpace,
                                    Expanded(
                                      child: PrimaryText(
                                        text: name,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: theme.accentTxt,
                                        textOverflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    PrimaryText(
                                      text: '$score out of $questionsPerPlayer',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryBase,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          24.verticalSpace,
                          const Divider(color: Colors.white10, height: 1),
                          16.verticalSpace,
                          SecondaryText(
                            text: (scopeType == 'general' || scopeType == 'chapter')
                                ? 'Study scripture and challenge friends in real-time!'
                                : 'Challenge friends and test your knowledge in real-time!',
                            color: theme.accentTxt.withOpacity(0.5),
                            fontSize: 11,
                            textAlign: TextAlign.center,
                          ),
                          4.verticalSpace,
                          PrimaryText(
                            text: 'Download MindPilot App 🚀',
                            color: theme.primaryBase,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );

                    ShareService.captureAndShare(
                      dialogContext,
                      widget: shareCard,
                      text: 'Check out our Group $scopeShortName Quiz results on MindPilot!${(scopeType == 'general' || scopeType == 'chapter') ? " 📖" : ""}🏆',
                      subject: 'MindPilot $scopeShortName Quiz Results',
                    );
                  },
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share Scores', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                12.verticalSpace,
                TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    _resultsDialogShown = false;
                    if (isCreator) {
                      await context.read<GroupQuizProvider>().endAndResetGame();
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop(); // Back to lobby
                    }
                  },
                  child: PrimaryText(
                    text: 'Back to Lobby',
                    color: theme.primaryBase,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final provider = context.watch<GroupQuizProvider>();

    final groupData = provider.groupData;
    final gameData = provider.gameData;

    if (provider.activeGroupId == null || groupData == null || gameData == null) {
      if (!_isGameCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<HomeProvider>().navIndex = 2;
            Navigator.of(context).popUntil((route) => route.isFirst);
            context.showInAppNotification('The host has disbanded the game.');
          }
        });
        return Scaffold(
          backgroundColor: theme.brandDark,
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      } else {
        return Scaffold(
          backgroundColor: theme.brandDark,
          body: const Center(
            child: SecondaryText(text: 'Quiz Completed'),
          ),
        );
      }
    }

    final isCompleted = gameData['status'] == 'completed';

    // Track completion state
    if (isCompleted) {
      _isGameCompleted = true;
    }

    final messages = _reconstructChatThread(groupData, gameData);
    if (messages.length > _lastMessageCount) {
      _lastMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    final membersMap = groupData['members'] as Map<String, dynamic>? ?? {};
    final totalInvited = membersMap.length;
    final joinedCount = membersMap.values.where((m) => m['status'] == 'accepted').length;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final expectedTurnUid = gameData['currentTurnPlayerUid'] as String?;
    final isMyTurn = currentUid == expectedTurnUid && !isCompleted;
    final currentTurnName = (expectedTurnUid != null)
        ? (membersMap[expectedTurnUid]?['displayName'] ?? membersMap[expectedTurnUid]?['email'] ?? 'player')
        : 'player';

    final int currentIndex = gameData['currentQuestionIndex'] as int? ?? 0;
    final questions = gameData['questions'] as List<dynamic>? ?? [];
    final currentQuestion = (currentIndex < questions.length) ? questions[currentIndex] as Map<String, dynamic>? : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryText(
              text: 'Group Quiz Arena ⚔️',
              color: theme.accentTxt,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
            if (questions.isNotEmpty) ...[
              4.verticalSpace,
              SecondaryText(
                text: isCompleted
                    ? 'Quiz Completed'
                    : 'Question ${currentIndex + 1} of ${questions.length} (${questions.length - currentIndex} remaining)',
                color: theme.primaryBase,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ],
          ],
        ),
        centerTitle: true,
        leading: Icon(Icons.close, color: theme.accentTxt, size: 20)
            .rippleClick(() {
          // Warning before leaving
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: theme.brandDark,
              title: PrimaryText(text: 'Leave Game?', color: theme.accentTxt),
              content: SecondaryText(text: 'If you leave, you will forfeit this game.', color: theme.accentTxt.withOpacity(0.7)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: SecondaryText(text: 'Stay', color: theme.accentTxt.withOpacity(0.6)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    provider.leaveGroup();
                    context.read<HomeProvider>().navIndex = 2;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: PrimaryText(text: 'Leave', color: theme.errorPrimary),
                ),
              ],
            ),
          );
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
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people, color: theme.primaryBase, size: 20),
                          12.horizontalSpace,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PrimaryText(
                                  text: 'Group Members ($joinedCount of $totalInvited Joined)',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.accentTxt,
                                ),
                                4.verticalSpace,
                                SecondaryText(
                                  text: 'Active: ${membersMap.values
                                      .where((m) => m['status'] == 'accepted')
                                      .map((m) => m['displayName'] ?? m['email'] ?? 'player')
                                      .join(', ')}',
                                  fontSize: 11,
                                  color: theme.accentTxt.withOpacity(0.6),
                                  textOverflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Chat conversation list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isAi = msg['isAi'] as bool? ?? false;
                    final isCurrent = msg['isCurrent'] as bool? ?? false;

                    return Align(
                      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isAi
                              ? (isCurrent ? theme.primaryBase.withOpacity(0.1) : Colors.white.withOpacity(0.05))
                              : (msg['isCorrect'] == true ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15)),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isAi ? Radius.zero : const Radius.circular(16),
                            bottomRight: isAi ? const Radius.circular(16) : Radius.zero,
                          ),
                          border: Border.all(
                            color: isAi
                                ? (isCurrent ? theme.primaryBase.withOpacity(0.3) : Colors.white10)
                                : (msg['isCorrect'] == true ? Colors.greenAccent.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PrimaryText(
                              text: msg['sender'] ?? 'User',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isAi ? theme.primaryBase : theme.accentTxt.withOpacity(0.8),
                            ),
                            8.verticalSpace,
                            MarkdownBody(
                              data: msg['text'] ?? '',
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(color: theme.accentTxt, fontSize: 14, height: 1.4),
                                strong: TextStyle(color: theme.primaryBase, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (msg['question'] != null) ...[
                              12.verticalSpace,
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCCFF00).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFCCFF00).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: PrimaryText(
                                  text: msg['question']!,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFCCFF00),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Interactive Answer Options panel
              if (!isCompleted) ...[
                // Timer
                _buildTimerIndicator(theme, provider),
                
                if (currentQuestion != null)
                  _buildInteractiveAnswers(
                    theme,
                    provider,
                    currentQuestion,
                    isMyTurn,
                    currentTurnName,
                  )
                else
                  _buildWaitingPanel(theme, groupData, gameData),
              ] else ...[
                GlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  borderRadius: 0,
                  border: const Border(top: BorderSide(color: Colors.white10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PrimaryText(
                        text: "Hope you've learnt something! 💡",
                        color: theme.accentTxt.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        textAlign: TextAlign.center,
                      ),
                      12.verticalSpace,
                      CustomButton(
                        key: const ValueKey('view_group_results_button'),
                        label: 'Proceed to Results 🏆',
                        onPressed: () {
                          _showResultsDialog(context, groupData, gameData);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerIndicator(AppTheme theme, GroupQuizProvider provider) {
    final seconds = provider.secondsRemaining;
    final total = provider.timerSeconds;
    final progress = (total > 0) ? (seconds / total) : 0.0;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation<Color>(
            seconds < 6 ? theme.errorPrimary : theme.primaryBase,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SecondaryText(text: 'Question Timer', color: theme.accentTxt.withOpacity(0.5), fontSize: 11),
              PrimaryText(
                text: '00:${seconds.toString().padLeft(2, '0')}',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: seconds < 6 ? theme.errorPrimary : theme.accentTxt,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveAnswers(
      AppTheme theme,
      GroupQuizProvider provider,
      Map<String, dynamic> question,
      bool isMyTurn,
      String currentTurnName) {
    final options = List<String>.from(question['options'] ?? []);

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 0,
      border: const Border(top: BorderSide(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryText(
            text: isMyTurn
                ? 'Your Turn to Answer! Select Options:'
                : 'Question Options (Waiting for @$currentTurnName):',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isMyTurn ? theme.primaryBase : theme.accentTxt.withOpacity(0.6),
          ),
          12.verticalSpace,
          ...List.generate(options.length, (index) {
            final optionWidget = GlassContainer(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              border: Border.all(
                color: isMyTurn ? Colors.white24 : Colors.white12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isMyTurn
                          ? theme.primaryBase.withOpacity(0.1)
                          : Colors.white10,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isMyTurn ? theme.primaryBase : Colors.white24,
                      ),
                    ),
                    child: Center(
                      child: PrimaryText(
                        text: String.fromCharCode(65 + index),
                        fontSize: 12,
                        color: isMyTurn ? theme.primaryBase : theme.accentTxt.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  16.horizontalSpace,
                  Expanded(
                    child: SecondaryText(
                      text: options[index],
                      color: isMyTurn ? theme.accentTxt : theme.accentTxt.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );

            if (isMyTurn) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: optionWidget.rippleClick(() {
                  final correctIdx = question['correctAnswerIndex'] as int? ?? 0;
                  final isCorrect = index == correctIdx;
                  AnalyticsService.logGroupQuizAction(
                    isCorrect ? 'answered_correct' : 'answered_incorrect',
                    groupId: widget.groupId,
                  );
                  provider.submitAnswer(index);
                }),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Opacity(
                  opacity: 0.7,
                  child: optionWidget,
                ),
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _buildWaitingPanel(
      AppTheme theme, Map<String, dynamic> groupData, Map<String, dynamic> gameData) {
    final currentTurnUid = gameData['currentTurnPlayerUid'] as String?;
    final membersMap = groupData['members'] as Map<String, dynamic>? ?? {};
    final currentTurnName = (currentTurnUid != null)
        ? (membersMap[currentTurnUid]?['displayName'] ?? membersMap[currentTurnUid]?['email'] ?? 'player')
        : 'player';

    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      borderRadius: 0,
      border: const Border(top: BorderSide(color: Colors.white10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
          16.horizontalSpace,
          Flexible(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.inter(
                  color: theme.accentTxt.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                children: [
                  const TextSpan(text: 'Waiting for '),
                  TextSpan(
                    text: '@$currentTurnName',
                    style: TextStyle(
                      color: theme.primaryBase,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: ' to answer...'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
