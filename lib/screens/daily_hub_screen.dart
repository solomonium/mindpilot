import 'package:mindpilot/export.dart';

class DailyHubScreen extends StatefulWidget {
  const DailyHubScreen({super.key});

  @override
  State<DailyHubScreen> createState() => _DailyHubScreenState();
}

class _DailyHubScreenState extends State<DailyHubScreen> {
  List<Map<String, dynamic>> _todayQuizzes = [];
  bool _isLoading = true;
  double _bibleKnowledge = 0.0;
  int _bibleGrowth = 0;

  List<Map<String, dynamic>> _meetingRatings = [];
  bool _isLoadingMeetings = true;

  @override
  void initState() {
    super.initState();
    _loadDailyQuizData();
    _loadMeetingRatings();
  }

  Future<void> _loadDailyQuizData() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final dateIso = startOfToday.toIso8601String();

    try {
      final results = await DatabaseHelper().getQuizResultsSince(dateIso);
      int totalScore = 0;
      int totalQuestions = 0;

      for (var q in results) {
        totalScore += (q['score'] as int? ?? 0);
        totalQuestions += (q['total_questions'] as int? ?? 0);
      }

      if (mounted) {
        setState(() {
          _todayQuizzes = results;
          _bibleKnowledge = totalQuestions > 0
              ? (totalScore / totalQuestions) * 100
              : 0.0;
          _bibleGrowth = results.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMeetingRatings() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final ratings = await DatabaseHelper().getMeetingRatingsForDate(today);
      if (mounted) {
        setState(() {
          _meetingRatings = ratings;
          _isLoadingMeetings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMeetings = false);
    }
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final authStore = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'Daily Hub',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.arrow_back_ios, color: theme.accentTxt, size: 20),
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
                    text: 'Your Quests & Guidance',
                    color: theme.accentTxt,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  8.verticalSpace,
                  SecondaryText(
                    text:
                        'Boost your focus, chat with your AI pilot, and complete daily clarity tasks.',
                    color: theme.accentTxt.withOpacity(0.6),
                    fontSize: 13,
                  ),
                  24.verticalSpace,

                  // 1. First Win Banner (if not completed)
                  if (!authStore.hasCompletedFirstSession) ...[
                    GuidedFirstSessionBanner(
                      personalization: authStore.personalization,
                    ),
                    24.verticalSpace,
                  ],

                  // 2. Ask Mind Pilot Card
                  _buildAskMindPilotCard(context, theme),
                  24.verticalSpace,

                  // 3. Bible Quiz Log & Stats Section
                  _buildBibleQuizSection(context, theme),
                  24.verticalSpace,

                  // 4. Meeting Productivity (Google users only)
                  // if (GoogleCalendarService().isGoogleUser) ...[
                  //   _buildMeetingProductivitySection(context, theme),
                  //   24.verticalSpace,
                  // ],

                  // 5. Daily Quests Card
                  const DailyQuestsCard(),
                  120.verticalSpace,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAskMindPilotCard(BuildContext context, AppTheme theme) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      gradient: theme.glassGradient,
      border: Border.all(color: theme.primaryBase.withOpacity(0.25)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: theme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 22,
            ),
          ),
          12.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrimaryText(
                  text: 'Ask MindPilot',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.accentTxt,
                ),
                4.verticalSpace,
                SecondaryText(
                  text: 'Get personalized guidance and clarify ideas anytime',
                  fontSize: 12,
                  color: theme.accentTxt.withOpacity(0.6),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: theme.primaryBase, size: 16),
        ],
      ),
    ).rippleClick(() {
      final notif = context.read<NotificationProvider>();
      String? prompt;
      if (notif.dailyInsight.isNotEmpty && notif.dailyInsight != '...') {
        prompt =
            "Help me understand today's insight: \"${notif.dailyInsight}\"";
      }
      context.push(AiChatScreen(initialMessage: prompt));
    });
  }

  Widget _buildBibleQuizSection(BuildContext context, AppTheme theme) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      border: Border.all(color: theme.primaryBase.withOpacity(0.25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, color: theme.primaryBase, size: 22),
              12.horizontalSpace,
              PrimaryText(
                text: 'Daily Bible Study & Quiz',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.accentTxt,
              ),
            ],
          ),
          16.verticalSpace,
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.accentTxt.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SecondaryText(
                        text: 'Bible Knowledge',
                        fontSize: 11,
                        color: theme.accentTxt.withOpacity(0.5),
                      ),
                      8.verticalSpace,
                      PrimaryText(
                        text: '${_bibleKnowledge.toInt()}%',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryBase,
                      ),
                    ],
                  ),
                ),
              ),
              12.horizontalSpace,
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.accentTxt.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SecondaryText(
                        text: 'Daily Growth',
                        fontSize: 11,
                        color: theme.accentTxt.withOpacity(0.5),
                      ),
                      8.verticalSpace,
                      PrimaryText(
                        text:
                            '$_bibleGrowth ${_bibleGrowth == 1 ? "Quiz" : "Quizzes"}',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.successPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          20.verticalSpace,
          const Divider(color: Colors.white10, height: 1),
          16.verticalSpace,
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_todayQuizzes.isEmpty) ...[
            SecondaryText(
              text:
                  'No quizzes completed today yet. Start a Bible study or quiz session to log your daily growth.',
              fontSize: 12,
              color: theme.accentTxt.withOpacity(0.6),
            ),
            16.verticalSpace,
            CustomButton(
              label: 'Start Bible Quiz',
              onPressed: () {
                context
                    .push(const BibleMainScreen())
                    .then((_) => _loadDailyQuizData());
              },
            ),
          ] else ...[
            PrimaryText(
              text: 'Today\'s Quiz Logs',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.accentTxt,
            ),
            12.verticalSpace,
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todayQuizzes.length,
              itemBuilder: (context, index) {
                final quiz = _todayQuizzes[index];
                final chapter = quiz['chapter'] as String? ?? 'General';
                final score = quiz['score'] as int? ?? 0;
                final total = quiz['total_questions'] as int? ?? 0;
                final dateStr = quiz['date'] as String? ?? '';
                final type = quiz['quiz_type'] as String? ?? 'General';
                final time = _formatTime(dateStr);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.primaryBase.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.quiz,
                          color: theme.primaryBase,
                          size: 16,
                        ),
                      ),
                      12.horizontalSpace,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PrimaryText(
                              text: chapter,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.accentTxt,
                            ),
                            4.verticalSpace,
                            SecondaryText(
                              text: '$type • $time',
                              fontSize: 11,
                              color: theme.accentTxt.withOpacity(0.4),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          PrimaryText(
                            text: '$score / $total',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: score == total
                                ? theme.successPrimary
                                : theme.accentTxt,
                          ),
                          4.verticalSpace,
                          SecondaryText(
                            text: 'correct',
                            fontSize: 10,
                            color: theme.accentTxt.withOpacity(0.4),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeetingProductivitySection(
    BuildContext context,
    AppTheme theme,
  ) {
    const List<String> _emojis = ['', '😩', '😐', '🙂', '😊', '🚀'];

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      border: Border.all(color: theme.primaryBase.withOpacity(0.25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.videocam, color: theme.primaryBase, size: 22),
              12.horizontalSpace,
              Expanded(
                child: PrimaryText(
                  text: 'Meeting Productivity',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.accentTxt,
                ),
              ),
              GestureDetector(
                onTap: _loadMeetingRatings,
                child: Icon(
                  Icons.refresh,
                  color: theme.accentTxt.withOpacity(0.4),
                  size: 18,
                ),
              ),
            ],
          ),
          16.verticalSpace,
          if (_isLoadingMeetings)
            const Center(child: CircularProgressIndicator())
          else if (_meetingRatings.isEmpty) ...[
            SecondaryText(
              text:
                  'No meeting ratings yet today. Rate your meetings from the Home screen to track productivity.',
              fontSize: 12,
              color: theme.accentTxt.withOpacity(0.6),
            ),
          ] else ...[
            // Avg score metric
            if (_meetingRatings.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.accentTxt.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    PrimaryText(
                      text:
                          _emojis[(_meetingRatings
                                      .map((r) => r['rating'] as int? ?? 0)
                                      .reduce((a, b) => a + b) /
                                  _meetingRatings.length)
                              .round()
                              .clamp(1, 5)],
                      fontSize: 28,
                    ),
                    16.horizontalSpace,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SecondaryText(
                            text: 'Avg Meeting Score',
                            fontSize: 11,
                            color: theme.accentTxt.withOpacity(0.5),
                          ),
                          4.verticalSpace,
                          PrimaryText(
                            text:
                                '${((_meetingRatings.map((r) => r['rating'] as int? ?? 0).reduce((a, b) => a + b) / _meetingRatings.length) * 20).toInt()}%',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryBase,
                          ),
                        ],
                      ),
                    ),
                    SecondaryText(
                      text:
                          '${_meetingRatings.length} meeting${_meetingRatings.length == 1 ? '' : 's'}',
                      fontSize: 11,
                      color: theme.accentTxt.withOpacity(0.4),
                    ),
                  ],
                ),
              ),
              16.verticalSpace,
            ],
            // Individual ratings
            PrimaryText(
              text: 'Today\'s Rated Meetings',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.accentTxt,
            ),
            12.verticalSpace,
            ...(_meetingRatings.map((r) {
              final title = r['title'] as String? ?? 'Meeting';
              final rating = r['rating'] as int? ?? 0;
              final notes = r['notes'] as String? ?? '';
              final scheduledAt = r['scheduled_at'] as String? ?? '';
              String timeStr = '';
              try {
                timeStr = DateFormat(
                  'h:mm a',
                ).format(DateTime.parse(scheduledAt));
              } catch (_) {}
              final emoji = rating >= 1 && rating <= 5 ? _emojis[rating] : '❓';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 24)),
                    12.horizontalSpace,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PrimaryText(
                            text: title,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.accentTxt,
                            textOverflow: TextOverflow.ellipsis,
                          ),
                          4.verticalSpace,
                          SecondaryText(
                            text: timeStr.isNotEmpty ? timeStr : 'Today',
                            fontSize: 11,
                            color: theme.accentTxt.withOpacity(0.4),
                          ),
                          if (notes.isNotEmpty) ...[
                            4.verticalSpace,
                            SecondaryText(
                              text: notes,
                              fontSize: 11,
                              color: theme.accentTxt.withOpacity(0.55),
                              maxLines: 2,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryBase.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PrimaryText(
                        text: '${rating * 20}%',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryBase,
                      ),
                    ),
                  ],
                ),
              );
            })),
          ],
        ],
      ),
    );
  }
}
