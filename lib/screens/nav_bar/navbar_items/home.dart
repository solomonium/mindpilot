import 'package:mindpilot/export.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isInsightExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<HomeProvider>().loadWeeklyStats();

      // 1. Fetch Remote Config
      await ConfigService().fetchRemoteConfig();

      // 2. Check for App Update
      final currentVersion = '1.0.0'; // Should match pubspec.yaml
      final config = ConfigService();

      if (config.isUpdateRequired(currentVersion)) {
        if (mounted) {
          AppHelper.showUpdatePrompt(
            context,
            version: config.latestVersion,
            force: config.forceUpdate,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final authStore = context.watch<AuthProvider>();
    final user = authStore.user;
    final isPro = authStore.isPro;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.primaryBase.withOpacity(0.1),
                          image: user?.photoURL != null
                              ? DecorationImage(
                                  image: NetworkImage(user!.photoURL!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: theme.foundationColor.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: user?.photoURL == null
                            ? Center(
                                child: Icon(
                                  Icons.person,
                                  color: theme.primaryBase,
                                  size: 24,
                                ),
                              )
                            : null,
                      ),
                      12.horizontalSpace,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PrimaryText(
                            text:
                                '${TimeTeller.tellTimeOfTheDay()}, ${user?.displayName?.split(' ').first ?? 'User'}',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.accentTxt,
                          ),
                          SecondaryText(
                            text: R.S.readyToMake,
                            fontSize: 12,
                            color: theme.accentTxt.withOpacity(0.7),
                          ),
                          if (isPro) ...[
                            4.verticalSpace,
                            Consumer<AppProvider>(
                              builder: (context, appStore, _) {
                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.local_fire_department,
                                      color: Colors.orange,
                                      size: 14,
                                    ),
                                    4.horizontalSpace,
                                    SecondaryText(
                                      text: '${appStore.streak} Day Streak',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  Consumer<NotificationProvider>(
                    builder: (context, notifStore, _) {
                      return Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.accentTxt.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_outlined,
                              size: 22,
                              color: theme.accentTxt,
                            ),
                          ).rippleClick(() {
                            context.push(const NotificationScreen());
                          }),
                          if (notifStore.unreadCount > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: theme.errorPrimary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.brandDark,
                                    width: 2,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Center(
                                  child: Text(
                                    '${notifStore.unreadCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              25.verticalSpace,
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: GlassContainer(
                  padding: const EdgeInsets.all(20),
                  gradient: theme.glassGradient,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SecondaryText(
                            text: DateFormat(
                              'EEEE, MMM dd',
                            ).format(DateTime.now()),
                            color: theme.accentTxt.withOpacity(0.8),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isPro
                                  ? const Color(0xFFF59E0B).withOpacity(0.2)
                                  : theme.accentTxt.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: SecondaryText(
                              text: isPro ? 'MindPilot Pro' : 'MindPilot Free',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isPro
                                  ? const Color(0xFFF59E0B)
                                  : theme.accentTxt,
                            ),
                          ),
                        ],
                      ),
                      SecondaryText(
                        text: R.S.dailyInsight,
                        color: theme.accentTxt.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      12.verticalSpace,
                      Consumer<NotificationProvider>(
                        builder: (context, notifStore, _) {
                          // Reset expansion if insight changed and no explanation exists
                          if (notifStore.insightExplanation == null &&
                              _isInsightExpanded) {
                            _isInsightExpanded = false;
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PrimaryText(
                                text: '"${notifStore.dailyInsight}"',
                                color: theme.accentTxt,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                              ),
                              if (_isInsightExpanded && isPro) ...[
                                16.verticalSpace,
                                if (notifStore.insightExplanation != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.primaryBase.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.primaryBase.withOpacity(
                                          0.2,
                                        ),
                                      ),
                                    ),
                                    child: _buildHighlightedText(
                                      notifStore.insightExplanation!,
                                      const Color(0xFFADFF2F), // Lemon Green
                                    ),
                                  ),
                              ],
                            ],
                          );
                        },
                      ),
                      20.verticalSpace,
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Consumer<NotificationProvider>(
                            builder: (context, notifStore, _) {
                              if (notifStore.isFetchingExplanation) {
                                return SizedBox(
                                  key: const ValueKey('spinner'),
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.primaryBase,
                                    ),
                                  ),
                                );
                              }

                              if (_isInsightExpanded &&
                                  isPro &&
                                  notifStore.fetchError == null) {
                                return Icon(
                                  Icons.keyboard_arrow_up,
                                  key: const ValueKey('arrow_up'),
                                  color: theme.accentTxt.withOpacity(0.6),
                                  size: 28,
                                ).rippleClick(
                                  () => setState(
                                    () => _isInsightExpanded = false,
                                  ),
                                );
                              }

                              final hasError = notifStore.fetchError != null;

                              return Row(
                                key: const ValueKey('explain_button'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasError
                                        ? Icons.refresh
                                        : Icons.psychology_outlined,
                                    color: hasError
                                        ? theme.errorPrimary
                                        : theme.accentTxt.withOpacity(0.6),
                                    size: 20,
                                  ),
                                  8.horizontalSpace,
                                  SecondaryText(
                                    text: hasError
                                        ? notifStore.fetchError!
                                        : 'Explain',
                                    color: hasError
                                        ? theme.errorPrimary
                                        : theme.accentTxt.withOpacity(0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ],
                              ).rippleClick(() async {
                                if (!isPro) {
                                  AppHelper.showPaywall(
                                    context,
                                    feature: 'Daily Explanation',
                                  );
                                } else {
                                  // Start fetching
                                  await context
                                      .read<NotificationProvider>()
                                      .fetchInsightExplanation();
                                  // Expand once done if no error
                                  if (mounted &&
                                      context
                                              .read<NotificationProvider>()
                                              .fetchError ==
                                          null) {
                                    setState(() => _isInsightExpanded = true);
                                  }
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              20.verticalSpace,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PrimaryText(
                    text: R.S.quickActions,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.accentTxt,
                  ),
                  Row(
                    children: [
                      PrimaryText(
                        text: 'Weekly report clarity',
                        color: theme.accentTxt.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      4.horizontalSpace,
                      Icon(
                        Icons.chevron_right,
                        color: theme.accentTxt.withOpacity(0.5),
                        size: 16,
                      ),
                    ],
                  ).rippleClick(() {
                    context.push(const ProgressReportScreen());
                  }),
                ],
              ),
              16.verticalSpace,
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _actionCard(
                        context,
                        'Decision Analyzer',
                        'Make better choices',
                        Icons.psychology,
                        theme.primaryBase,
                      ),
                    ),
                    12.horizontalSpace,
                    Expanded(
                      child: _actionCard(
                        context,
                        'Focus Session',
                        'Improve focus',
                        Icons.timer_outlined,
                        theme.successPrimary,
                      ),
                    ),
                    12.horizontalSpace,
                    Expanded(
                      child: _actionCard(
                        context,
                        'Create Task',
                        'Set new goals',
                        Icons.add_task,
                        theme.errorPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              16.verticalSpace,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PrimaryText(
                    text: R.S.todaysProgress,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.accentTxt,
                  ),
                  Row(
                    children: [
                      PrimaryText(
                        text: 'View all',
                        color: theme.accentTxt.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      4.horizontalSpace,
                      Icon(
                        Icons.chevron_right,
                        color: theme.accentTxt.withOpacity(0.5),
                        size: 16,
                      ),
                    ],
                  ).rippleClick(() {
                    context.push(const ProgressReportScreen());
                  }),
                ],
              ),
              16.verticalSpace,
              Consumer2<JournalProvider, TaskProvider>(
                builder: (context, journal, taskStore, _) {
                  final totalMinutes = journal.totalFocusMinutes;
                  final hours = totalMinutes ~/ 60;
                  final minutes = totalMinutes % 60;
                  String focusTimeText = hours > 0
                      ? '${hours}h ${minutes}m'
                      : '${minutes}m';

                  String tasksText =
                      '${taskStore.completedCount}/${taskStore.totalCount}';

                  int points =
                      (taskStore.completedCount * 10) + (totalMinutes ~/ 5);
                  String achievement = 'Level ${1 + (points ~/ 50)}';

                  return Row(
                    children: [
                      Expanded(
                        child: _progressStat(
                          'Focus Time',
                          focusTimeText,
                          Icons.access_time,
                        ),
                      ),
                      12.horizontalSpace,
                      Expanded(
                        child: _progressStat(
                          'Achievement',
                          achievement,
                          Icons.stars,
                        ),
                      ),
                      12.horizontalSpace,
                      Expanded(
                        child: _progressStat(
                          'Tasks Done',
                          tasksText,
                          Icons.check_circle_outline,
                        ),
                      ),
                    ],
                  );
                },
              ),
              32.verticalSpace,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PrimaryText(
                    text: "Today's Tasks",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.accentTxt,
                  ),
                  PrimaryText(
                    text: R.S.viewAll,
                    color: theme.accentTxt.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ).rippleClick(() {
                    context.push(const TasksListScreen());
                  }),
                ],
              ),
              16.verticalSpace,
              Consumer<TaskProvider>(
                builder: (context, taskStore, _) {
                  if (taskStore.tasks.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.accentTxt.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: SecondaryText(
                          text: 'No tasks for today. Start by creating one!',
                          color: theme.accentTxt.withOpacity(0.5),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: taskStore.tasks.take(5).map((task) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.accentTxt.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: task.isDone
                                ? theme.successPrimary.withOpacity(0.3)
                                : theme.accentTxt.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              task.isDone
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: task.isDone
                                  ? theme.successPrimary
                                  : theme.accentTxt.withOpacity(0.3),
                              size: 24,
                            ),
                            12.horizontalSpace,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PrimaryText(
                                    text: task.title,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.accentTxt.withOpacity(
                                      task.isDone ? 0.5 : 1,
                                    ),
                                    decoration: task.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  if (task.description.isNotEmpty)
                                    SecondaryText(
                                      text: task.description,
                                      fontSize: 11,
                                      color: theme.accentTxt.withOpacity(0.5),
                                      maxLines: 1,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              32.verticalSpace,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, Color baseColor) {
    List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*');
    int lastMatchEnd = 0;

    for (final Match match in regExp.allMatches(text)) {
      // Add plain text before match
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        );
      }

      // Add highlighted match (without markers)
      String matchedText = match.group(1) ?? match.group(2) ?? '';
      spans.add(
        TextSpan(
          text: matchedText,
          style: GoogleFonts.inter(
            color: baseColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    // Add remaining plain text
    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.9),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget reportItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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

  Widget _actionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    AppTheme theme = context.watch();
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.accentTxt.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.accentTxt, size: 20),
          ),
          12.verticalSpace,
          PrimaryText(
            text: title,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: theme.accentTxt,
          ),
          4.verticalSpace,
          SecondaryText(
            text: subtitle,
            fontSize: 10,
            color: theme.accentTxt.withOpacity(0.7),
            maxLines: 2,
          ),
        ],
      ),
    ).rippleClick(() {
      if (title == 'Decision Analyzer') {
        context.push(const DecisionAnalyzerScreen());
      } else if (title == 'Focus Session') {
        context.push(const FocusSessionScreen());
      } else if (title == 'Create Task') {
        context.push(const TaskCreationScreen());
      }
    });
  }

  Widget _progressStat(String label, String value, IconData icon) {
    return Builder(
      builder: (context) {
        AppTheme theme = context.watch();
        return GlassContainer(
          padding: const EdgeInsets.all(12),
          gradient: theme.glassGradient,
          child: Column(
            children: [
              SecondaryText(
                text: label,
                fontSize: 10,
                color: theme.accentTxt.withOpacity(0.7),
              ),
              8.verticalSpace,
              PrimaryText(
                text: value,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.accentTxt,
              ),
            ],
          ),
        );
      },
    );
  }
}
