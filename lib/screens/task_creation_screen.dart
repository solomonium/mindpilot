import 'package:mindpilot/export.dart';

class TaskCreationScreen extends StatefulWidget {
  const TaskCreationScreen({super.key});

  @override
  State<TaskCreationScreen> createState() => _TaskCreationScreenState();
}

class _TaskCreationScreenState extends State<TaskCreationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty) {
      context.showInAppNotification('Please enter a task title');
      return;
    }

    setState(() => _isLoading = true);
    await context.read<TaskProvider>().addTask(title, desc);
    setState(() => _isLoading = false);

    if (mounted) {
      context.showInAppNotification(
        'Task created successfully!',
        type: InAppNotificationType.success,
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: PrimaryText(
            text: 'Create New Task',
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
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PrimaryText(
                    text: 'What do you want to accomplish?',
                    color: theme.accentTxt,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  12.verticalSpace,
                  SecondaryText(
                    text: 'Setting clear tasks helps you stay focused and productive.',
                    color: theme.accentTxt.withOpacity(0.7),
                  ),
                  24.verticalSpace,
                  _buildInputField(
                    theme,
                    label: 'Task Title',
                    hint: 'e.g., Morning Meditation',
                    controller: _titleController,
                  ),
                  24.verticalSpace,
                  _buildInputField(
                    theme,
                    label: 'Description (Optional)',
                    hint: 'Details about your task...',
                    controller: _descController,
                    maxLines: 4,
                  ),
                  40.verticalSpace,
                  CustomButton(
                    label: 'Create Task',
                    onPressed: _saveTask,
                    backgroundColor: theme.primaryBase,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    AppTheme theme, {
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SecondaryText(
          text: label,
          color: theme.accentTxt.withOpacity(0.9),
          fontWeight: FontWeight.bold,
        ),
        12.verticalSpace,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: theme.accentTxt.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: theme.accentTxt, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              hintStyle: TextStyle(
                color: theme.accentTxt.withOpacity(0.4),
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
