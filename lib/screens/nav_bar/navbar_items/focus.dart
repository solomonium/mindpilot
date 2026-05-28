import 'dart:async';
import 'package:mindpilot/export.dart';

class FocusSessionScreen extends StatefulWidget {
  final int? initialDuration;
  final bool autoStart;
  final DateTime? scheduledStartTime;

  const FocusSessionScreen({
    super.key,
    this.initialDuration,
    this.autoStart = false,
    this.scheduledStartTime,
  });

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> {
  @override
  void initState() {
    super.initState();
    NotificationService().stopAlarmSound();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focusProvider = context.read<FocusProvider>();
      if (!focusProvider.isRunning) {
        if (widget.initialDuration != null) {
          focusProvider.selectedMinutes = widget.initialDuration!;
        }
        if (widget.autoStart && widget.scheduledStartTime != null) {
          focusProvider.startWaitingTimer(widget.scheduledStartTime!);
        }
      }
    });
  }

  void _onStartTimerTap() async {
    final focusProvider = context.read<FocusProvider>();
    final bool online = await AppHelper.isOnline();
    if (!online) {
      focusProvider.startTimer();
    } else {
      if (mounted) {
        AppHelper.showAirplaneModePrompt(
          context,
          onStartSession: focusProvider.startTimer,
        );
      }
    }
  }

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int mins = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final isPro = context.watch<AppAuthProvider>().isPro;
    final focusProvider = context.watch<FocusProvider>();
    double progress = focusProvider.secondsRemaining / (focusProvider.selectedMinutes * 60);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 1,
              child: Image.asset(R.png.focus.png, fit: BoxFit.cover),
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chevron_left,
                          color: theme.accentTxt,
                        ).rippleClick(() => context.pop()),
                        const Spacer(),
                        PrimaryText(
                          text: 'Focus Session',
                          color: theme.accentTxt,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        const Spacer(),
                        Icon(Icons.history, color: theme.accentTxt).rippleClick(
                          () {
                            if (isPro) {
                              context.showInAppNotification(
                                'Coming soon: Detailed focus history!',
                              );
                            } else {
                              AppHelper.showPaywall(
                                context,
                                feature: 'Focus History',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  12.verticalSpace,
                  _timerCircle(theme, progress, focusProvider),
                  if (focusProvider.isWaitingForStart &&
                      widget.scheduledStartTime != null) ...[
                    const SizedBox(height: 20),
                    PrimaryText(
                      text: 'Starting in ${_formatTime(focusProvider.secondsToStart)}',
                      color: theme.accentTxt.withOpacity(0.8),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    SecondaryText(
                      text:
                          'Task scheduled for ${DateFormat('hh:mm a').format(widget.scheduledStartTime!)}',
                      color: theme.accentTxt.withOpacity(0.5),
                    ),
                  ],

                  20.verticalSpace,

                  if (!focusProvider.isRunning) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SecondaryText(
                                text: 'Sound:',
                                color: theme.accentTxt.withOpacity(0.7),
                              ),
                              PrimaryText(
                                text: focusProvider.selectedSound,
                                color: theme.primaryBase,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ).clickable(() => _showSoundPicker(context, focusProvider)),
                            ],
                          ),
                          16.verticalSpace,
                          Slider(
                            value: focusProvider.selectedMinutes.toDouble(),
                            min: 1,
                            max: 180,
                            divisions: 179,
                            activeColor: theme.primaryBase,
                            inactiveColor: theme.accentTxt.withOpacity(0.1),
                            onChanged: (val) {
                              focusProvider.selectedMinutes = val.toInt();
                            },
                          ),
                          PrimaryText(
                            text: focusProvider.selectedMinutes >= 60
                                ? '${focusProvider.selectedMinutes ~/ 60}h ${focusProvider.selectedMinutes % 60}m'
                                : '${focusProvider.selectedMinutes} Minutes',
                            color: theme.accentTxt,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ),
                    16.verticalSpace,
                  ],
                  SecondaryText(
                    text: focusProvider.isRunning
                        ? 'Deep work in progress...'
                        : 'Stay focused and get things done',
                    color: theme.accentTxt.withOpacity(0.7),
                  ),
                  if (!focusProvider.isRunning) ...[
                    12.verticalSpace,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.airplanemode_active, size: 14, color: Colors.orange),
                          8.horizontalSpace,
                          const SecondaryText(
                            text: 'Toggle Airplane Mode',
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ).rippleClick(() {
                      context.showInAppNotification(
                        'Opening settings. Please toggle Airplane Mode for zero distractions.',
                        type: InAppNotificationType.info,
                      );
                      AppSettings.openAppSettings(type: AppSettingsType.wireless);
                    }),
                  ],
                  12.verticalSpace,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      gradient: theme.glassGradient,
                      border: Border.all(
                        color: focusProvider.isRunning
                            ? theme.errorPrimary
                            : theme.primaryBase,
                        width: 2,
                      ),
                      child: Center(
                        child: PrimaryText(
                          text: focusProvider.isRunning
                              ? 'Stop Focus Session'
                              : 'Start Focus Session',
                          color: theme.accentTxt,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ).rippleClick(focusProvider.isRunning ? focusProvider.stopTimer : _onStartTimerTap),
                  ),
                  12.verticalSpace,
                  _sessionTypes(theme, focusProvider),
                  120.verticalSpace,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSoundPicker(BuildContext context, FocusProvider focusProvider) {
    AppTheme theme = context.read();
    final isPro = context.read<AppAuthProvider>().isPro;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.brandDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PrimaryText(
              text: 'Choose Session Sound',
              color: theme.accentTxt,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            20.verticalSpace,
            ...focusProvider.sounds.map((sound) {
              bool soundIsPro = sound['isPro'] == 'true';
              bool isSelected = focusProvider.selectedSound == sound['name'];

              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected
                      ? theme.primaryBase
                      : theme.accentTxt.withOpacity(0.3),
                ),
                title: Row(
                  children: [
                    PrimaryText(
                      text: sound['name']!,
                      color: theme.accentTxt,
                      fontSize: 15,
                    ),
                    if (soundIsPro) ...[
                      8.horizontalSpace,
                      const Icon(
                        Icons.star,
                        color: Color(0xFFF59E0B),
                        size: 14,
                      ),
                    ],
                  ],
                ),
                trailing: soundIsPro && !isPro
                    ? const Icon(Icons.lock_outline, size: 18)
                    : null,
                onTap: () {
                  if (soundIsPro && !isPro) {
                    Navigator.pop(context);
                    AppHelper.showPaywall(context, feature: 'Premium Sounds');
                  } else {
                    focusProvider.selectedSound = sound['name']!;
                    Navigator.pop(context);
                  }
                },
              );
            }),
            20.verticalSpace,
          ],
        ),
      ),
    );
  }

  Widget _timerCircle(AppTheme theme, double progress, FocusProvider focusProvider) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.accentTxt.withOpacity(0.1), width: 6),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: theme.accentTxt.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryBase),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SecondaryText(
                text: 'Focus Time',
                color: theme.accentTxt.withOpacity(0.7),
                fontSize: 14,
              ),
              8.verticalSpace,
              PrimaryText(
                text: _formatTime(focusProvider.secondsRemaining),
                color: theme.accentTxt,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sessionTypes(AppTheme theme, FocusProvider focusProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _typeItem(theme, Icons.access_time, 'Pomodoro', focusProvider.selectedMinutes == 25, focusProvider),
        24.horizontalSpace,
        _typeItem(
          theme,
          Icons.coffee_outlined,
          'Short Break',
          focusProvider.selectedMinutes == 5,
          focusProvider,
        ),
        24.horizontalSpace,
        _typeItem(
          theme,
          Icons.bed_outlined,
          'Long Break',
          focusProvider.selectedMinutes == 15,
          focusProvider,
        ),
      ],
    );
  }

  Widget _typeItem(
    AppTheme theme,
    IconData icon,
    String label,
    bool isSelected,
    FocusProvider focusProvider,
  ) {
    return Column(
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          gradient: isSelected ? null : theme.glassGradient,
          color: isSelected ? theme.primaryBase.withOpacity(0.3) : null,
          border: isSelected
              ? Border.all(color: theme.primaryBase, width: 2)
              : null,
          customBorderRadius: BorderRadius.circular(16),
          child: Icon(
            icon,
            color: isSelected ? theme.primaryBase : theme.accentTxt,
            size: 24,
          ),
        ).rippleClick(() {
          if (!focusProvider.isRunning) {
            if (label == 'Pomodoro') focusProvider.selectedMinutes = 25;
            if (label == 'Short Break') focusProvider.selectedMinutes = 5;
            if (label == 'Long Break') focusProvider.selectedMinutes = 15;
          }
        }),
        8.verticalSpace,
        SecondaryText(
          text: label,
          color: isSelected
              ? theme.accentTxt
              : theme.accentTxt.withOpacity(0.7),
          fontSize: 11,
        ),
      ],
    );
  }
}
