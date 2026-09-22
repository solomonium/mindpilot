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
  TimeOfDay? _startTime;
  int _durationMinutes = 30; // Default 30 mins

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (context, child) {
        AppTheme theme = context.read();
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: theme.primaryBase,
              onPrimary: theme.accentTxt,
              surface: theme.brandDark,
              onSurface: theme.accentTxt,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: theme.primaryBase),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startTime) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _saveTask() async {
    if (_isLoading) return;
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty) {
      context.showInAppNotification(R.S.enterTaskTitle);
      return;
    }

    setState(() => _isLoading = true);
    String? startTimeStr;
    String? completionTimeStr;

    if (_startTime != null) {
      final now = DateTime.now();
      final startDt = DateTime(
        now.year,
        now.month,
        now.day,
        _startTime!.hour,
        _startTime!.minute,
      );
      final endDt = startDt.add(Duration(minutes: _durationMinutes));

      startTimeStr = DateFormat('hh:mm a').format(startDt);
      completionTimeStr = DateFormat('hh:mm a').format(endDt);
    }

    final success = await context.read<TaskProvider>().addTask(
      title,
      desc,
      startTime: startTimeStr,
      durationMinutes: _durationMinutes,
      completionTime: completionTimeStr,
    );

    if (!success) {
      setState(() => _isLoading = false);
      return;
    }

    if (_startTime != null) {
      final now = DateTime.now();
      var startDt = DateTime(
        now.year,
        now.month,
        now.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      // If the selected time has already passed today, assume it's for tomorrow
      if (startDt.isBefore(now)) {
        startDt = startDt.add(const Duration(days: 1));
      }

      await NotificationService().scheduleTaskAlarm(
        title,
        startDt,
        _durationMinutes,
      );
    }

    setState(() => _isLoading = false);

    if (mounted) {
      context.showInAppNotification(
        R.S.taskCreated,
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
            text: R.S.createTaskTitle,
            color: theme.accentTxt,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(Icons.chevron_left, color: theme.accentTxt),
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
                    text: R.S.taskAccomplish,
                    color: theme.accentTxt,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  12.verticalSpace,
                  SecondaryText(
                    text: R.S.taskDescHint,
                    color: theme.accentTxt.withOpacity(0.7),
                  ),
                  24.verticalSpace,
                  _buildInputField(
                    theme,
                    label: R.S.taskTitleLabel,
                    hint: R.S.taskTitleHint,
                    controller: _titleController,
                  ),
                  24.verticalSpace,
                  _buildInputField(
                    theme,
                    label: R.S.taskDescriptionLabel,
                    hint: R.S.taskDescriptionHint,
                    controller: _descController,
                    maxLines: 4,
                  ),
                  24.verticalSpace,
                  SecondaryText(
                    text: R.S.startTimeLabel,
                    color: theme.accentTxt.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                  ),
                  12.verticalSpace,
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.accentTxt.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.accentTxt.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PrimaryText(
                          text: _startTime == null
                              ? R.S.setStartTime
                              : _startTime!.format(context),
                          color: theme.accentTxt.withOpacity(
                            _startTime == null ? 0.4 : 1,
                          ),
                          fontSize: 16,
                        ),
                        Icon(Icons.access_time, color: theme.primaryBase),
                      ],
                    ),
                  ).rippleClick(_pickTime),
                  24.verticalSpace,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SecondaryText(
                        text: R.S.durationLabel,
                        color: theme.accentTxt.withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                      ),
                      PrimaryText(
                        text:
                            '${_durationMinutes ~/ 60}h ${_durationMinutes % 60}m',
                        color: theme.primaryBase,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                  8.verticalSpace,
                  Slider(
                    value: _durationMinutes.toDouble(),
                    min: 30,
                    max: 180,
                    divisions: 15, // 10 min increments
                    activeColor: theme.primaryBase,
                    inactiveColor: theme.accentTxt.withOpacity(0.1),
                    onChanged: (val) =>
                        setState(() => _durationMinutes = val.toInt()),
                  ),
                  if (_startTime != null) ...[
                    12.verticalSpace,
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryBase.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: SecondaryText(
                          text:
                              'Scheduled: ${_startTime!.format(context)} - ${DateFormat('hh:mm a').format(DateTime(2024, 1, 1, _startTime!.hour, _startTime!.minute).add(Duration(minutes: _durationMinutes)))}',
                          color: theme.primaryBase,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  40.verticalSpace,
                  CustomButton(
                    label: R.S.createTask,
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
