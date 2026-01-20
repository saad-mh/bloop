import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

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

class _PomodoroCard extends StatefulWidget {
	const _PomodoroCard();

	@override
	State<_PomodoroCard> createState() => _PomodoroCardState();
}

class _PomodoroCardState extends State<_PomodoroCard> {
	Timer? _timer;
	Duration _focusDuration = const Duration(minutes: 25);
	Duration _shortBreakDuration = const Duration(minutes: 5);
	Duration _longBreakDuration = const Duration(minutes: 15);
	int _totalSessions = 4;
	bool _autoStartNext = true;

	Duration _remaining = const Duration(minutes: 25);
	bool _isRunning = false;
	int _sessionIndex = 1;
	_SessionType _sessionType = _SessionType.focus;

	@override
	void dispose() {
		_timer?.cancel();
		super.dispose();
	}

	void _start() {
		_timer?.cancel();
		setState(() => _isRunning = true);
		_timer = Timer.periodic(const Duration(seconds: 1), (_) {
			if (_remaining.inSeconds <= 1) {
				_timer?.cancel();
				setState(() {
					_remaining = Duration.zero;
					_isRunning = false;
				});
				_handleSessionComplete();
				return;
			}
			setState(() {
				_remaining -= const Duration(seconds: 1);
			});
		});
	}

	void _pause() {
		_timer?.cancel();
		setState(() => _isRunning = false);
	}

	void _reset() {
		_timer?.cancel();
		setState(() {
			_sessionType = _SessionType.focus;
			_remaining = _focusDuration;
			_isRunning = false;
		});
	}

	void _nextSession() {
		setState(() {
			_advanceSession();
			_isRunning = false;
		});
	}

	void _handleSessionComplete() {
		if (!_autoStartNext) {
			setState(() => _advanceSession());
			return;
		}
		setState(() => _advanceSession());
		_start();
	}

	void _advanceSession() {
		if (_sessionType == _SessionType.focus) {
			final isLastFocus = _sessionIndex >= _totalSessions;
			_sessionType = isLastFocus ? _SessionType.longBreak : _SessionType.shortBreak;
			_remaining = isLastFocus ? _longBreakDuration : _shortBreakDuration;
			return;
		}
		if (_sessionType == _SessionType.shortBreak) {
			_sessionIndex = (_sessionIndex % _totalSessions) + 1;
			_sessionType = _SessionType.focus;
			_remaining = _focusDuration;
			return;
		}
		_sessionIndex = 1;
		_sessionType = _SessionType.focus;
		_remaining = _focusDuration;
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
		final scheme = Theme.of(context).colorScheme;
		final textTheme = Theme.of(context).textTheme;
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
								onChanged: (v) => focusMinutes = v,
							),
							const SizedBox(height: 12),
							_buildDurationControl(
								context,
								label: 'Custom short break duration (minutes)',
								min: 1,
								max: 20,
								value: shortMinutes,
								controller: shortController,
								onChanged: (v) => shortMinutes = v,
							),
							const SizedBox(height: 12),
							_buildDurationControl(
								context,
								label: 'Custom long break duration (minutes)',
								min: 5,
								max: 30,
								value: longMinutes,
								controller: longController,
								onChanged: (v) => longMinutes = v,
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
							StatefulBuilder(
								builder: (context, setModalState) {
									return SwitchListTile(
										contentPadding: EdgeInsets.zero,
										value: autoStart,
										onChanged: (v) => setModalState(() => autoStart = v),
										title: const Text('Auto-start next session'),
									);
								},
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

		if (result != true || !mounted) {
			return;
		}

		final focusMinutes = int.tryParse(focusController.text.trim()) ?? focusMinutes;
		final shortMinutes = int.tryParse(shortController.text.trim()) ?? shortMinutes;
		final longMinutes = int.tryParse(longController.text.trim()) ?? longMinutes;
		final sessions = int.tryParse(sessionsController.text.trim()) ?? _totalSessions;

		setState(() {
			_focusDuration = Duration(minutes: focusMinutes.clamp(1, 180));
			_shortBreakDuration = Duration(minutes: shortMinutes.clamp(1, 60));
			_longBreakDuration = Duration(minutes: longMinutes.clamp(1, 120));
			_totalSessions = sessions.clamp(1, 12);
			_autoStartNext = autoStart;
			_sessionType = _SessionType.focus;
			_sessionIndex = 1;
			_remaining = _focusDuration;
			_isRunning = false;
		});
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
		return StatefulBuilder(
			builder: (context, setModalState) {
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
											setModalState(() => onChanged(newValue));
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
												setModalState(() => onChanged(parsed));
											}
										},
									),
								),
							],
						),
					],
				);
			},
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
}

enum _SessionType {
	focus,
	shortBreak,
	longBreak,
}

