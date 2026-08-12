import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:mindpilot/export.dart';

class FocusProvider extends ChangeNotifier with WidgetsBindingObserver {
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();
  int _selectedMinutes = 25;
  int _secondsRemaining = 25 * 60;
  bool _isRunning = false;
  bool _isAlarmPlaying = false;
  bool _isAmbientPlaying = false;
  DateTime? _endTime;
  bool _isInBackground = false;
  String _selectedSound = 'Standard Alert';
  String _selectedAmbient = 'None';

  bool _isWaitingForStart = false;
  int _secondsToStart = 0;
  Timer? _waitingTimer;
  DateTime? _scheduledStartTime;
  bool _joinLounge = false;

  final List<Map<String, String>> _sounds = [
    {
      'name': 'Standard Alert',
      'url': 'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
      'isPro': 'false',
    },
    {
      'name': 'Zen Garden',
      'url': 'https://assets.mixkit.co/active_storage/sfx/139/139-preview.mp3',
      'isPro': 'true',
    },
    {
      'name': 'Deep Rain',
      'url': 'https://assets.mixkit.co/active_storage/sfx/2358/2358-preview.mp3',
      'isPro': 'true',
    },
    {
      'name': 'Mindful Bell',
      'url': 'https://assets.mixkit.co/active_storage/sfx/2568/2568-preview.mp3',
      'isPro': 'true',
    },
  ];

  final List<Map<String, String>> _ambientSounds = [
    {
      'name': 'None',
      'path': '',
      'isPro': 'false',
    },
    {
      'name': 'Alone With God (Piano & Strings)',
      'path': 'audio/worship_piano_1.mp3',
      'isPro': 'false',
    },
    {
      'name': 'Worship Piano (Hillsong Instrumental)',
      'path': 'audio/worship_piano_2.mp3',
      'isPro': 'true',
    },
    {
      'name': 'Contemporary Praise (Piano Solo)',
      'path': 'audio/worship_piano_3.mp3',
      'isPro': 'true',
    },
  ];

  // Getters
  int get selectedMinutes => _selectedMinutes;
  int get secondsRemaining => _secondsRemaining;
  bool get isRunning => _isRunning;
  bool get isAlarmPlaying => _isAlarmPlaying;
  bool get isAmbientPlaying => _isAmbientPlaying;
  DateTime? get endTime => _endTime;
  bool get isInBackground => _isInBackground;
  String get selectedSound => _selectedSound;
  String get selectedAmbient => _selectedAmbient;
  List<Map<String, String>> get sounds => _sounds;
  List<Map<String, String>> get ambientSounds => _ambientSounds;
  bool get isWaitingForStart => _isWaitingForStart;
  int get secondsToStart => _secondsToStart;
  bool get joinLounge => _joinLounge;

  set joinLounge(bool val) {
    _joinLounge = val;
    notifyListeners();
  }

  set selectedMinutes(int val) {
    _selectedMinutes = val;
    _secondsRemaining = val * 60;
    notifyListeners();
  }

  set selectedSound(String val) {
    _selectedSound = val;
    final soundUrl = _sounds.firstWhere((s) => s['name'] == val, orElse: () => _sounds[0])['url']!;
    _audioPlayer.setSource(UrlSource(soundUrl));
    notifyListeners();
  }

  set selectedAmbient(String val) {
    _selectedAmbient = val;
    notifyListeners();
    if (_isRunning) {
      _startAmbientSound();
    }
  }

  set isInBackground(bool val) {
    _isInBackground = val;
  }

  FocusProvider() {
    _audioPlayer.setSource(UrlSource(_sounds[0]['url']!));
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _startAmbientSound() async {
    try {
      await _ambientPlayer.stop();
      _isAmbientPlaying = false;
      if (_selectedAmbient == 'None') {
        notifyListeners();
        return;
      }
      final track = _ambientSounds.firstWhere(
        (element) => element['name'] == _selectedAmbient,
        orElse: () => _ambientSounds[0],
      );
      final path = track['path'] ?? '';
      if (path.isNotEmpty) {
        await _ambientPlayer.setSource(AssetSource(path));
        await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
        await _ambientPlayer.resume();
        _isAmbientPlaying = true;
      }
      notifyListeners();
    } catch (e) {
      safePrint('Error starting ambient sound: $e');
    }
  }

  Future<void> _stopAmbientSound() async {
    try {
      await _ambientPlayer.stop();
      _isAmbientPlaying = false;
      notifyListeners();
    } catch (e) {
      safePrint('Error stopping ambient sound: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      updateTimerOnResume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isInBackground = true;
    }
  }

  void initializeWithDuration(int duration) {
    _selectedMinutes = duration;
    _secondsRemaining = duration * 60;
    NotificationService().stopAlarmSound();
    _audioPlayer.setSource(UrlSource(_sounds[0]['url']!));
    notifyListeners();
  }

  void startWaitingTimer(DateTime scheduledStartTime) {
    _scheduledStartTime = scheduledStartTime;
    _waitingTimer?.cancel();
    _isWaitingForStart = true;
    final now = DateTime.now();
    _secondsToStart = scheduledStartTime.difference(now).inSeconds;
    notifyListeners();

    _playSound(durationSeconds: 2);

    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diff = scheduledStartTime.difference(DateTime.now()).inSeconds;
      if (diff <= 0) {
        timer.cancel();
        _isWaitingForStart = false;
        _secondsToStart = 0;
        notifyListeners();
        _playSound(durationSeconds: 5);
        startTimer();
      } else {
        _secondsToStart = diff;
        notifyListeners();
        if (diff % 10 == 0) {
          _playSound(durationSeconds: 1);
        }
      }
    });
  }

  void updateTimerOnResume() {
    if (_isRunning && _endTime != null) {
      _tick();
    }
    if (_isWaitingForStart && _scheduledStartTime != null) {
      final diff = _scheduledStartTime!.difference(DateTime.now()).inSeconds;
      if (diff <= 0) {
        _waitingTimer?.cancel();
        _isWaitingForStart = false;
        _secondsToStart = 0;
        notifyListeners();
        _playSound(durationSeconds: 5);
        startTimer();
      } else {
        _secondsToStart = diff;
        notifyListeners();
      }
    }
  }

  void _playSound({int durationSeconds = 5}) async {
    try {
      if (_isAlarmPlaying) return;
      _isAlarmPlaying = true;
      notifyListeners();

      final bool online = await AppHelper.isOnline();
      if (!online) {
        await _audioPlayer.setSource(AssetSource('audio/alarm.mp3'));
      } else {
        final selectedSoundMap = _sounds.firstWhere(
          (s) => s['name'] == _selectedSound,
          orElse: () => _sounds[0],
        );
        await _audioPlayer.setSource(UrlSource(selectedSoundMap['url']!));
      }

      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.resume();

      // Stop sound after specified duration
      Future.delayed(Duration(seconds: durationSeconds), () async {
        await _audioPlayer.stop();
        _isAlarmPlaying = false;
        notifyListeners();
      });
    } catch (e) {
      safePrint('Error playing sound in FocusProvider: $e');
      try {
        await _audioPlayer.setSource(AssetSource('audio/alarm.mp3'));
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.resume();
        Future.delayed(Duration(seconds: durationSeconds), () async {
          await _audioPlayer.stop();
          _isAlarmPlaying = false;
          notifyListeners();
        });
      } catch (innerError) {
        safePrint('Error playing fallback sound in FocusProvider: $innerError');
        _isAlarmPlaying = false;
        notifyListeners();
      }
    }
  }

  void startTimer() {
    if (_timer != null) _timer!.cancel();
    _endTime = DateTime.now().add(Duration(seconds: _secondsRemaining));
    _isRunning = true;
    notifyListeners();

    _startAmbientSound();

    NotificationService().scheduleFocusCompleteAlarm(
      endTime: _endTime!,
      soundName: _selectedSound,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick();
    });
  }

  void _tick() {
    if (_endTime == null) return;
    final now = DateTime.now();
    final remaining = _endTime!.difference(now).inSeconds;

    if (remaining > 0) {
      _secondsRemaining = remaining;
      notifyListeners();
    } else {
      _secondsRemaining = 0;
      _timer?.cancel();
      _endTime = null;
      _isRunning = false;
      notifyListeners();

      _stopAmbientSound();

      final context = R.N.navKey.currentContext;
      if (!_isInBackground) {
        _playSound(durationSeconds: 5);
      } else {
        NotificationService().showFocusCompleteNotification();
      }

      if (context != null) {
        try {
          context.read<GroupQuizProvider>().leaveVoiceRoom();
        } catch (_) {}
        context.read<JournalProvider>().saveFocusSession(_selectedMinutes);
        EngagementService().recordAction(EngagementAction.focusComplete);
        if (!context.read<AppAuthProvider>().hasCompletedFirstSession) {
          EngagementService().markFirstSessionComplete('focus');
          context.read<AppAuthProvider>().markFirstSessionComplete();
        }
        _showPostFocusJournalPrompt(context);
        context.showInAppNotification(
          'Great job! You finished your session.',
          title: 'Focus Complete',
          type: InAppNotificationType.success,
        );
      }
    }
  }

  void stopTimer() {
    _timer?.cancel();
    _endTime = null;
    _isRunning = false;
    notifyListeners();
    _stopAmbientSound();
    NotificationService().cancelFocusCompleteAlarm();
    final context = R.N.navKey.currentContext;
    if (context != null) {
      try {
        context.read<GroupQuizProvider>().leaveVoiceRoom();
      } catch (_) {}
    }
  }

  void resetTimer() {
    stopTimer();
    _secondsRemaining = _selectedMinutes * 60;
    notifyListeners();
  }

  void _showPostFocusJournalPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        AppTheme theme = ctx.watch();
        return AlertDialog(
          backgroundColor: theme.brandDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: PrimaryText(
            text: 'How did it feel?',
            color: theme.accentTxt,
            fontWeight: FontWeight.bold,
          ),
          content: SecondaryText(
            text: 'Capture a quick journal note about your focus session.',
            color: theme.accentTxt.withOpacity(0.7),
            fontSize: 13,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: SecondaryText(text: 'Later', color: theme.accentTxt.withOpacity(0.6)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ctx.push(const JournalEntriesScreen());
              },
              child: PrimaryText(
                text: 'Journal Now',
                color: theme.primaryBase,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _waitingTimer?.cancel();
    _audioPlayer.dispose();
    _ambientPlayer.dispose();
    super.dispose();
  }
}
