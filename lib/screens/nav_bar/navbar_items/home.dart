import 'package:mindpilot/export.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final user = context.watch<AuthProvider>().user;
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
                            ? DecorationImage(image: NetworkImage(user!.photoURL!), fit: BoxFit.cover)
                            : null,
                          boxShadow: [BoxShadow(color: theme.foundationColor.withOpacity(0.1), blurRadius: 4)],
                        ),
                        child: user?.photoURL == null 
                          ? Center(child: Icon(Icons.person, color: theme.primaryBase, size: 24)) 
                          : null,
                      ),
                      12.horizontalSpace,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PrimaryText(
                            text: '${TimeTeller.tellTimeOfTheDay()}, ${user?.displayName?.split(' ').first ?? 'User'}', 
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: theme.accentTxt,
                          ),
                          SecondaryText(text: R.S.readyToMake, fontSize: 12, color: theme.accentTxt.withOpacity(0.7)),
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
                            child: Icon(Icons.notifications_outlined, size: 22, color: theme.accentTxt),
                          ).rippleClick(() {
                            context.push(const NotificationScreen());
                          }),
                          if (notifStore.unreadCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '${notifStore.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    }
                  ),
                ],
              ),
              25.verticalSpace,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: theme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: theme.primaryBase.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SecondaryText(text: R.S.dailyInsight, color: theme.accentTxt.withOpacity(0.7), fontSize: 12),
                    12.verticalSpace,
                    Consumer<NotificationProvider>(
                      builder: (context, notifStore, _) {
                        return PrimaryText(
                          text: '"${notifStore.dailyInsight}"',
                          color: theme.accentTxt,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        );
                      }
                    ),
                    20.verticalSpace,
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Image.asset(R.png.mindpilot.png, height: 40, color: theme.accentTxt.withOpacity(0.2)),
                    ),
                  ],
                ),
              ),
              32.verticalSpace,
              PrimaryText(text: R.S.quickActions, fontSize: 18, fontWeight: FontWeight.bold, color: theme.accentTxt),
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
              32.verticalSpace,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PrimaryText(text: R.S.todaysProgress, fontSize: 18, fontWeight: FontWeight.bold, color: theme.accentTxt),
                  PrimaryText(text: 'View all', color: theme.accentTxt.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600).rippleClick(() {
                    context.push(const ProgressReportScreen());
                  }),
                ],
              ),
              16.verticalSpace,
              Consumer2<JournalProvider, TaskProvider>(
                builder: (context, journal, taskStore, _) {
                  // Focus Time
                  final totalMinutes = journal.totalFocusMinutes;
                  final hours = totalMinutes ~/ 60;
                  final minutes = totalMinutes % 60;
                  String focusTimeText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

                  // Tasks Done
                  String tasksText = '${taskStore.completedCount}/${taskStore.totalCount}';

                  // Achievement (Simple logic: tasks + focus milestones)
                  int points = (taskStore.completedCount * 10) + (totalMinutes ~/ 5);
                  String achievement = 'Level ${1 + (points ~/ 50)}';

                  return Row(
                    children: [
                      Expanded(child: _progressStat('Focus Time', focusTimeText, Icons.access_time)),
                      12.horizontalSpace,
                      Expanded(child: _progressStat('Achievement', achievement, Icons.stars)),
                      12.horizontalSpace,
                      Expanded(child: _progressStat('Tasks Done', tasksText, Icons.check_circle_outline)),
                    ],
                  );
                },
              ),
              32.verticalSpace,
              PrimaryText(text: "Today's Tasks", fontSize: 18, fontWeight: FontWeight.bold, color: theme.accentTxt),
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
                            Checkbox(
                              value: task.isDone,
                              activeColor: theme.successPrimary,
                              onChanged: (_) => taskStore.toggleTaskDone(task),
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
                                    color: theme.accentTxt.withOpacity(task.isDone ? 0.5 : 1),
                                    decoration: task.isDone ? TextDecoration.lineThrough : null,
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
                            Icon(
                              Icons.delete_outline,
                              color: theme.errorPrimary.withOpacity(0.5),
                              size: 20,
                            ).rippleClick(() => taskStore.deleteTask(task.id!)),
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

  Widget _actionCard(BuildContext context, String title, String subtitle, IconData icon, Color color) {
    AppTheme theme = context.watch();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: theme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: theme.primaryBase.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: theme.accentTxt.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: theme.accentTxt, size: 20),
          ),
          12.verticalSpace,
          PrimaryText(text: title, fontSize: 13, fontWeight: FontWeight.bold, color: theme.accentTxt),
          4.verticalSpace,
          SecondaryText(text: subtitle, fontSize: 10, color: theme.accentTxt.withOpacity(0.7), maxLines: 1),
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
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: theme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: theme.primaryBase.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              SecondaryText(text: label, fontSize: 10, color: theme.accentTxt.withOpacity(0.7)),
              8.verticalSpace,
              PrimaryText(text: value, fontSize: 14, fontWeight: FontWeight.bold, color: theme.accentTxt),
            ],
          ),
        );
      }
    );
  }
}
