import 'package:mindpilot/export.dart';

class TasksListScreen extends StatefulWidget {
  final int? highlightTaskId;
  const TasksListScreen({super.key, this.highlightTaskId});

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  int? _expandedTaskId;

  @override
  void initState() {
    super.initState();
    AppHelper.setScreenshotProtection(true);
    _expandedTaskId = widget.highlightTaskId;
  }

  @override
  void dispose() {
    // AppHelper.setScreenshotProtection(false);
    super.dispose();
  }

  final Map<int, String> _tempNotes = {};

  void _showClearAllConfirmation(BuildContext context) {
    AppTheme theme = context.read();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.brandDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: PrimaryText(text: 'Clear All Tasks', color: theme.accentTxt),
        content: SecondaryText(
          text:
              'This will permanently delete all your tasks for today. This action cannot be undone.',
          color: theme.accentTxt.withOpacity(0.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: SecondaryText(
              text: 'Cancel',
              color: theme.accentTxt.withOpacity(0.5),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<TaskProvider>().clearAllTasks();
              context.showInAppNotification(
                'All tasks cleared',
                type: InAppNotificationType.success,
              );
            },
            child: PrimaryText(text: 'Clear All', color: theme.errorPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'All Tasks',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.chevron_left, color: theme.accentTxt),
        ).rippleClick(() => context.pop()),
        actions: [
          Icon(
            Icons.delete_sweep_outlined,
            color: theme.errorPrimary.withOpacity(0.7),
          ).rippleClick(() => _showClearAllConfirmation(context)),
          8.horizontalSpace,
          Icon(Icons.share_outlined, color: theme.accentTxt).rippleClick(() {
            final user = context.read<AppAuthProvider>().user;
            final taskStore = context.read<TaskProvider>();
            final downloadUrl = ConfigService().updateUrl;
            ShareService.captureAndShare(
              context,
              text:
                  "Crushing my goals one focus session at a time! 🚀 MindPilot keeps me sharp and on track. Who else is staying disciplined today?\n\nDownload MindPilot: $downloadUrl\n#MindPilot #Focus #Achievement",
              widget: ShareableCard(
                mode: ShareableCardMode.tasks,
                tasks: taskStore.tasks.map((t) => t.title).toList(),
                userName: user?.displayName,
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
          Consumer<TaskProvider>(
            builder: (context, taskStore, _) {
              if (taskStore.tasks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.task_alt,
                        size: 64,
                        color: theme.accentTxt.withOpacity(0.2),
                      ),
                      16.verticalSpace,
                      SecondaryText(
                        text: 'No tasks found.',
                        color: theme.accentTxt.withOpacity(0.5),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: taskStore.tasks.length,
                itemBuilder: (context, index) {
                  final task = taskStore.tasks[index];
                  final isExpanded = _expandedTaskId == task.id;
                  final isHighlighted = widget.highlightTaskId == task.id;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? theme.primaryBase.withOpacity(0.15)
                          : theme.accentTxt.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isHighlighted
                            ? theme.primaryBase
                            : (task.isDone
                                  ? theme.successPrimary.withOpacity(0.3)
                                  : theme.accentTxt.withOpacity(0.1)),
                        width: isHighlighted ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: Checkbox(
                            value: task.isDone,
                            activeColor: theme.successPrimary,
                            side: BorderSide(
                              color: theme.accentTxt.withOpacity(0.5),
                            ),
                            onChanged: (_) => taskStore.toggleTaskDone(task),
                          ),
                          title: PrimaryText(
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (task.description.isNotEmpty && !isExpanded)
                                SecondaryText(
                                  text: task.description,
                                  fontSize: 11,
                                  color: theme.accentTxt.withOpacity(0.5),
                                  maxLines: 1,
                                ),
                              4.verticalSpace,
                              Row(
                                children: [
                                  SecondaryText(
                                    text: task.date,
                                    fontSize: 10,
                                    color: theme.accentTxt.withOpacity(0.3),
                                  ),
                                  if (task.startTime != null ||
                                      task.completionTime != null) ...[
                                    8.horizontalSpace,
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: theme.accentTxt.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    8.horizontalSpace,
                                    Icon(
                                      Icons.access_time,
                                      size: 10,
                                      color: theme.primaryBase.withOpacity(0.5),
                                    ),
                                    4.horizontalSpace,
                                    Flexible(
                                      child: SecondaryText(
                                        text:
                                            task.startTime != null &&
                                                task.completionTime != null
                                            ? '${task.startTime} - ${task.completionTime}'
                                            : (task.startTime ??
                                                  task.completionTime!),
                                        fontSize: 10,
                                        color: theme.primaryBase.withOpacity(
                                          0.7,
                                        ),
                                        fontWeight: FontWeight.bold,
                                        textOverflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: theme.accentTxt.withOpacity(0.3),
                              ),
                              8.horizontalSpace,
                              Icon(
                                Icons.delete_outline,
                                color: theme.errorPrimary.withOpacity(0.5),
                                size: 22,
                              ).rippleClick(
                                () => taskStore.deleteTask(task.id!),
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _expandedTaskId = isExpanded ? null : task.id;
                            });
                          },
                        ),
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(
                                  color: theme.accentTxt.withOpacity(0.1),
                                ),
                                8.verticalSpace,
                                SecondaryText(
                                  text: 'Description',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.accentTxt.withOpacity(0.7),
                                ),
                                8.verticalSpace,
                                TextFormField(
                                  initialValue: task.description,
                                  maxLines: null,
                                  style: TextStyle(
                                    color: theme.accentTxt,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Add details...',
                                    hintStyle: TextStyle(
                                      color: theme.accentTxt.withOpacity(0.3),
                                    ),
                                    filled: true,
                                    fillColor: theme.accentTxt.withOpacity(
                                      0.05,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                  onFieldSubmitted: (val) {
                                    taskStore.updateTaskDescription(
                                      task.id!,
                                      val,
                                    );
                                  },
                                  onChanged: (val) {
                                    // Store locally if needed, but for now we'll just use onFieldSubmitted or a save button
                                    _tempNotes[task.id!] = val;
                                  },
                                ),
                                8.verticalSpace,
                                Align(
                                  alignment: Alignment.centerRight,
                                  child:
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.primaryBase.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.update_outlined,
                                              size: 14,
                                              color: theme.primaryBase,
                                            ),
                                            8.horizontalSpace,
                                            SecondaryText(
                                              text: 'Update Note',
                                              fontSize: 11,
                                              color: theme.primaryBase,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ],
                                        ),
                                      ).rippleClick(() {
                                        final note =
                                            _tempNotes[task.id!] ??
                                            task.description;
                                        taskStore.updateTaskDescription(
                                          task.id!,
                                          note,
                                        );
                                        context.showInAppNotification(
                                          'Note updated',
                                          type: InAppNotificationType.success,
                                        );
                                      }),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(const TaskCreationScreen()),
        backgroundColor: theme.primaryBase,
        child: Icon(Icons.add, color: theme.accentTxt),
      ),
    );
  }
}
