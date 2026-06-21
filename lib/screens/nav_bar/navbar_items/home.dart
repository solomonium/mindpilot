import 'package:mindpilot/export.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isInsightExpanded = false;
  String? _lastAutoExpandedContent;

  // Google Calendar state
  List<CalendarEvent> _calendarEvents = [];
  bool _isLoadingCalendar = false;
  bool _calendarError = false;
  bool _calendarConnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<HomeProvider>().loadWeeklyStats();
      await NotificationService().scheduleMorningInsightReminder();

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

      // Auto-fetch calendar silently for Google users
      if (GoogleCalendarService().isGoogleUser) {
        _fetchCalendarEvents(requestPermission: false);
      }
    });
  }

  Future<void> _fetchCalendarEvents({bool requestPermission = true}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingCalendar = true;
      _calendarError = false;
    });
    try {
      if (!requestPermission) {
        final isConnected = await GoogleCalendarService().isCalendarConnected;
        if (!isConnected) {
          if (mounted) {
            setState(() {
              _calendarEvents = [];
              _calendarConnected = false;
              _isLoadingCalendar = false;
            });
          }
          return;
        }
      }

      final events = await GoogleCalendarService().fetchUpcomingEvents(
        requestPermission: requestPermission,
      );
      // Schedule notifications for each upcoming event
      for (final e in events) {
        if (e.isUpcoming) {
          await NotificationService().scheduleMeetingReminder(
            eventId: e.id,
            title: e.title,
            startTime: e.startTime,
          );
          await NotificationService().scheduleMeetingRatingRequest(
            eventId: e.id,
            title: e.title,
            endTime: e.endTime,
          );
        }
      }
      if (mounted) {
        setState(() {
          _calendarEvents = events;
          _calendarConnected = true;
          _isLoadingCalendar = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _calendarError = true;
          _isLoadingCalendar = false;
        });
      }
    }
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
                                    text: appStore.streak > 0
                                        ? '${appStore.streak} Day Streak'
                                        : 'Start your streak today',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                  if (isPro && appStore.streak > 0) ...[
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
                                          userName: displayNameToUse,
                                        ),
                                      );
                                      AnalyticsService.logShareCard('streak');
                                    }),
                                  ],
                                ],
                              );
                            },
                          ),
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
              16.verticalSpace,
              LevelProgressBar(xp: authStore.xp, level: authStore.level),
              16.verticalSpace,
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
                                  AppHelper.watchAdForAction(
                                    context,
                                    promptText: 'You have used your 3 free explanations for today. Watch a video ad to get 1 more explanation credit!',
                                    onReward: () async {
                                      await authStore.rewardExplanationCount();
                                      if (mounted) {
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
                                          await EngagementService().recordAction(
                                            EngagementAction.insightExplained,
                                          );
                                        }
                                      }
                                    },
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
                                    await EngagementService().recordAction(
                                      EngagementAction.insightExplained,
                                    );
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

              // ─── Google Calendar Card (Google users only) ───────────────
              // if (GoogleCalendarService().isGoogleUser) ...[
              //   _buildCalendarCard(context, theme),
              //   20.verticalSpace,
              // ],

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
              _buildGoalBasedQuickActions(context, theme, authStore.personalization),
              20.verticalSpace,
              _buildDailyHubRow(context, theme, authStore),
              20.verticalSpace,
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
                        String achievement = 'Level ${authStore.level}';

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
                  String achievement = 'Level ${authStore.level}';

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

  Widget _buildDailyHubRow(BuildContext context, AppTheme theme, AppAuthProvider authStore) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      gradient: theme.glassGradient,
      border: Border.all(color: theme.primaryBase.withOpacity(0.25)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryBase.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, color: theme.primaryBase, size: 20),
          ),
          12.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrimaryText(
                  text: 'Daily Hub',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.accentTxt,
                ),
                4.verticalSpace,
                SecondaryText(
                  text: 'Complete your daily pack, first win tasks, and get AI guidance',
                  fontSize: 11,
                  color: theme.accentTxt.withOpacity(0.6),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: theme.primaryBase, size: 16),
        ],
      ),
    ).rippleClick(() {
      context.push(const DailyHubScreen());
    });
  }

  Widget _buildGoalBasedQuickActions(
    BuildContext context,
    AppTheme theme,
    List<String> personalization,
  ) {
    final selected = [
      {
        'key': 'bible_quiz',
        'title': 'Bible Quiz',
        'subtitle': 'Learn & test knowledge',
        'icon': Icons.quiz_outlined,
        'color': const Color(0xFFF59E0B),
        'nav': -2,
      },
      {
        'key': 'focus',
        'title': R.S.focusSession,
        'subtitle': 'Improve focus',
        'icon': Icons.timer_outlined,
        'color': theme.successPrimary,
        'nav': 1,
      },
      {
        'key': 'decision',
        'title': R.S.decisionAnalyzer,
        'subtitle': 'Make better choices',
        'icon': Icons.psychology,
        'color': theme.primaryBase,
        'nav': 3,
      },
      {
        'key': 'task',
        'title': R.S.createTask,
        'subtitle': 'Set new goals',
        'icon': Icons.add_task,
        'color': theme.errorPrimary,
        'nav': -1,
      },
      {
        'key': 'journal',
        'title': 'Journal',
        'subtitle': 'Write daily reflections',
        'icon': Icons.book_outlined,
        'color': const Color(0xFF8B5CF6),
        'nav': -3,
      },
    ];

    void handleTap(int nav) {
      if (nav >= 0) {
        context.read<HomeProvider>().navIndex = nav;
      } else if (nav == -1) {
        context.push(const TaskCreationScreen());
      } else if (nav == -2) {
        context.push(const BibleMainScreen());
      } else if (nav == -3) {
        context.push(const JournalEntriesScreen());
      }
    }

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _actionCard(
                  context,
                  selected[0]['title'] as String,
                  selected[0]['subtitle'] as String,
                  selected[0]['icon'] as IconData,
                  selected[0]['color'] as Color,
                  onTap: () => handleTap(selected[0]['nav'] as int),
                ),
              ),
              12.horizontalSpace,
              Expanded(
                child: _actionCard(
                  context,
                  selected[1]['title'] as String,
                  selected[1]['subtitle'] as String,
                  selected[1]['icon'] as IconData,
                  selected[1]['color'] as Color,
                  onTap: () => handleTap(selected[1]['nav'] as int),
                ),
              ),
            ],
          ),
        ),
        12.verticalSpace,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _actionCard(
                  context,
                  selected[2]['title'] as String,
                  selected[2]['subtitle'] as String,
                  selected[2]['icon'] as IconData,
                  selected[2]['color'] as Color,
                  onTap: () => handleTap(selected[2]['nav'] as int),
                ),
              ),
              12.horizontalSpace,
              Expanded(
                child: _actionCard(
                  context,
                  selected[3]['title'] as String,
                  selected[3]['subtitle'] as String,
                  selected[3]['icon'] as IconData,
                  selected[3]['color'] as Color,
                  onTap: () => handleTap(selected[3]['nav'] as int),
                ),
              ),
            ],
          ),
        ),
        12.verticalSpace,
        _horizontalActionCard(
          context,
          selected[4]['title'] as String,
          selected[4]['subtitle'] as String,
          selected[4]['icon'] as IconData,
          selected[4]['color'] as Color,
          onTap: () => handleTap(selected[4]['nav'] as int),
        ),
      ],
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
    Color color, {
    VoidCallback? onTap,
  }) {
    AppTheme theme = context.watch();
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      gradient: theme.glassGradient,
      border: Border.all(
        color: color.withOpacity(0.25),
        width: 1,
      ),
      child: SizedBox(
        height: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrimaryText(
                  text: title,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.accentTxt,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
                4.verticalSpace,
                SecondaryText(
                  text: subtitle,
                  fontSize: 10,
                  color: theme.accentTxt.withOpacity(0.55),
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    ).rippleClick(() {
      if (onTap != null) {
        onTap();
        return;
      }
      if (title == R.S.decisionAnalyzer) {
        context.read<HomeProvider>().navIndex = 3;
      } else if (title == R.S.focusSession) {
        context.read<HomeProvider>().navIndex = 1;
      } else if (title == R.S.createTask) {
        context.push(const TaskCreationScreen());
      } else if (title == 'Journal') {
        context.push(const JournalEntriesScreen());
      }
    });
  }

  Widget _horizontalActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    AppTheme theme = context.watch();
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      gradient: theme.glassGradient,
      border: Border.all(
        color: color.withOpacity(0.25),
        width: 1,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          16.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  color: theme.accentTxt.withOpacity(0.55),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.7), size: 14),
        ],
      ),
    ).rippleClick(() {
      if (onTap != null) {
        onTap();
        return;
      }
      if (title == 'Bible Quiz') {
        context.push(const BibleMainScreen());
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

  Widget _buildCalendarCard(BuildContext context, AppTheme theme) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      border: Border.all(color: theme.primaryBase.withOpacity(0.25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: theme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today,
                    color: Colors.white, size: 16),
              ),
              12.horizontalSpace,
              Expanded(
                child: PrimaryText(
                  text: "Today's Meetings",
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.accentTxt,
                ),
              ),
              if (_calendarConnected)
                GestureDetector(
                  onTap: _fetchCalendarEvents,
                  child: Icon(Icons.refresh,
                      color: theme.accentTxt.withOpacity(0.4), size: 18),
                ),
            ],
          ),
          16.verticalSpace,
          if (_isLoadingCalendar)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.primaryBase),
                  ),
                ),
              ),
            )
          else if (!_calendarConnected)
            Column(
              children: [
                SecondaryText(
                  text:
                      'Connect your Google Calendar to see today\'s meetings and get productivity reminders.',
                  fontSize: 12,
                  color: theme.accentTxt.withOpacity(0.6),
                ),
                16.verticalSpace,
                GestureDetector(
                  onTap: _fetchCalendarEvents,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: theme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today,
                            color: Colors.white, size: 16),
                        8.horizontalSpace,
                        const Text(
                          'Connect Calendar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else if (_calendarEvents.isEmpty)
            SecondaryText(
              text: 'No more meetings scheduled for today 🎉',
              fontSize: 12,
              color: theme.accentTxt.withOpacity(0.6),
            )
          else
            ...(_calendarEvents.take(3).map((event) {
              final start = DateFormat('h:mm a').format(event.startTime);
              final end = DateFormat('h:mm a').format(event.endTime);
              final isPast = event.endTime.isBefore(DateTime.now());
              final isNow = event.isOngoing;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isNow
                      ? theme.primaryBase.withOpacity(0.08)
                      : theme.accentTxt.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isNow
                        ? theme.primaryBase.withOpacity(0.35)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SecondaryText(
                          text: start,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isNow
                              ? theme.primaryBase
                              : theme.accentTxt.withOpacity(0.5),
                        ),
                        SecondaryText(
                          text: end,
                          fontSize: 10,
                          color: theme.accentTxt.withOpacity(0.35),
                        ),
                      ],
                    ),
                    12.horizontalSpace,
                    if (isNow)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.primaryBase.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SecondaryText(
                          text: 'LIVE',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryBase,
                        ),
                      ),
                    if (isNow) 8.horizontalSpace,
                    Expanded(
                      child: PrimaryText(
                        text: event.title,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.accentTxt.withOpacity(isPast ? 0.5 : 0.9),
                        textOverflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    8.horizontalSpace,
                    // Meeting link button
                    if (event.hasMeetingLink && !isPast)
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.tryParse(event.meetingLink!);
                          if (uri != null) await launchUrl(uri);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.primaryBase.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.videocam,
                              color: theme.primaryBase, size: 16),
                        ),
                      ),
                    // Rate button for past meetings
                    if (isPast) ...[
                      8.horizontalSpace,
                      GestureDetector(
                        onTap: () => MeetingRatingSheet.show(
                          context,
                          event: event,
                          onRated: () => setState(() {}),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SecondaryText(
                            text: 'Rate',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            })),
        ],
      ),
    );
  }
}
