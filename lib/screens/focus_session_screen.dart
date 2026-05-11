import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:mindpilot/export.dart';

class FocusSessionScreen extends StatefulWidget {
  const FocusSessionScreen({super.key});

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> {
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _selectedMinutes = 25;
  int _secondsRemaining = 25 * 60;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.setSource(
      UrlSource(
        'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
      ),
    );
  }

  void _playSound() async {
    try {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.resume();
    } catch (e) {
      safePrint('Error playing sound: $e');
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
        _playSound();
        context.read<JournalProvider>().saveFocusSession(_selectedMinutes);
        context.showInAppNotification(
          'Great job! You finished your session.',
          title: 'Focus Complete',
          type: InAppNotificationType.success,
        );
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
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
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    double progress = _secondsRemaining / (_selectedMinutes * 60);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.6,
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
                      Icon(Icons.more_horiz, color: theme.accentTxt),
                    ],
                  ),
                ),
                const Spacer(),
                _timerCircle(theme, progress),
                const Spacer(),
                if (!_isRunning) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        SecondaryText(
                          text: 'Adjust Focus Time',
                          color: theme.accentTxt.withOpacity(0.7),
                        ),
                        10.verticalSpace,
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
                  24.verticalSpace,
                ],
                SecondaryText(
                  text: _isRunning
                      ? 'Deep work in progress...'
                      : 'Stay focused and get things done',
                  color: theme.accentTxt.withOpacity(0.7),
                ),
                24.verticalSpace,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: CustomButton(
                    label: _isRunning
                        ? 'Stop Focus Session'
                        : 'Start Focus Session',
                    onPressed: _isRunning ? _stopTimer : _startTimer,
                    backgroundColor: _isRunning
                        ? theme.errorPrimary
                        : theme.primaryBase,
                  ),
                ),
                40.verticalSpace,
                _sessionTypes(theme),
                20.verticalSpace,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timerCircle(AppTheme theme, double progress) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.accentTxt.withOpacity(0.1), width: 8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 250,
            height: 250,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
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
                fontSize: 48,
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.primaryBase
                : theme.accentTxt.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.accentTxt, size: 24),
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
