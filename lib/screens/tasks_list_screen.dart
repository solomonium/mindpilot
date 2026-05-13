import 'package:mindpilot/export.dart';

class TasksListScreen extends StatelessWidget {
  const TasksListScreen({super.key});

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
        leading: Icon(
          Icons.chevron_left,
          color: theme.accentTxt,
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
          Consumer<TaskProvider>(
            builder: (context, taskStore, _) {
              if (taskStore.tasks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task_alt, size: 64, color: theme.accentTxt.withOpacity(0.2)),
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
                          side: BorderSide(color: theme.accentTxt.withOpacity(0.5)),
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
                                  maxLines: 2,
                                ),
                              4.verticalSpace,
                              Row(
                                children: [
                                  SecondaryText(
                                    text: task.date,
                                    fontSize: 10,
                                    color: theme.accentTxt.withOpacity(0.3),
                                  ),
                                  if (task.startTime != null || task.completionTime != null) ...[
                                    8.horizontalSpace,
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(color: theme.accentTxt.withOpacity(0.2), shape: BoxShape.circle),
                                    ),
                                    8.horizontalSpace,
                                    Icon(Icons.access_time, size: 10, color: theme.primaryBase.withOpacity(0.5)),
                                    4.horizontalSpace,
                                    SecondaryText(
                                      text: task.startTime != null && task.completionTime != null 
                                          ? '${task.startTime} - ${task.completionTime} (${task.durationMinutes}m)'
                                          : (task.startTime ?? task.completionTime!),
                                      fontSize: 10,
                                      color: theme.primaryBase.withOpacity(0.7),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ],

                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.delete_outline,
                          color: theme.errorPrimary.withOpacity(0.5),
                          size: 22,
                        ).rippleClick(() => taskStore.deleteTask(task.id!)),
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
