import 'package:mindpilot/export.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isInsightExpanded = false;
  String? _lastAutoExpandedContent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<HomeProvider>().loadWeeklyStats();

      await ConfigService().fetchRemoteConfig();

      final currentVersion = ConfigService().currentAppVersion;
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
    final authStore = context.watch<AppAuthProvider>();
    final user = authStore.user;
    final isPro = authStore.isPro;

    final email = authStore.email ?? user?.email;
    final emailPrefix = (email != null && email.contains('@'))
        ? (email.contains('privaterelay.appleid.com') ? 'User' : email.split('@').first.capitalize())
        : 'User';

    String displayNameToUse = 'User';
    if (authStore.displayName != null && authStore.displayName!.trim().isNotEmpty) {
      displayNameToUse = authStore.displayName!;
    } else if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      displayNameToUse = user.displayName!;
    } else if (emailPrefix.trim().isNotEmpty) {
      displayNameToUse = emailPrefix;
    }

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
                                child: displayNameToUse.getInitials().isNotEmpty
                                    ? PrimaryText(
                                        text: displayNameToUse.getInitials(),
                                        color: theme.primaryBase,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      )
                                    : Icon(
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
                                '${TimeTeller.tellTimeOfTheDay()}, ${displayNameToUse.split(' ').first}',
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
                                    8.horizontalSpace,
                                    Icon(
                                      Icons.share_outlined,
                                      color: Colors.orange.withOpacity(0.6),
                                      size: 12,
                                    ).rippleClick(() {
                                      final downloadUrl = ConfigService().updateUrl;
                                      ShareService.captureAndShare(
                                        context,
                                        text: "Keeping the momentum alive! 🔥 Day ${appStore.streak} of staying focused with MindPilot. Consistency is the key to mastery.\n\nDownload MindPilot: $downloadUrl\n#MindPilot #Streak #Discipline",
                                        widget: ShareableCard(
                                          mode: ShareableCardMode.streak,
                                          streak: appStore.streak,
                                          userName: user?.displayName,
                                        ),
                                      );
                                    }),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SecondaryText(
                            text: R.S.dailyInsight,
                            color: theme.accentTxt.withOpacity(0.7),
                            fontSize: 12,
                          ),
                          const Spacer(),
                          Consumer<NotificationProvider>(
                            builder: (context, notifStore, _) {
                              if (notifStore.dailyInsight.isEmpty || notifStore.dailyInsight == '...') return const SizedBox();
                              return Icon(
                                Icons.share_outlined,
                                color: theme.accentTxt.withOpacity(0.5),
                                size: 16,
                              ).rippleClick(() {
                                String? explanation = notifStore.insightExplanation;
                                if (explanation != null) {
                                  final match = RegExp(r'\*?\*?Quick [Tt]ip\b').firstMatch(explanation);
                                  if (match != null) {
                                    explanation = explanation.substring(0, match.start).trim();
                                  }
                                }
                                
                                
                                final downloadUrl = ConfigService().updateUrl;
                                final caption = notifStore.getInsightShareCaption();
                                ShareService.captureAndShare(
                                  context,
                                  text: "$caption\n\nDownload MindPilot: $downloadUrl\n#MindPilot #DailyInsight #Mindset",
                                  widget: ShareableCard(
                                    mode: ShareableCardMode.insight,
                                    insightTitle: 'Daily Insight',
                                    insightContent: notifStore.dailyInsight,
                                    author: notifStore.dailyInsightAuthor,
                                    insightExplanation: explanation,
                                    userName: user?.displayName,
                                  ),
                                );
                              });
                            },
                          ),
                          12.horizontalSpace,
                          Consumer<NotificationProvider>(
                            builder: (context, notifStore, _) {
                              if (notifStore.lastInsightDate == null) return const SizedBox();
                              
                              try {
                                final date = DateTime.parse(notifStore.lastInsightDate!);
                                final timeStr = DateFormat('hh:mm a').format(date);
                                return SecondaryText(
                                  text: 'Updated: $timeStr',
                                  color: theme.accentTxt.withOpacity(0.4),
                                  fontSize: 10,
                                );
                              } catch (e) {
                                return const SizedBox();
                              }
                            },
                          ),
                        ],
                      ),
                      12.verticalSpace,
                      Consumer<NotificationProvider>(
                        builder: (context, notifStore, _) {
                          // Auto-expand only ONCE when a new explanation arrives
                          final expansionKey = "${notifStore.dailyInsight}${notifStore.insightExplanation}";
                          if (notifStore.insightExplanation != null && 
                              !notifStore.isFetchingExplanation &&
                              _lastAutoExpandedContent != expansionKey) {
                            _lastAutoExpandedContent = expansionKey;
                            _isInsightExpanded = true; // Set directly to avoid frame-skip
                          }

                          // Reset expansion if insight changed and no explanation exists
                          if (notifStore.insightExplanation == null &&
                              _isInsightExpanded) {
                            _isInsightExpanded = false;
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '"${notifStore.dailyInsight}" ',
                                      style: GoogleFonts.inter(
                                        color: theme.accentTxt,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                      TextSpan(
                                        text: "- ${notifStore.dailyInsightAuthor ?? "Unknown"}",
                                        style: GoogleFonts.inter(
                                          color: Colors.orangeAccent,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (['laleyesolomon2@gmail.com', 'solteqinnovationsltd@gmail.com'].contains(authStore.user?.email?.toLowerCase())) // Show source to super admins
                                        TextSpan(
                                          text: "\n[Source: ${notifStore.lastInsightSource ?? 'N/A'}]",
                                          style: GoogleFonts.inter(
                                            color: theme.accentTxt.withOpacity(0.3),
                                            fontSize: 10,
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                              if (_isInsightExpanded) ...[
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
                      8.verticalSpace,
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Consumer2<NotificationProvider, AppAuthProvider>(
                            builder: (context, notifStore, authStore, _) {
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
                              final remaining = 3 - authStore.explanationCount;
                              final buttonText = isPro 
                                ? (hasError ? notifStore.fetchError! : 'Explain')
                                : (hasError ? notifStore.fetchError! : 'Explain ($remaining left)');

                              return Container(
                                key: const ValueKey('explain_button'),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.primaryBase.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: theme.primaryBase.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      hasError
                                          ? Icons.refresh
                                          : Icons.psychology_outlined,
                                      color: hasError
                                          ? theme.errorPrimary
                                          : theme.primaryBase,
                                      size: 18,
                                    ),
                                    8.horizontalSpace,
                                    SecondaryText(
                                      text: buttonText,
                                      color: hasError
                                          ? theme.errorPrimary
                                          : theme.accentTxt,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ],
                                ),
                              ).rippleClick(() async {
                                if (!isPro && authStore.explanationCount >= 3) {
                                  AppHelper.showPaywall(
                                    context,
                                    feature: 'Daily Explanation',
                                  );
                                } else {
                                  // Start fetching
                                  final wasFetched = await context
                                      .read<NotificationProvider>()
                                      .fetchInsightExplanation();
                                  
                                  // Only increment count if a NEW explanation was actually fetched
                                  if (mounted && 
                                      wasFetched &&
                                      context.read<NotificationProvider>().fetchError == null &&
                                      !isPro) {
                                    await authStore.incrementExplanationCount();
                                  }

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
                        R.S.decisionAnalyzer,
                        'Make better choices',
                        Icons.psychology,
                        theme.primaryBase,
                      ),
                    ),
                    12.horizontalSpace,
                    Expanded(
                      child: _actionCard(
                        context,
                        R.S.focusSession,
                        'Improve focus',
                        Icons.timer_outlined,
                        theme.successPrimary,
                      ),
                    ),
                    12.horizontalSpace,
                    Expanded(
                      child: _actionCard(
                        context,
                        R.S.createTask,
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
                      Icon(
                        Icons.share_outlined,
                        color: theme.accentTxt.withOpacity(0.5),
                        size: 18,
                      ).rippleClick(() {
                        final journal = context.read<JournalProvider>();
                        final taskStore = context.read<TaskProvider>();

                        final totalMinutes = journal.totalFocusMinutes;
                        final hours = totalMinutes ~/ 60;
                        final minutes = totalMinutes % 60;
                        String focusTimeText =
                            hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
                        String tasksText =
                            '${taskStore.completedCount}/${taskStore.totalCount}';
                        int points =
                            (taskStore.completedCount * 10) + (totalMinutes ~/ 5);
                        String achievement = 'Level ${1 + (points ~/ 50)}';

                        final downloadUrl = ConfigService().updateUrl;
                        ShareService.captureAndShare(
                          context,
                          text: "Today's wins are in! 🏆 Seeing my progress clearly makes every session count. Ready to level up your focus? Join me on MindPilot!\n\nDownload MindPilot: $downloadUrl\n#MindPilot #Progress #Achievement",
                          widget: ShareableCard(
                            mode: ShareableCardMode.progress,
                            focusTime: focusTimeText,
                            tasksDone: tasksText,
                            achievement: achievement,
                            userName: user?.displayName,
                          ),
                        );
                      }),
                      16.horizontalSpace,
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
                    text: R.S.todaysTasks,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.accentTxt,
                  ),
                  SecondaryText(
                    text: 'View All',
                    color: theme.accentTxt.withOpacity(0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ).rippleClick(() => context.push(const TasksListScreen())),
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
                          text: R.S.noTasks,
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
                      ).rippleClick(() {
                        context.push(TasksListScreen(highlightTaskId: task.id));
                      });
                    }).toList(),
                  );
                },
              ),
              110.verticalSpace,
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
      border: Border.all(
        color: theme.primaryBase.withOpacity(0.3),
        width: 1,
      ),
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
      if (title == R.S.decisionAnalyzer) {
        context.read<HomeProvider>().navIndex = 2;
      } else if (title == R.S.focusSession) {
        context.read<HomeProvider>().navIndex = 1;
      } else if (title == R.S.createTask) {
        context.push(const TaskCreationScreen());
      }
    });
  }

  Widget _progressStat(String label, String value, IconData icon) {
    return Builder(
      builder: (context) {
        AppTheme theme = context.watch();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.accentTxt.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              SecondaryText(
                text: label,
                fontSize: 10,
                color: theme.accentTxt.withOpacity(0.5),
              ),
              8.verticalSpace,
              PrimaryText(
                text: value,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.accentTxt.withOpacity(0.8),
              ),
            ],
          ),
        );
      },
    );
  }
}
