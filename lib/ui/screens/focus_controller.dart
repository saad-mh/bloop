import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';

import '../../providers/settings_provider.dart';
import '../../services/focus_foreground_task.dart';
import '../../services/notif_service.dart';
import '../../services/storage_service.dart';

final focusControllerProvider = ChangeNotifierProvider<FocusController>((ref) {
  return FocusController(ref: ref);
});

const Map<String, String> focusSoundAssets = {
  'Soft Chime': 'assets/audio/ambient_1.mp3',
  'Rain Drop': 'assets/audio/rain_1.mp3',
  'White Noise': 'assets/audio/white_noise.mp3',
  'Forest Bell': 'assets/audio/forest.mp3',
  'Fireplace': 'assets/audio/fireplace_1.mp3',
  'Piano Drift': 'assets/audio/piano_1.mp3',
  'Thunder': 'assets/audio/rain_thunder.wav',
};

class FocusController extends ChangeNotifier {
  FocusController({required Ref ref}) : _ref = ref {
    final settings = _ref.read(settingsProvider);
    _focusSessionNotificationsEnabled =
        settings.focusSessionNotificationsEnabled;
    _fullScreenEnabled = settings.focusFullScreenEnabled;
    _appPinningEnabled = settings.focusAppPinningEnabled;
    _allowOverrides = settings.focusAllowOverrides;
    _notifService.initNotification();
    _focusActionSub = _notifService.focusSessionActions.listen((action) {
      switch (action) {
        case FocusSessionAction.toggle:
          if (_isRunning) {
            pause();
          } else {
            start();
          }
          return;
        case FocusSessionAction.skip:
          nextSession();
          return;
      }
    });
    _ref.listen<SettingsState>(settingsProvider, (previous, next) {
      if (previous?.focusSessionNotificationsEnabled ==
          next.focusSessionNotificationsEnabled) {
        // still allow other focus settings to update below
      } else {
        _focusSessionNotificationsEnabled =
            next.focusSessionNotificationsEnabled;
        if (_focusSessionNotificationsEnabled) {
          _syncFocusSessionNotification();
        } else {
          _stopFocusNotificationUpdates();
          _cancelFocusSessionNotification();
        }
      }
      _fullScreenEnabled = next.focusFullScreenEnabled;
      _appPinningEnabled = next.focusAppPinningEnabled;
      _allowOverrides = next.focusAllowOverrides;
      _safeNotify();
    });
    _loadPersistedState();
  }

  static const int _notificationId = 90001;
  static const String _totalSessionsKey = FocusSessionPrefs.totalSessionsKey;
  static const String _dimScreenEnabledKey = 'focus.ui.dimScreenEnabled';
  static const String _soundsEnabledKey = 'focus.ui.soundsEnabled';
  static const String _sceneryEnabledKey = 'focus.ui.sceneryEnabled';
  static const String _selectedSoundKey = 'focus.ui.selectedSound';
  static const String _selectedSceneryKey = 'focus.ui.selectedScenery';

  final Ref _ref;

  final NotifService _notifService = NotifService();
  final _FocusAudioEngine _audioEngine = _FocusAudioEngine();
  Timer? _timer;
  Timer? _notificationTimer;
  StreamSubscription<FocusSessionAction>? _focusActionSub;
  bool _disposed = false;

  Duration _focusDuration = const Duration(minutes: 25);
  Duration _shortBreakDuration = const Duration(minutes: 5);
  Duration _longBreakDuration = const Duration(minutes: 15);
  int _totalSessions = 4;
  bool _autoStartNext = true;
  Duration _totalFocusSpent = Duration.zero;
  DateTime? _sessionStartUtc;
  int _plannedDurationSeconds = const Duration(minutes: 25).inSeconds;

  Duration _remaining = const Duration(minutes: 25);
  bool _isRunning = false;
  bool _isSessionActive = false;
  int _sessionIndex = 1;
  _SessionType _sessionType = _SessionType.focus;
  bool _isInitializing = true;
  bool _focusSessionNotificationsEnabled = false;
  bool _fullScreenEnabled = true;
  bool _dimScreenEnabled = true;
  bool _appPinningEnabled = false;
  bool _soundsEnabled = true;
  bool _sceneryEnabled = true;
  bool _allowOverrides = false;
  String _selectedSound = 'Soft Chime';
  String _selectedScenery = 'Aurora';

  bool get isInitializing => _isInitializing;
  bool get isRunning => _isRunning;
  bool get isSessionActive => _isSessionActive;
  int get sessionIndex => _sessionIndex;
  int get totalSessions => _totalSessions;
  Duration get remaining => _remaining;
  Duration get focusDuration => _focusDuration;
  Duration get shortBreakDuration => _shortBreakDuration;
  Duration get longBreakDuration => _longBreakDuration;
  bool get autoStartNext => _autoStartNext;
  Duration get totalFocusSpent => _totalFocusSpent;
  String get sessionLabel => _sessionLabel();
  String get focusHintText => _focusHintText();
  bool get fullScreenEnabled => _fullScreenEnabled;
  bool get dimScreenEnabled => _dimScreenEnabled;
  bool get appPinningEnabled => _appPinningEnabled;
  bool get soundsEnabled => _soundsEnabled;
  bool get sceneryEnabled => _sceneryEnabled;
  bool get allowOverrides => _allowOverrides;
  String get selectedSound => _selectedSound;
  String get selectedScenery => _selectedScenery;
  bool get isFocusSession => _sessionType == _SessionType.focus;

  bool get isFullScreenActive => _isSessionActive && _fullScreenEnabled;

  double get progress {
    final maxSeconds = _currentSessionDuration().inSeconds;
    if (maxSeconds == 0) return 0.0;
    return 1 - (_remaining.inSeconds / maxSeconds);
  }

  void handleLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _stopUiTimer();
        _notificationTimer?.cancel();
        _notificationTimer = null;
        _updateRemaining(DateTime.now().toUtc());
        _persistState();
        if (_focusSessionNotificationsEnabled && _isSessionActive) {
          _syncFocusSessionNotification();
        }
        return;
      case AppLifecycleState.resumed:
        _restoreAndRecompute();
        return;
      case AppLifecycleState.detached:
        return;
    }
  }

  void start() {
    final nowUtc = DateTime.now().toUtc();
    _timer?.cancel();
    _isRunning = true;
    _isSessionActive = true;
    _sessionStartUtc = nowUtc;
    _remaining = Duration(seconds: _plannedDurationSeconds);
    _safeNotify();
    _scheduleNotification(nowUtc);
    _persistState();
    _startUiTimer();
    _startFocusNotificationUpdates();
    _syncAudioForState();
  }

  void pause() {
    if (!_isRunning) return;
    final nowUtc = DateTime.now().toUtc();
    _stopUiTimer();
    _stopFocusNotificationUpdates();
    _updateRemaining(nowUtc);
    _accumulateFocusTime(nowUtc: nowUtc);
    _isRunning = false;
    _isSessionActive = true;
    _sessionStartUtc = nowUtc;
    _plannedDurationSeconds = _remaining.inSeconds;
    _safeNotify();
    _cancelNotification();
    _persistState();
    _syncFocusSessionNotification();
    _syncAudioForState();
  }

  void reset() {
    _stopUiTimer();
    _stopFocusNotificationUpdates();
    _cancelNotification();
    _sessionType = _SessionType.focus;
    _sessionIndex = 1;
    _isRunning = false;
    _isSessionActive = false;
    _sessionStartUtc = DateTime.now().toUtc();
    _plannedDurationSeconds = _focusDuration.inSeconds;
    _remaining = _focusDuration;
    _safeNotify();
    _persistState();
    _cancelFocusSessionNotification();
    _syncAudioForState();
  }

  void nextSession() {
    _stopUiTimer();
    _stopFocusNotificationUpdates();
    _cancelNotification();
    _accumulateFocusTime(nowUtc: DateTime.now().toUtc());
    _advanceSession();
    _isRunning = false;
    _isSessionActive = false;
    _sessionStartUtc = DateTime.now().toUtc();
    _plannedDurationSeconds = _currentSessionDuration().inSeconds;
    _remaining = _currentSessionDuration();
    _safeNotify();
    _persistState();
    _cancelFocusSessionNotification();
    _syncAudioForState();
  }

  void applySettings({
    required int focusMinutes,
    required int shortMinutes,
    required int longMinutes,
    required int totalSessions,
    required bool autoStartNext,
  }) {
    _focusDuration = Duration(minutes: focusMinutes.clamp(1, 180));
    _shortBreakDuration = Duration(minutes: shortMinutes.clamp(1, 60));
    _longBreakDuration = Duration(minutes: longMinutes.clamp(1, 120));
    _totalSessions = totalSessions.clamp(1, 12);
    _autoStartNext = autoStartNext;
    _sessionType = _SessionType.focus;
    _sessionIndex = 1;
    _isRunning = false;
    _isSessionActive = false;
    _sessionStartUtc = DateTime.now().toUtc();
    _plannedDurationSeconds = _focusDuration.inSeconds;
    _remaining = _focusDuration;
    _safeNotify();
    _stopUiTimer();
    _stopFocusNotificationUpdates();
    _cancelNotification();
    _persistState();
    _cancelFocusSessionNotification();
    _syncAudioForState();
  }

  void updateSessionPreferences({
    bool? fullScreenEnabled,
    bool? appPinningEnabled,
    bool? dimScreenEnabled,
    bool? soundsEnabled,
    bool? sceneryEnabled,
    bool? allowOverrides,
  }) {
    if (fullScreenEnabled != null) {
      _fullScreenEnabled = fullScreenEnabled;
      _ref
          .read(settingsProvider.notifier)
          .setFocusFullScreenEnabled(fullScreenEnabled);
    }
    if (appPinningEnabled != null) {
      _appPinningEnabled = appPinningEnabled;
      _ref
          .read(settingsProvider.notifier)
          .setFocusAppPinningEnabled(appPinningEnabled);
    }
    _dimScreenEnabled = dimScreenEnabled ?? _dimScreenEnabled;
    _soundsEnabled = soundsEnabled ?? _soundsEnabled;
    _sceneryEnabled = sceneryEnabled ?? _sceneryEnabled;
    if (allowOverrides != null) {
      _allowOverrides = allowOverrides;
      _ref
          .read(settingsProvider.notifier)
          .setFocusAllowOverrides(allowOverrides);
    }
    _persistUiPrefs();
    _safeNotify();
    _syncAudioForState();
  }

  void setSelectedSound(String value) {
    _selectedSound = value;
    _persistUiPrefs();
    _safeNotify();
    if (_isSessionActive && _isRunning && _sessionType == _SessionType.focus) {
      _syncAudioForState(restart: true);
    }
  }

  void setSelectedScenery(String value) {
    _selectedScenery = value;
    _persistUiPrefs();
    _safeNotify();
  }

  void _handleSessionComplete(DateTime nowUtc) {
    _stopUiTimer();
    _stopFocusNotificationUpdates();
    _cancelNotification();
    _cancelFocusSessionNotification();
    _finalizeFocusTime(nowUtc: nowUtc);
    _isRunning = false;
    _advanceSession();
    _sessionStartUtc = nowUtc;
    _plannedDurationSeconds = _currentSessionDuration().inSeconds;
    _remaining = _currentSessionDuration();
    _isSessionActive = _autoStartNext;
    _safeNotify();
    _persistState();
    _syncAudioForState();
    if (_autoStartNext) {
      start();
    }
  }

  void _advanceSession() {
    if (_sessionType == _SessionType.focus) {
      final isLastFocus = _sessionIndex >= _totalSessions;
      _sessionType = isLastFocus ? _SessionType.longBreak : _SessionType.shortBreak;
      return;
    }
    if (_sessionType == _SessionType.shortBreak) {
      _sessionIndex = (_sessionIndex % _totalSessions) + 1;
      _sessionType = _SessionType.focus;
      return;
    }
    _sessionIndex = 1;
    _sessionType = _SessionType.focus;
  }

  String _sessionLabel() {
    switch (_sessionType) {
      case _SessionType.focus:
        return 'Focus';
      case _SessionType.shortBreak:
        return 'Short break';
      case _SessionType.longBreak:
        return 'Long break';
    }
  }

  Duration _currentSessionDuration() {
    switch (_sessionType) {
      case _SessionType.focus:
        return _focusDuration;
      case _SessionType.shortBreak:
        return _shortBreakDuration;
      case _SessionType.longBreak:
        return _longBreakDuration;
    }
  }

  String _focusHintText() {
    switch (_sessionType) {
      case _SessionType.focus:
        return 'Focus on one task for ${_focusDuration.inMinutes} minutes';
      case _SessionType.shortBreak:
        return 'Take a short break for ${_shortBreakDuration.inMinutes} minutes';
      case _SessionType.longBreak:
        return 'Recharge for ${_longBreakDuration.inMinutes} minutes';
    }
  }

  void _accumulateFocusTime({DateTime? nowUtc}) {
    if (_sessionType != _SessionType.focus) {
      return;
    }
    if (_sessionStartUtc == null) {
      return;
    }
    final now = nowUtc ?? DateTime.now().toUtc();
    final elapsed = now.difference(_sessionStartUtc!);
    if (elapsed.isNegative || elapsed == Duration.zero) {
      return;
    }
    _totalFocusSpent += elapsed;
    _sessionStartUtc = now;
    _safeNotify();
  }

  void _finalizeFocusTime({required DateTime nowUtc}) {
    if (_sessionType != _SessionType.focus) {
      return;
    }
    if (_sessionStartUtc == null) return;
    final elapsed = nowUtc.difference(_sessionStartUtc!);
    if (elapsed.isNegative || elapsed == Duration.zero) return;
    final maxElapsed = Duration(seconds: _plannedDurationSeconds);
    _totalFocusSpent += elapsed > maxElapsed ? maxElapsed : elapsed;
    _sessionStartUtc = nowUtc;
    _safeNotify();
  }

  Duration _computeRemaining({DateTime? nowUtc}) {
    if (!_isRunning || _sessionStartUtc == null) {
      return Duration(seconds: _plannedDurationSeconds);
    }
    final now = nowUtc ?? DateTime.now().toUtc();
    final elapsedSeconds = now.difference(_sessionStartUtc!).inSeconds;
    final remainingSeconds = _plannedDurationSeconds - elapsedSeconds;
    return Duration(seconds: remainingSeconds < 0 ? 0 : remainingSeconds);
  }

  void _updateRemaining(DateTime nowUtc) {
    final remaining = _computeRemaining(nowUtc: nowUtc);
    if (remaining.inSeconds <= 0) {
      _handleSessionComplete(nowUtc);
      return;
    }
    _remaining = remaining;
    _safeNotify();
  }

  void _startUiTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRunning) {
        _stopUiTimer();
        return;
      }
      _updateRemaining(DateTime.now().toUtc());
    });
  }

  void _startFocusNotificationUpdates() {
    if (!_focusSessionNotificationsEnabled) return;
    _notificationTimer?.cancel();
    _syncFocusSessionNotification();
    if (_isRunning) {
      _notificationTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => _syncFocusSessionNotification(),
      );
      _startForegroundService();
    } else {
      _stopForegroundService();
    }
  }

  void _stopUiTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _stopFocusNotificationUpdates() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _stopForegroundService();
  }

  Future<void> _scheduleNotification(DateTime startUtc) async {
    final endTime = startUtc.add(Duration(seconds: _plannedDurationSeconds));
    await _notifService.scheduleAt(
      id: _notificationId,
      title: _sessionLabel(),
      body: 'Session complete',
      scheduledTime: endTime,
    );
  }

  Future<void> _cancelNotification() async {
    await _notifService.cancelNotification(_notificationId);
  }

  Future<void> _cancelFocusSessionNotification() async {
    await _notifService.cancelNotification(FocusSessionPrefs.focusNotificationId);
  }

  Future<void> _persistState() async {
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      await box.put(FocusSessionPrefs.sessionTypeKey, _sessionType.name);
      await box.put(
        FocusSessionPrefs.sessionStartKey,
        (_sessionStartUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch,
      );
      await box.put(FocusSessionPrefs.plannedDurationKey, _plannedDurationSeconds);
      await box.put(FocusSessionPrefs.sessionIndexKey, _sessionIndex);
      await box.put(_totalSessionsKey, _totalSessions);
      await box.put(FocusSessionPrefs.isRunningKey, _isRunning);
      await box.put(FocusSessionPrefs.isActiveKey, _isSessionActive);
      await FocusSessionPrefs.writeSession(
        sessionType: _sessionType.name,
        sessionStartUtc: _sessionStartUtc ?? DateTime.now().toUtc(),
        plannedDurationSeconds: _plannedDurationSeconds,
        sessionIndex: _sessionIndex,
        totalSessions: _totalSessions,
        isRunning: _isRunning,
        isActive: _isSessionActive,
      );
    } catch (_) {
      // ignore persistence failures
    }
  }

  Future<void> _persistUiPrefs() async {
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      await box.put(_dimScreenEnabledKey, _dimScreenEnabled);
      await box.put(_soundsEnabledKey, _soundsEnabled);
      await box.put(_sceneryEnabledKey, _sceneryEnabled);
      await box.put(_selectedSoundKey, _selectedSound);
      await box.put(_selectedSceneryKey, _selectedScenery);
    } catch (_) {
      // ignore persistence failures
    }
  }

  Future<void> _loadPersistedState() async {
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      final storedType = box.get(FocusSessionPrefs.sessionTypeKey) as String?;
      final storedStart = box.get(FocusSessionPrefs.sessionStartKey) as int?;
      final storedPlanned = box.get(FocusSessionPrefs.plannedDurationKey) as int?;
      final storedIndex = box.get(FocusSessionPrefs.sessionIndexKey) as int?;
      final storedTotal = box.get(_totalSessionsKey) as int?;
      final storedRunning = box.get(FocusSessionPrefs.isRunningKey) as bool?;
      final storedActive = box.get(FocusSessionPrefs.isActiveKey) as bool?;
      final storedDim = box.get(_dimScreenEnabledKey) as bool?;
      final storedSounds = box.get(_soundsEnabledKey) as bool?;
      final storedScenery = box.get(_sceneryEnabledKey) as bool?;
      final storedSoundChoice = box.get(_selectedSoundKey) as String?;
      final storedSceneryChoice = box.get(_selectedSceneryKey) as String?;

      if (storedType != null) {
        _sessionType = _SessionType.values.firstWhere(
          (t) => t.name == storedType,
          orElse: () => _SessionType.focus,
        );
      }
      if (storedStart != null) {
        _sessionStartUtc = DateTime.fromMillisecondsSinceEpoch(
          storedStart,
          isUtc: true,
        );
      }
      _plannedDurationSeconds = storedPlanned ?? _currentSessionDuration().inSeconds;
      _sessionIndex = storedIndex ?? _sessionIndex;
      _totalSessions = storedTotal ?? _totalSessions;
      _isRunning = storedRunning ?? false;
      _isSessionActive = storedActive ?? _isRunning;
      _dimScreenEnabled = storedDim ?? _dimScreenEnabled;
      _soundsEnabled = storedSounds ?? _soundsEnabled;
      _sceneryEnabled = storedScenery ?? _sceneryEnabled;
      _selectedSound = storedSoundChoice ?? _selectedSound;
      _selectedScenery = storedSceneryChoice ?? _selectedScenery;
    } catch (_) {
      // ignore load failures
    }
    if (_disposed) return;
    _remaining = _computeRemaining(nowUtc: DateTime.now().toUtc());
    _isInitializing = false;
    _safeNotify();
    _syncAudioForState();
    if (_isRunning) {
      if (_remaining.inSeconds <= 0) {
        _handleSessionComplete(DateTime.now().toUtc());
      } else {
        _startUiTimer();
        _startFocusNotificationUpdates();
      }
    } else if (_isSessionActive) {
      _syncFocusSessionNotification();
    }
  }

  Future<void> _restoreAndRecompute() async {
    await _loadPersistedState();
    if (_isRunning) {
      _updateRemaining(DateTime.now().toUtc());
    }
    if (_isRunning) {
      _startFocusNotificationUpdates();
    } else if (_isSessionActive) {
      _syncFocusSessionNotification();
    }
  }

  void _syncAudioForState({bool restart = false}) {
    if (!_soundsEnabled || !_isSessionActive || _sessionType != _SessionType.focus) {
      unawaited(_audioEngine.stop());
      return;
    }
    if (_isRunning) {
      final asset = focusSoundAssets[_selectedSound] ??
          (focusSoundAssets.isNotEmpty ? focusSoundAssets.values.first : '');
      if (asset.isEmpty) {
        unawaited(_audioEngine.stop());
      } else {
        unawaited(_audioEngine.playLoop(asset, restart: restart));
      }
      return;
    }
    unawaited(_audioEngine.pause());
  }

  void _syncFocusSessionNotification() {
    if (!_focusSessionNotificationsEnabled || !_isSessionActive) {
      _cancelFocusSessionNotification();
      return;
    }
    final remaining = _computeRemaining(nowUtc: DateTime.now().toUtc());
    final minutesLeft = (remaining.inSeconds / 60).ceil().clamp(0, 9999);
    final title = '${_sessionLabel()} • $minutesLeft min left';
    final body = _focusSecondaryLine();
    _notifService.showFocusSessionNotification(
      id: FocusSessionPrefs.focusNotificationId,
      title: title,
      body: body,
      remainingSeconds: remaining.inSeconds,
      totalSeconds: _plannedDurationSeconds,
      isRunning: _isRunning,
    );
  }

  String _focusSecondaryLine() {
    switch (_sessionType) {
      case _SessionType.focus:
        return 'Session $_sessionIndex of $_totalSessions • Deep focus session';
      case _SessionType.shortBreak:
        return 'Break time - relax';
      case _SessionType.longBreak:
        return 'Break time - recharge';
    }
  }

  Future<void> _startForegroundService() async {
    if (!Platform.isAndroid || !_focusSessionNotificationsEnabled) return;
    final running = await FlutterForegroundTask.isRunningService;
    if (!running) {
      await FlutterForegroundTask.startService(
        notificationTitle: _sessionLabel(),
        notificationText: 'Updating focus session',
        callback: startFocusForegroundTask,
      );
    }
  }

  Future<void> _stopForegroundService() async {
    if (!Platform.isAndroid) return;
    final running = await FlutterForegroundTask.isRunningService;
    if (running) {
      await FlutterForegroundTask.stopService();
    }
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _notificationTimer?.cancel();
    _focusActionSub?.cancel();
    _stopForegroundService();
    unawaited(_audioEngine.dispose());
    super.dispose();
  }
}

class _FocusAudioEngine {
  final AudioPlayer _player = AudioPlayer();
  String? _currentAsset;

  Future<void> playLoop(String assetPath, {bool restart = false}) async {
    final bool shouldChangeSource = restart || _currentAsset != assetPath;

    if (shouldChangeSource && _player.playing) {
      await _player.stop();
    }

    if (shouldChangeSource) {
      _currentAsset = assetPath;
      await _player.setAudioSource(AudioSource.asset(assetPath));
    }
    await _player.setLoopMode(LoopMode.one);
    if (!_player.playing) {
      await _player.play();
    }
  }

  Future<void> pause() async {
    if (_player.playing) {
      await _player.pause();
    }
  }

  Future<void> stop() async {
    if (_currentAsset != null) {
      if (_player.playing) {
        await _player.stop();
      }
      _currentAsset = null;
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}

enum _SessionType {
  focus,
  shortBreak,
  longBreak,
}
