import 'package:mindpilot/export.dart';

class ProgressReportScreen extends StatefulWidget {
  const ProgressReportScreen({super.key});

  @override
  State<ProgressReportScreen> createState() => _ProgressReportScreenState();
}

class _ProgressReportScreenState extends State<ProgressReportScreen> {
  bool _tempUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().loadWeeklyStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Consumer3<JournalProvider, TaskProvider, HomeProvider>(
      builder: (context, journal, taskStore, homeStore, _) {
        final isPro = context.watch<AppAuthProvider>().isPro || _tempUnlocked;

        // Calculate dynamic values
        final taskRate =
            taskStore.totalCount > 0 ? taskStore.completedCount / taskStore.totalCount : 0.0;
        final focusScore = (journal.totalFocusMinutes / 120).clamp(0.0, 1.0); // Goal: 2 hours
        
        final double overallGrowth;
        if (homeStore.weeklyQuizzes > 0) {
          final quizXpScore = (homeStore.weeklyQuizXp / 250).clamp(0.0, 1.0);
          overallGrowth = ((taskRate * 0.3) + (focusScore * 0.3) + ((homeStore.bibleKnowledgeScore / 100) * 0.2) + (quizXpScore * 0.2)) * 100;
        } else {
          overallGrowth = ((taskRate * 0.6) + (focusScore * 0.4)) * 100;
        }

        // Focus areas
        final decisionScore = (journal.entries.length / 10).clamp(0.0, 1.0); // Goal: 10 decisions
        final productivityScore = taskRate;
        final wellbeingScore = (journal.entries.where((e) => e.mood.contains('😊')).length /
                (journal.entries.isEmpty ? 1 : journal.entries.length))
            .clamp(0.4, 1.0);
        final consistencyScore = (journal.totalFocusMinutes > 0 ? 0.8 : 0.2);

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: PrimaryText(
              text: 'Growth Progress',
              color: theme.accentTxt,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            centerTitle: true,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Icon(
                Icons.arrow_back_ios,
                color: theme.accentTxt,
                size: 20,
              ).rippleClick(() => context.pop()),
            ),
            actions: [
              Icon(
                Icons.share_outlined,
                color: theme.accentTxt,
              ).rippleClick(() {
                final user = context.read<AppAuthProvider>().user;
                final downloadUrl = ConfigService().updateUrl;
                ShareService.captureAndShare(
                  context,
                  text: "Reflecting on a week of growth! 🌱 My MindPilot weekly report shows exactly where I've focused and how far I've come. Ready to start your clarity journey?\n\nDownload MindPilot: $downloadUrl\n#MindPilot #Growth #WeeklyReport",
                  widget: ShareableCard(
                    mode: ShareableCardMode.progress,
                    userName: user?.displayName,
                    focusTime: '${homeStore.weeklyFocusMinutes}m',
                    tasksDone: homeStore.weeklyTasks.toString(),
                    achievement: 'Weekly Growth',
                  ),
                );
              }),
              20.horizontalSpace,
            ],
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
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Weekly Clarity Report (Visible to all)
                    PrimaryText(
                      text: 'Weekly Clarity Report',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.accentTxt,
                    ),
                    16.verticalSpace,
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      gradient: theme.glassGradient,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _reportItem(context, 'Tasks Done', homeStore.weeklyTasks.toString(), Icons.check_circle, Colors.green),
                              _reportItem(context, 'Focus Time', '${homeStore.weeklyFocusMinutes}m', Icons.timer, Colors.blue),
                              _reportItem(context, 'Journals', homeStore.weeklyJournalEntries.toString(), Icons.book, Colors.purple),
                              _reportItem(context, 'Quiz XP', '+${homeStore.weeklyQuizXp} XP', Icons.bolt, Colors.amber),
                            ],
                          ),
                          16.verticalSpace,
                          SecondaryText(
                            text: 'Total progress in the last 7 days.',
                            fontSize: 11,
                            color: theme.accentTxt.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                    32.verticalSpace,

                    if (!isPro) ...[
                      // Upsell for Freemium
                      GlassContainer(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(Icons.lock_outline, color: Color(0xFFF59E0B), size: 48),
                            20.verticalSpace,
                            PrimaryText(
                              text: 'Unlock Growth Insights',
                              color: theme.accentTxt,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            12.verticalSpace,
                            SecondaryText(
                              text: 'Get detailed psychological analysis and overall growth tracking with Pro.',
                              color: theme.accentTxt.withOpacity(0.7),
                              textAlign: TextAlign.center,
                            ),
                            32.verticalSpace,
                            CustomButton(
                              label: 'Upgrade to Pro',
                              onPressed: () => AppHelper.showPaywall(
                                context,
                                feature: 'Growth Analytics',
                                onAdUnlocked: () {
                                  setState(() {
                                    _tempUnlocked = true;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Detailed Analytics for Pro
                      GlassContainer(
                        padding: const EdgeInsets.all(24),
                        gradient: theme.glassGradient,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SecondaryText(
                                text: 'Overall Growth', color: Colors.white70, fontSize: 12),
                            8.verticalSpace,
                            PrimaryText(
                              text: '${overallGrowth.toInt()}%',
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            16.verticalSpace,
                            SecondaryText(
                              text: overallGrowth > 50
                                  ? "Keep going, you're doing great!"
                                  : "Every small step counts towards clarity.",
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            20.verticalSpace,
                            SizedBox(
                              height: 60,
                              width: double.infinity,
                              child: CustomPaint(painter: ChartPainter()),
                            ),
                          ],
                        ),
                      ),
                      32.verticalSpace,
                      PrimaryText(
                          text: 'Focus Areas',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.accentTxt),
                      20.verticalSpace,
                      _focusArea(
                          context, 'Decision Clarity', decisionScore, '${(decisionScore * 100).toInt()}%'),
                      _focusArea(
                          context, 'Productivity', productivityScore, '${(productivityScore * 100).toInt()}%'),
                      _focusArea(
                          context, 'Mindfulness', wellbeingScore, '${(wellbeingScore * 100).toInt()}%'),
                      _focusArea(
                          context, 'Consistency', consistencyScore, '${(consistencyScore * 100).toInt()}%'),
                      _focusArea(
                          context, 'Bible Knowledge', homeStore.bibleKnowledgeScore / 100, '${homeStore.bibleKnowledgeScore.toInt()}%'),
                      _focusArea(
                          context, 'Bible Growth', homeStore.bibleGrowthScore / 100, '${homeStore.bibleGrowthScore.toInt()}%'),
                      _focusArea(
                          context, 'Quiz XP Progress', (homeStore.weeklyQuizXp / 250).clamp(0.0, 1.0), '${homeStore.weeklyQuizXp} XP'),
                      32.verticalSpace,
                      PrimaryText(
                          text: 'Pro Insights',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.accentTxt),
                      16.verticalSpace,
                      _insightItem(
                        context,
                        Icons.lightbulb_outline,
                        taskStore.completedCount > 0
                            ? 'You\'ve finished ${taskStore.completedCount} tasks today!'
                            : 'Start a task to boost your productivity score.',
                        const Color(0xFFF59E0B),
                      ),
                      _insightItem(
                        context,
                        Icons.timer_outlined,
                        journal.totalFocusMinutes > 0
                            ? 'Total focus time: ${journal.totalFocusMinutes} minutes.'
                            : 'Use Focus Session to improve concentration.',
                        const Color(0xFF10B981),
                      ),
                      _insightItem(
                        context,
                        Icons.menu_book_outlined,
                        homeStore.weeklyQuizzes > 0
                            ? 'Your Bible Knowledge is at ${homeStore.bibleKnowledgeScore.toInt()}% this week. Growth level is at ${homeStore.bibleGrowthScore.toInt()}%.'
                            : 'Take a daily Bible Quiz to start tracking your knowledge and spiritual growth.',
                        const Color(0xFFF59E0B),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _focusArea(BuildContext context, String label, double value, String percentage) {
    AppTheme theme = context.watch();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SecondaryText(text: label, fontSize: 13, color: theme.accentTxt.withOpacity(0.8)),
              PrimaryText(
                  text: percentage, color: theme.accentTxt, fontSize: 13, fontWeight: FontWeight.bold),
            ],
          ),
          8.verticalSpace,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: theme.accentTxt.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryBase),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportItem(BuildContext context, String label, String value, IconData icon, Color color) {
    AppTheme theme = context.watch();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        8.verticalSpace,
        PrimaryText(
          text: value,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: theme.accentTxt,
        ),
        4.verticalSpace,
        SecondaryText(
          text: label,
          fontSize: 10,
          color: theme.accentTxt.withOpacity(0.6),
        ),
      ],
    );
  }

  Widget _insightItem(BuildContext context, IconData icon, String text, Color color) {
    AppTheme theme = context.watch();
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration:
                BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          16.horizontalSpace,
          Expanded(
              child: SecondaryText(
                  text: text, fontSize: 13, color: theme.accentTxt.withOpacity(0.9))),
        ],
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(
          size.width * 0.2, size.height * 0.9, size.width * 0.4, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.6, size.height * 0.2, size.width * 0.8, size.height * 0.4)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
