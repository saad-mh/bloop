import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/notif_service.dart';
import '../../services/storage_service.dart';
import '../../services/focus_foreground_task.dart';
import '../../providers/settings_provider.dart';

class FocusScreen extends StatelessWidget {
	const FocusScreen({Key? key}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Focus'),
				toolbarHeight: MediaQuery.of(context).size.height * 0.1,
				// centerTitle: true,
			),
			body: const SafeArea(
				child: _PomodoroCard(),
			),
		);
	}
}

class _PomodoroCard extends ConsumerStatefulWidget {
	const _PomodoroCard();

	@override
	ConsumerState<_PomodoroCard> createState() => _PomodoroCardState();
}

class _PomodoroCardState extends ConsumerState<_PomodoroCard> with WidgetsBindingObserver {
	Timer? _timer;
	Timer? _notificationTimer;
	StreamSubscription<FocusSessionAction>? _focusActionSub;
	final NotifService _notifService = NotifService();

	static const int _notificationId = 90001;
	static const String _totalSessionsKey = FocusSessionPrefs.totalSessionsKey;

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
	bool _registeredSettingsListener = false;

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addObserver(this);
		_notifService.initNotification();
		_focusSessionNotificationsEnabled =
				ref.read(settingsProvider).focusSessionNotificationsEnabled;
		_focusActionSub = _notifService.focusSessionActions.listen((action) {
			if (!mounted) return;
			switch (action) {
				case FocusSessionAction.toggle:
					if (_isRunning) {
						_pause();
					} else {
						_start();
					}
					return;
				case FocusSessionAction.skip:
					_nextSession();
					return;
			}
		});
		_loadPersistedState();
	}

	@override
	void dispose() {
		WidgetsBinding.instance.removeObserver(this);
		_timer?.cancel();
		_notificationTimer?.cancel();
		_focusActionSub?.cancel();
		super.dispose();
	}

	@override
	void didChangeAppLifecycleState(AppLifecycleState state) {
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

	void _start() {
		final nowUtc = DateTime.now().toUtc();
		_timer?.cancel();
		setState(() {
			_isRunning = true;
			_isSessionActive = true;
			_sessionStartUtc = nowUtc;
			_remaining = Duration(seconds: _plannedDurationSeconds);
		});
		_scheduleNotification(nowUtc);
		_persistState();
		_startUiTimer();
		_startFocusNotificationUpdates();
	}

	void _pause() {
		if (!_isRunning) return;
		final nowUtc = DateTime.now().toUtc();
		_stopUiTimer();
		_stopFocusNotificationUpdates();
		_updateRemaining(nowUtc);
		_accumulateFocusTime(nowUtc: nowUtc);
		setState(() {
			_isRunning = false;
			_isSessionActive = true;
			_sessionStartUtc = nowUtc;
			_plannedDurationSeconds = _remaining.inSeconds;
		});
		_cancelNotification();
		_persistState();
		_syncFocusSessionNotification();
	}

	void _reset() {
		_stopUiTimer();
		_stopFocusNotificationUpdates();
		_cancelNotification();
		setState(() {
			_sessionType = _SessionType.focus;
			_sessionIndex = 1;
			_isRunning = false;
			_isSessionActive = false;
			_sessionStartUtc = DateTime.now().toUtc();
			_plannedDurationSeconds = _focusDuration.inSeconds;
			_remaining = _focusDuration;
		});
		_persistState();
		_cancelFocusSessionNotification();
	}

	void _nextSession() {
		_stopUiTimer();
		_stopFocusNotificationUpdates();
		_cancelNotification();
		_accumulateFocusTime(nowUtc: DateTime.now().toUtc());
		setState(() {
			_advanceSession();
			_isRunning = false;
			_isSessionActive = false;
			_sessionStartUtc = DateTime.now().toUtc();
			_plannedDurationSeconds = _currentSessionDuration().inSeconds;
			_remaining = _currentSessionDuration();
		});
		_persistState();
		_cancelFocusSessionNotification();
	}

	void _handleSessionComplete(DateTime nowUtc) {
		_stopUiTimer();
		_stopFocusNotificationUpdates();
		_cancelNotification();
		_cancelFocusSessionNotification();
		_finalizeFocusTime(nowUtc: nowUtc);
		setState(() {
			_isRunning = false;
			_advanceSession();
			_sessionStartUtc = nowUtc;
			_plannedDurationSeconds = _currentSessionDuration().inSeconds;
			_remaining = _currentSessionDuration();
			_isSessionActive = _autoStartNext;
		});
		_persistState();
		if (_autoStartNext) {
			_start();
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

	@override
	Widget build(BuildContext context) {
		// Register settings listener once. Some Riverpod versions restrict
		// `ref.listen` to be used from the build method of consumer widgets;
		// registering here ensures we comply while only registering once.
		if (!_registeredSettingsListener) {
			_registeredSettingsListener = true;
			ref.listen<SettingsState>(settingsProvider, (previous, next) {
				if (previous?.focusSessionNotificationsEnabled ==
					next.focusSessionNotificationsEnabled) return;
				setState(() {
					_focusSessionNotificationsEnabled = next.focusSessionNotificationsEnabled;
				});
				if (_focusSessionNotificationsEnabled) {
					_syncFocusSessionNotification();
				} else {
					_stopFocusNotificationUpdates();
					_cancelFocusSessionNotification();
				}
			});
		}

		final scheme = Theme.of(context).colorScheme;
		final textTheme = Theme.of(context).textTheme;
		if (_isInitializing) {
			return const Padding(
				padding: EdgeInsets.all(24),
				child: Center(child: CircularProgressIndicator()),
			);
		}
		final maxSeconds = _currentSessionDuration().inSeconds;
		final progress = maxSeconds == 0
				? 0.0
				: 1 - (_remaining.inSeconds / maxSeconds);
		final minutes = _twoDigits(_remaining.inMinutes.remainder(60));
		final seconds = _twoDigits(_remaining.inSeconds.remainder(60));

		return Padding(
			padding: const EdgeInsets.all(20),
			child: Card(
				color: scheme.surfaceContainerHighest,
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(24),
				),
				child: Padding(
					padding: const EdgeInsets.all(20),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							Row(
								children: [
									Icon(Icons.timer_rounded, color: scheme.primary),
									const SizedBox(width: 8),
									Text(
											_sessionLabel(),
										style: textTheme.titleLarge?.copyWith(
											fontWeight: FontWeight.w600,
										),
									),
									const Spacer(),
									FilledButton.tonal(
										onPressed: _nextSession,
										child: Text('Session $_sessionIndex/$_totalSessions'),
									),
										IconButton(
											tooltip: 'Edit pomodoro',
											icon: const Icon(Icons.settings),
											onPressed: _openSettings,
										),
								],
							),
							const SizedBox(height: 20),
							TweenAnimationBuilder<double>(
								duration: const Duration(milliseconds: 500),
								tween: Tween(begin: 0, end: progress.clamp(0, 1)),
								builder: (context, value, child) {
									return Stack(
										alignment: Alignment.center,
										children: [
											SizedBox(
												width: 180,
												height: 180,
												child: CircularProgressIndicator(
													value: value,
													strokeWidth: 10,
													color: scheme.primary,
													backgroundColor: scheme.surfaceVariant,
												),
											),
											_buildAnimatedTime(
												context,
												minutes: minutes,
												seconds: seconds,
											),
										],
									);
								},
							),
							const SizedBox(height: 16),
							Text(
								_focusHintText(),
								style: textTheme.bodyMedium?.copyWith(
									color: scheme.onSurfaceVariant,
								),
							),
							const SizedBox(height: 20),
							Row(
								children: [
									Expanded(
										child: FilledButton(
											onPressed: _isRunning ? _pause : _start,
											child: Text(_isRunning ? 'Pause' : 'Start'),
										),
									),
									const SizedBox(width: 12),
									Expanded(
										child: OutlinedButton(
											onPressed: _reset,
											child: const Text('Reset'),
										),
									),
								],
							),
							const SizedBox(height: 16),
							FocusedTodayCard(focusedDuration: _totalFocusSpent),
						],
					),
				),
			),
		);
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
		setState(() {
			_totalFocusSpent += elapsed;
			_sessionStartUtc = now;
		});
	}

	void _finalizeFocusTime({required DateTime nowUtc}) {
		if (_sessionType != _SessionType.focus) {
			return;
		}
		if (_sessionStartUtc == null) return;
		final elapsed = nowUtc.difference(_sessionStartUtc!);
		if (elapsed.isNegative || elapsed == Duration.zero) return;
		final maxElapsed = Duration(seconds: _plannedDurationSeconds);
		setState(() {
			_totalFocusSpent += elapsed > maxElapsed ? maxElapsed : elapsed;
			_sessionStartUtc = nowUtc;
		});
	}


	Future<void> _openSettings() async {
		final focusController = TextEditingController(text: _focusDuration.inMinutes.toString());
		final shortController = TextEditingController(text: _shortBreakDuration.inMinutes.toString());
		final longController = TextEditingController(text: _longBreakDuration.inMinutes.toString());
		final sessionsController = TextEditingController(text: _totalSessions.toString());
		var autoStart = _autoStartNext;
		var focusMinutes = _focusDuration.inMinutes;
		var shortMinutes = _shortBreakDuration.inMinutes;
		var longMinutes = _longBreakDuration.inMinutes;

		final result = await showModalBottomSheet<bool>(
			context: context,
			isScrollControlled: true,
			showDragHandle: true,
			builder: (context) {
				return StatefulBuilder(
					builder: (context, setModalState) {
						return Padding(
							padding: EdgeInsets.only(
								left: 20,
								right: 20,
								top: 8,
								bottom: MediaQuery.of(context).viewInsets.bottom + 20,
							),
							child: Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										'Pomodoro settings',
										style: Theme.of(context).textTheme.titleLarge,
									),
									const SizedBox(height: 16),
									_buildDurationControl(
										context,
										label: 'Custom focus duration (minutes)',
										min: 5,
										max: 60,
										value: focusMinutes,
										controller: focusController,
										onChanged: (v) => setModalState(() => focusMinutes = v),
									),
									const SizedBox(height: 12),
									_buildDurationControl(
										context,
										label: 'Custom short break duration (minutes)',
										min: 1,
										max: 20,
										value: shortMinutes,
										controller: shortController,
										onChanged: (v) => setModalState(() => shortMinutes = v),
									),
									const SizedBox(height: 12),
									_buildDurationControl(
										context,
										label: 'Custom long break duration (minutes)',
										min: 5,
										max: 30,
										value: longMinutes,
										controller: longController,
										onChanged: (v) => setModalState(() => longMinutes = v),
									),
									const SizedBox(height: 12),
									TextField(
										controller: sessionsController,
										keyboardType: TextInputType.number,
										decoration: const InputDecoration(
											labelText: 'Sessions per cycle',
										),
									),
									const SizedBox(height: 12),
									SwitchListTile(
										contentPadding: EdgeInsets.zero,
										value: autoStart,
										onChanged: (v) => setModalState(() => autoStart = v),
										title: const Text('Auto-start next session'),
									),
									const SizedBox(height: 16),
									Row(
										children: [
											Expanded(
												child: OutlinedButton(
													onPressed: () => Navigator.pop(context, false),
													child: const Text('Cancel'),
												),
											),
											const SizedBox(width: 12),
											Expanded(
												child: FilledButton(
													onPressed: () => Navigator.pop(context, true),
													child: const Text('Save'),
												),
											),
										],
									),
								],
							),
						);
					},
				);
			},
		);

		if (result != true || !mounted) {
			return;
		}

		final parsedFocus = int.tryParse(focusController.text.trim()) ?? focusMinutes;
		final parsedShort = int.tryParse(shortController.text.trim()) ?? shortMinutes;
		final parsedLong = int.tryParse(longController.text.trim()) ?? longMinutes;
		final sessions = int.tryParse(sessionsController.text.trim()) ?? _totalSessions;

		setState(() {
			_focusDuration = Duration(minutes: parsedFocus.clamp(1, 180));
			_shortBreakDuration = Duration(minutes: parsedShort.clamp(1, 60));
			_longBreakDuration = Duration(minutes: parsedLong.clamp(1, 120));
			_totalSessions = sessions.clamp(1, 12);
			_autoStartNext = autoStart;
			_sessionType = _SessionType.focus;
			_sessionIndex = 1;
			_isRunning = false;
			_isSessionActive = false;
			_sessionStartUtc = DateTime.now().toUtc();
			_plannedDurationSeconds = _focusDuration.inSeconds;
			_remaining = _focusDuration;
		});
		_stopUiTimer();
		_stopFocusNotificationUpdates();
		_cancelNotification();
		_persistState();
		_cancelFocusSessionNotification();
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
		setState(() {
			_remaining = remaining;
		});
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
		await _notifService
				.cancelNotification(FocusSessionPrefs.focusNotificationId);
	}

	Future<void> _persistState() async {
		try {
			final box = Hive.box(StorageService.settingsBoxName);
			await box.put(FocusSessionPrefs.sessionTypeKey, _sessionType.name);
			await box.put(FocusSessionPrefs.sessionStartKey,
					(_sessionStartUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch);
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

	Future<void> _loadPersistedState() async {
		try {
			final box = Hive.box(StorageService.settingsBoxName);
			final storedType =
					box.get(FocusSessionPrefs.sessionTypeKey) as String?;
			final storedStart =
					box.get(FocusSessionPrefs.sessionStartKey) as int?;
			final storedPlanned =
					box.get(FocusSessionPrefs.plannedDurationKey) as int?;
			final storedIndex =
					box.get(FocusSessionPrefs.sessionIndexKey) as int?;
			final storedTotal = box.get(_totalSessionsKey) as int?;
			final storedRunning =
					box.get(FocusSessionPrefs.isRunningKey) as bool?;
			final storedActive =
					box.get(FocusSessionPrefs.isActiveKey) as bool?;

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
		} catch (_) {
			// ignore load failures
		}
		if (!mounted) return;
		setState(() {
			_remaining = _computeRemaining(nowUtc: DateTime.now().toUtc());
			_isInitializing = false;
		});
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
				return 'Break time – relax';
			case _SessionType.longBreak:
				return 'Break time – recharge';
		}
	}

	Widget _buildDurationControl(
		BuildContext context, {
		required String label,
		required int min,
		required int max,
		required int value,
		required TextEditingController controller,
		required ValueChanged<int> onChanged,
	}) {
		final clamped = value.clamp(min, max).toDouble();
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text(label, style: Theme.of(context).textTheme.bodyMedium),
				Row(
					children: [
						Expanded(
							child: Slider(
								min: min.toDouble(),
								max: max.toDouble(),
								value: clamped,
								onChanged: (v) {
									final newValue = v.round();
									controller.text = newValue.toString();
									onChanged(newValue);
								},
							),
						),
						SizedBox(
							width: 72,
							child: TextField(
								controller: controller,
								keyboardType: TextInputType.number,
								onChanged: (text) {
									final parsed = int.tryParse(text.trim());
									if (parsed != null) {
										onChanged(parsed);
									}
								},
							),
						),
					],
				),
			],
		);
	}

	Widget _buildAnimatedTime(
		BuildContext context, {
		required String minutes,
		required String seconds,
	}) {
		final scheme = Theme.of(context).colorScheme;
		final style = Theme.of(context).textTheme.displaySmall?.copyWith(
			fontWeight: FontWeight.w700,
			color: scheme.onSurface,
			fontFeatures: const [FontFeature.tabularFigures()],
		);
		return Row(
			mainAxisSize: MainAxisSize.min,
			children: [
				_buildDigit(minutes[0], style, scheme),
				_buildDigit(minutes[1], style, scheme),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 6),
					child: Text(':', style: style),
				),
				_buildDigit(seconds[0], style, scheme),
				_buildDigit(seconds[1], style, scheme),
			],
		);
	}

	Widget _buildDigit(String digit, TextStyle? style, ColorScheme scheme) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
			margin: const EdgeInsets.symmetric(horizontal: 2),
			decoration: BoxDecoration(
				color: scheme.surface,
				borderRadius: BorderRadius.circular(12),
				boxShadow: [
					BoxShadow(
						color: scheme.shadow.withOpacity(0.05),
						blurRadius: 8,
						offset: const Offset(0, 4),
					),
				],
			),
			child: ClipRect(
				child: AnimatedSwitcher(
					duration: const Duration(milliseconds: 500),
					switchInCurve: Curves.easeOutCubic,
					switchOutCurve: Curves.easeInCubic,
					transitionBuilder: (child, animation) {
						final slide = Tween<Offset>(
							begin: const Offset(0, -0.6),
							end: Offset.zero,
						).animate(animation);
						return FadeTransition(
							opacity: animation,
							child: SlideTransition(position: slide, child: child),
						);
					},
					child: Text(
						digit,
						key: ValueKey<String>(digit),
						style: style,
					),
				),
			),
		);
	}

	String _twoDigits(int n) => n.toString().padLeft(2, '0');

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
}

enum _SessionType {
	focus,
	shortBreak,
	longBreak,
}

class FocusedTodayCard extends StatelessWidget {
	final Duration focusedDuration;
	const FocusedTodayCard({Key? key, required this.focusedDuration}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		final textTheme = Theme.of(context).textTheme;
		final totalMinutes = focusedDuration.inMinutes;
		final displayText = totalMinutes < 60
				? '${totalMinutes}m'
				: (focusedDuration.inMinutes / 60).toStringAsFixed(1) + 'h';
		final progress = (totalMinutes / 240).clamp(0, 1);

		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
			decoration: BoxDecoration(
				color: scheme.surface,
				borderRadius: BorderRadius.circular(18),
				boxShadow: [
					BoxShadow(
						color: scheme.shadow.withOpacity(0.06),
						blurRadius: 16,
						offset: const Offset(0, 6),
					),
				],
			),
			child: Row(
				children: [
					Container(
						padding: const EdgeInsets.all(10),
						decoration: BoxDecoration(
							color: scheme.primaryContainer,
							borderRadius: BorderRadius.circular(14),
						),
						child: Icon(
							Icons.hourglass_bottom_rounded,
							color: scheme.onPrimaryContainer,
						),
					),
					const SizedBox(width: 12),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									'Focused Today',
									style: textTheme.titleMedium?.copyWith(
										fontWeight: FontWeight.w600,
									),
								),
								const SizedBox(height: 8),
								Row(
									mainAxisAlignment: MainAxisAlignment.spaceBetween,
									children: [
										Expanded(
											child: ClipRRect(
												borderRadius: BorderRadius.circular(999),
												child: LinearProgressIndicator(
													value: progress.toDouble(),
													minHeight: 6,
													backgroundColor: scheme.surfaceVariant,
													color: scheme.primary,
												),
											),
										),
										const SizedBox(width: 12),
										Text(
											displayText,
											style: textTheme.titleLarge?.copyWith(
												fontWeight: FontWeight.w700,
												color: scheme.onSurface,
											),
										),
									],
								),
							],
						),
					),
				],
			),
		);
	}
}

