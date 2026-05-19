import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
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
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _selectedMinutes = 25;
  int _secondsRemaining = 25 * 60;
  bool _isRunning = false;
  bool _isAlarmPlaying = false;

  String _selectedSound = 'Standard Alert';

  final List<Map<String, String>> _sounds = [
    {
      'name': 'Standard Alert',
      'url':
          'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
      'isPro': 'false',
    },
    {
      'name': 'Zen Garden',
      'url': 'https://assets.mixkit.co/active_storage/sfx/139/139-preview.mp3',
      'isPro': 'true',
    },
    {
      'name': 'Deep Rain',
      'url':
          'https://assets.mixkit.co/active_storage/sfx/2358/2358-preview.mp3',
      'isPro': 'true',
    },
    {
      'name': 'Mindful Bell',
      'url':
          'https://assets.mixkit.co/active_storage/sfx/2568/2568-preview.mp3',
      'isPro': 'true',
    },
  ];

  bool _isWaitingForStart = false;
  int _secondsToStart = 0;
  Timer? _waitingTimer;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialDuration ?? 25;
    _secondsRemaining = _selectedMinutes * 60;
    _audioPlayer.setSource(UrlSource(_sounds[0]['url']!));

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final now = DateTime.now();
        if (widget.scheduledStartTime != null &&
            widget.scheduledStartTime!.isAfter(now)) {
          setState(() {
            _isWaitingForStart = true;
            _secondsToStart = widget.scheduledStartTime!
                .difference(now)
                .inSeconds;
          });

          // Play an initial beep
          _playSound(durationSeconds: 2);

          _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted) {
              final diff = widget.scheduledStartTime!
                  .difference(DateTime.now())
                  .inSeconds;
              if (diff <= 0) {
                timer.cancel();
                setState(() {
                  _isWaitingForStart = false;
                  _secondsToStart = 0;
                });
                _playSound(
                  durationSeconds: 5,
                ); // Final alert when time is reached
              } else {
                setState(() => _secondsToStart = diff);
                // Beep every 10 seconds to keep the user alert without being too annoying
                if (diff % 10 == 0) {
                  _playSound(durationSeconds: 1);
                }
              }
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waitingTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playSound({int durationSeconds = 5}) async {
    try {
      if (_isAlarmPlaying) return;
      setState(() => _isAlarmPlaying = true);

      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.resume();

      // Stop sound after specified duration
      Future.delayed(Duration(seconds: durationSeconds), () async {
        if (mounted) {
          await _audioPlayer.stop();
          setState(() => _isAlarmPlaying = false);
        }
      });
    } catch (e) {
      safePrint('Error playing sound: $e');
      setState(() => _isAlarmPlaying = false);
    }
  }

  void _startTimer() {
    if (_timer != null) _timer!.cancel();
    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _stopTimer();
        _playSound(durationSeconds: 5); // Ring for at least 5 seconds
        context.read<JournalProvider>().saveFocusSession(_selectedMinutes);
        context.showInAppNotification(
          'Great job! You finished your session.',
          title: 'Focus Complete',
          type: InAppNotificationType.success,
        );
      }
    });
  }

  void _onStartTimerTap() async {
    final bool online = await AppHelper.isOnline();
    if (!online) {
      _startTimer();
    } else {
      if (mounted) {
        AppHelper.showAirplaneModePrompt(
          context,
          onStartSession: _startTimer,
        );
      }
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void resetTimer() {
    _stopTimer();
    setState(() {
      _secondsRemaining = _selectedMinutes * 60;
    });
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
    double progress = _secondsRemaining / (_selectedMinutes * 60);

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
                _timerCircle(theme, progress),
                if (_isWaitingForStart &&
                    widget.scheduledStartTime != null) ...[
                  const SizedBox(height: 20),
                  PrimaryText(
                    text: 'Starting in ${_formatTime(_secondsToStart)}',
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

                if (!_isRunning) ...[
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
                              text: _selectedSound,
                              color: theme.primaryBase,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ).clickable(() => _showSoundPicker(context)),
                          ],
                        ),
                        16.verticalSpace,
                        Slider(
                          value: _selectedMinutes.toDouble(),
                          min: 1,
                          max: 180,
                          divisions: 179,
                          activeColor: theme.primaryBase,
                          inactiveColor: theme.accentTxt.withOpacity(0.1),
                          onChanged: (val) {
                            setState(() {
                              _selectedMinutes = val.toInt();
                              _secondsRemaining = _selectedMinutes * 60;
                            });
                          },
                        ),
                        PrimaryText(
                          text: _selectedMinutes >= 60
                              ? '${_selectedMinutes ~/ 60}h ${_selectedMinutes % 60}m'
                              : '$_selectedMinutes Minutes',
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
                  text: _isRunning
                      ? 'Deep work in progress...'
                      : 'Stay focused and get things done',
                  color: theme.accentTxt.withOpacity(0.7),
                ),
                if (!_isRunning) ...[
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
                      color: _isRunning
                          ? theme.errorPrimary
                          : theme.primaryBase,
                      width: 2,
                    ),
                    child: Center(
                      child: PrimaryText(
                        text: _isRunning
                            ? 'Stop Focus Session'
                            : 'Start Focus Session',
                        color: theme.accentTxt,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ).rippleClick(_isRunning ? _stopTimer : _onStartTimerTap),
                ),
                12.verticalSpace,
                _sessionTypes(theme),
                20.verticalSpace,
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  void _showSoundPicker(BuildContext context) {
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
            ..._sounds.map((sound) {
              bool soundIsPro = sound['isPro'] == 'true';
              bool isSelected = _selectedSound == sound['name'];

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
                    setState(() {
                      _selectedSound = sound['name']!;
                      _audioPlayer.setSource(UrlSource(sound['url']!));
                    });
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

  Widget _timerCircle(AppTheme theme, double progress) {
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
                text: _formatTime(_secondsRemaining),
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

  Widget _sessionTypes(AppTheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _typeItem(theme, Icons.access_time, 'Pomodoro', _selectedMinutes == 25),
        24.horizontalSpace,
        _typeItem(
          theme,
          Icons.coffee_outlined,
          'Short Break',
          _selectedMinutes == 5,
        ),
        24.horizontalSpace,
        _typeItem(
          theme,
          Icons.bed_outlined,
          'Long Break',
          _selectedMinutes == 15,
        ),
      ],
    );
  }

  Widget _typeItem(
    AppTheme theme,
    IconData icon,
    String label,
    bool isSelected,
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
          if (!_isRunning) {
            setState(() {
              if (label == 'Pomodoro') _selectedMinutes = 25;
              if (label == 'Short Break') _selectedMinutes = 5;
              if (label == 'Long Break') _selectedMinutes = 15;
              _secondsRemaining = _selectedMinutes * 60;
            });
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
