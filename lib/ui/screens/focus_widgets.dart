import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';

import 'focus_controller.dart';

class PomodoroCard extends ConsumerStatefulWidget {
	const PomodoroCard({super.key});

	@override
	ConsumerState<PomodoroCard> createState() => _PomodoroCardState();
}

class _PomodoroCardState extends ConsumerState<PomodoroCard> {
	Timer? _controlsTimer;
	bool _controlsVisible = false;
	bool _confirmSkip = false;
	ProviderSubscription<FocusController>? _focusSub;

	static const Duration _autoHideDuration = Duration(seconds: 4);

	@override
	void initState() {
		super.initState();
		_focusSub = ref.listenManual(focusControllerProvider, (previous, next) {
			final wasActive = previous?.isSessionActive ?? false;
			if (!wasActive && next.isSessionActive) {
				if (mounted) {
					setState(() {
						_controlsVisible = false;
						_confirmSkip = false;
					});
				}
			}
		});
	}

	@override
	void dispose() {
		_controlsTimer?.cancel();
		_focusSub?.close();
		super.dispose();
	}

	void _toggleControls() {
		setState(() {
			_controlsVisible = !_controlsVisible;
			if (!_controlsVisible) {
				_confirmSkip = false;
			}
		});
		_armAutoHide();
	}

	void _showControls() {
		if (!_controlsVisible) {
			setState(() => _controlsVisible = true);
		}
		_armAutoHide();
	}

	void _armAutoHide() {
		_controlsTimer?.cancel();
		if (_controlsVisible) {
			_controlsTimer = Timer(_autoHideDuration, () {
				if (!mounted) return;
				setState(() {
					_controlsVisible = false;
					_confirmSkip = false;
				});
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		final controller = ref.watch(focusControllerProvider);
		final scheme = Theme.of(context).colorScheme;
		final textTheme = Theme.of(context).textTheme;
		if (controller.isInitializing) {
			return const Padding(
				padding: EdgeInsets.all(24),
				child: Center(child: CircularProgressIndicator()),
			);
		}
		final minutes = _twoDigits(controller.remaining.inMinutes.remainder(60));
		final seconds = _twoDigits(controller.remaining.inSeconds.remainder(60));
		final isFullScreen = controller.isFullScreenActive;

		if (!isFullScreen) {
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
											controller.sessionLabel,
											style: textTheme.titleLarge?.copyWith(
												fontWeight: FontWeight.w600,
											),
										),
										const Spacer(),
										IconButton(
											tooltip: 'Edit pomodoro',
											icon: const Icon(Icons.settings),
											onPressed: () => _openSettings(context, ref),
										),
									],
								),
								const SizedBox(height: 20),
								_buildTimerDial(
									context,
									minutes: minutes,
									seconds: seconds,
									size: 190,
								),
								const SizedBox(height: 16),
								Text(
									controller.focusHintText,
									style: textTheme.bodyMedium?.copyWith(
										color: scheme.onSurfaceVariant,
									),
								),
								const SizedBox(height: 20),
								Row(
									children: [
										Expanded(
											child: FilledButton(
												onPressed: () {
													_showControls();
													controller.isRunning
														? controller.pause()
														: controller.start();
												},
											child: Text(controller.isRunning ? 'Pause' : 'Start'),
										),
									),
									const SizedBox(width: 12),
									Expanded(
										child: OutlinedButton(
											onPressed: () {
												_showControls();
												controller.reset();
											},
											child: const Text('Reset'),
										),
									),
								],
							),
							const SizedBox(height: 16),
							FocusedTodayCard(
								focusedDuration: controller.totalFocusSpent,
							),
						],
						),
					),
				),
			);
		}

		return GestureDetector(
			behavior: HitTestBehavior.opaque,
			onTap: _toggleControls,
			onHorizontalDragEnd: (details) {
				if (details.primaryVelocity != null &&
					details.primaryVelocity! < -600) {
					_openSessionSettings(context, controller);
					_showControls();
				}
			},
			child: Stack(
				fit: StackFit.expand,
				children: [
					_FocusSceneryBackground(
						scheme: scheme,
						sceneryKey: controller.selectedScenery,
						enabled: controller.sceneryEnabled,
					),
					if (controller.dimScreenEnabled)
						AnimatedOpacity(
							opacity: 0.6,
							duration: const Duration(milliseconds: 400),
							child: Container(color: Colors.black),
						),
					Padding(
						padding: EdgeInsets.zero,
						child: Column(
							children: [
								const SizedBox(height: 4),
								Padding(
								  padding: const EdgeInsets.fromLTRB(0, 32, 0, 8),
								  child: Text(
								  	controller.sessionLabel,
								  	style: textTheme.titleLarge?.copyWith(
								  		fontWeight: FontWeight.w700,
								  		color: scheme.onSurface,
								  	),
								  ),
								),
								Text(
									'Session ${controller.sessionIndex}/${controller.totalSessions}',
									style: textTheme.bodyMedium?.copyWith(
										color: scheme.onSurfaceVariant,
									),
								),
								const Spacer(),
								_buildTimerDial(
									context,
									minutes: minutes,
									seconds: seconds,
									size: 230,
								),
								const SizedBox(height: 16),
								Padding(
									padding: const EdgeInsets.symmetric(horizontal: 24),
									child: Text(
										controller.focusHintText,
										textAlign: TextAlign.center,
										style: textTheme.bodyLarge?.copyWith(
											color: scheme.onSurfaceVariant,
										),
									),
								),
								const Spacer(),
								Padding(
									padding: const EdgeInsets.only(bottom: 28),
									child: AnimatedOpacity(
										opacity: _controlsVisible ? 0 : 1,
										duration: const Duration(milliseconds: 220),
										curve: Curves.easeOut,
										child: AnimatedSlide(
											offset:
												_controlsVisible ? const Offset(0, 0.08) : Offset.zero,
											duration: const Duration(milliseconds: 220),
											curve: Curves.easeOut,
											child: Text(
												'Tap to show controls',
												style: textTheme.bodySmall?.copyWith(
													color: scheme.onSurfaceVariant,
												),
											),
										),
									),
                ),
							],
						),
					),
					Positioned(
						top: 32,
						right: 12,
						child: IgnorePointer(
							ignoring: !_controlsVisible,
							child: AnimatedOpacity(
								opacity: _controlsVisible ? 1 : 0,
								duration: const Duration(milliseconds: 220),
								curve: Curves.easeOut,
								child: AnimatedSlide(
									offset:
										_controlsVisible ? Offset.zero : const Offset(0, -0.08),
									duration: const Duration(milliseconds: 220),
									curve: Curves.easeOut,
									child: Column(
									  spacing: 4,
										children: [
											_QuickActionIcon(
												icon: CupertinoIcons.music_note,
												label: 'Sound',
												isEnabled: controller.soundsEnabled,
												onTap: () {
													_showControls();
													_openSoundPicker(context, controller);
												},
											),
											const SizedBox(width: 8),
											_QuickActionIcon(
												icon: CupertinoIcons.cloud,
												label: 'Scenery',
												isEnabled: controller.sceneryEnabled,
												onTap: () {
													_showControls();
													_openSceneryPicker(context, controller);
												},
											),
										],
									),
								),
							),
						),
					),
					Positioned(
						left: 20,
						right: 20,
						bottom: 24,
						child: IgnorePointer(
							ignoring: !_controlsVisible,
							child: AnimatedOpacity(
								opacity: _controlsVisible ? 1 : 0,
								duration: const Duration(milliseconds: 240),
								curve: Curves.easeOut,
								child: AnimatedSlide(
									offset:
										_controlsVisible ? Offset.zero : const Offset(0, 0.08),
									duration: const Duration(milliseconds: 240),
									curve: Curves.easeOut,
									child: _FocusControlsPanel(
										isRunning: controller.isRunning,
										selectedSound: controller.selectedSound,
										selectedScenery: controller.selectedScenery,
										onPauseResume: () {
											_showControls();
											controller.isRunning
												? controller.pause()
												: controller.start();
										},
										onSlideEnd: () {
											_showControls();
											controller.reset();
										},
										showConfirmSkip: _confirmSkip,
										onSkipArmed: () => setState(() => _confirmSkip = true),
										onSkipCancel: () => setState(() => _confirmSkip = false),
										onSkipConfirm: () {
											setState(() => _confirmSkip = false);
											controller.nextSession();
										},
										onInteract: _showControls,
									),
								),
							),
						),
					),
				],
			),
		);
	}

	Future<void> _openSettings(BuildContext context, WidgetRef ref) async {
		final controller = ref.read(focusControllerProvider);
		final focusController = TextEditingController(
			text: controller.focusDuration.inMinutes.toString(),
		);
		final shortController = TextEditingController(
			text: controller.shortBreakDuration.inMinutes.toString(),
		);
		final longController = TextEditingController(
			text: controller.longBreakDuration.inMinutes.toString(),
		);
		final sessionsController =
				TextEditingController(text: controller.totalSessions.toString());
		var autoStart = controller.autoStartNext;
		var focusMinutes = controller.focusDuration.inMinutes;
		var shortMinutes = controller.shortBreakDuration.inMinutes;
		var longMinutes = controller.longBreakDuration.inMinutes;

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
								crossAxisAlignment: CrossAxisAlignment.center,
								children: [
									Text(
										'Pomodoro settings',
										style: Theme.of(context).textTheme.titleLarge,
									),
									const SizedBox(height: 16),
									_buildDurationControl(
										context,
										label: 'Custom focus duration (mins)',
										min: 5,
										max: 60,
										value: focusMinutes,
										controller: focusController,
										onChanged: (v) => setModalState(() => focusMinutes = v),
									),
									const SizedBox(height: 12),
									_buildDurationControl(
										context,
										label: 'Custom short break duration (mins)',
										min: 1,
										max: 20,
										value: shortMinutes,
										controller: shortController,
										onChanged: (v) => setModalState(() => shortMinutes = v),
									),
									const SizedBox(height: 12),
									_buildDurationControl(
										context,
										label: 'Custom long break duration (mins)',
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
										decoration: InputDecoration(
											border: OutlineInputBorder(
												borderRadius: BorderRadius.circular(8),
											),
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

		if (result != true) {
			return;
		}

		final parsedFocus = int.tryParse(focusController.text.trim()) ?? focusMinutes;
		final parsedShort = int.tryParse(shortController.text.trim()) ?? shortMinutes;
		final parsedLong = int.tryParse(longController.text.trim()) ?? longMinutes;
		final sessions =
				int.tryParse(sessionsController.text.trim()) ?? controller.totalSessions;

		controller.applySettings(
			focusMinutes: parsedFocus,
			shortMinutes: parsedShort,
			longMinutes: parsedLong,
			totalSessions: sessions,
			autoStartNext: autoStart,
		);
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
								year2023: false,
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

	Widget _buildTimerDial(
		BuildContext context, {
		required String minutes,
		required String seconds,
		required double size,
	}) {
		final controller = ref.read(focusControllerProvider);
		final scheme = Theme.of(context).colorScheme;
		return TweenAnimationBuilder<double>(
			duration: const Duration(milliseconds: 500),
			tween: Tween(begin: 0, end: controller.progress.clamp(0, 1)),
			builder: (context, value, child) {
				return Stack(
					alignment: Alignment.center,
					children: [
						SizedBox(
							width: size,
							height: size,
							child: CircularProgressIndicator(
								value: value,
								strokeWidth: size > 200 ? 12 : 10,
								color: scheme.primary,
								backgroundColor: scheme.surfaceVariant,
								year2023: false,
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

	Future<void> _openSessionSettings(
		BuildContext context,
		FocusController controller,
	) async {
		_controlsTimer?.cancel();
		var fullScreen = controller.fullScreenEnabled;
		var appPinning = controller.appPinningEnabled;
		var dimScreen = controller.dimScreenEnabled;
		var soundsEnabled = controller.soundsEnabled;
		var sceneryEnabled = controller.sceneryEnabled;
		var allowOverrides = controller.allowOverrides;
		await showModalBottomSheet<void>(
			context: context,
			showDragHandle: true,
			isScrollControlled: true,
			builder: (context) {
				return StatefulBuilder(
					builder: (context, setModalState) {
						return Padding(
							padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
							child: Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										'Focus session settings',
										style: Theme.of(context).textTheme.titleLarge,
									),
									const SizedBox(height: 12),
									SwitchListTile(
										contentPadding: EdgeInsets.zero,
										value: fullScreen,
										title: const Text('Full-screen focus mode'),
										onChanged: (v) => setModalState(() => fullScreen = v),
									),
									SwitchListTile(
										contentPadding: EdgeInsets.zero,
										value: appPinning,
										title: const Text('App pinning'),
										onChanged: (v) => setModalState(() => appPinning = v),
									),
									SwitchListTile(
										contentPadding: EdgeInsets.zero,
										value: dimScreen,
										title: const Text('Dim screen during focus'),
										onChanged: (v) => setModalState(() => dimScreen = v),
									),
									SwitchListTile(
										contentPadding: EdgeInsets.zero,
										value: soundsEnabled,
										title: const Text('Sounds on'),
										onChanged: (v) => setModalState(() => soundsEnabled = v),
									),
									SwitchListTile(
										contentPadding: EdgeInsets.zero,
										value: sceneryEnabled,
										title: const Text('Scenery on'),
										onChanged: (v) => setModalState(() => sceneryEnabled = v),
									),
									SwitchListTile(
										contentPadding: EdgeInsets.zero,
										value: allowOverrides,
										title: const Text('Allow overrides during focus'),
										onChanged: (v) => setModalState(() => allowOverrides = v),
									),
									const SizedBox(height: 12),
									Row(
										children: [
											Expanded(
												child: OutlinedButton(
													onPressed: () => Navigator.pop(context),
													child: const Text('Close'),
												),
											),
											const SizedBox(width: 12),
											Expanded(
												child: FilledButton(
													onPressed: () => Navigator.pop(context),
													child: const Text('Apply'),
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
		controller.updateSessionPreferences(
			fullScreenEnabled: fullScreen,
			appPinningEnabled: appPinning,
			dimScreenEnabled: dimScreen,
			soundsEnabled: soundsEnabled,
			sceneryEnabled: sceneryEnabled,
			allowOverrides: allowOverrides,
		);
		_armAutoHide();
	}

	Future<void> _openSoundPicker(
		BuildContext context,
		FocusController controller,
	) async {
		_controlsTimer?.cancel();
		final options = _soundOptions;
		var selected = controller.selectedSound;
		await showModalBottomSheet<void>(
			context: context,
			showDragHandle: true,
			builder: (context) {
				return Padding(
					padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Text(
								'Change sound',
								style: Theme.of(context).textTheme.titleMedium,
							),
							const SizedBox(height: 8),
							...options.map(
								(option) => RadioListTile<String>(
									value: option,
									groupValue: selected,
									title: Text(option),
									onChanged: (value) {
										selected = value ?? selected;
										Navigator.pop(context);
									},
								),
							),
						],
					),
				);
			},
		);
		controller.setSelectedSound(selected);
		_armAutoHide();
	}

	Future<void> _openSceneryPicker(
		BuildContext context,
		FocusController controller,
	) async {
		_controlsTimer?.cancel();
		final options = _sceneryOptions;
		var selected = controller.selectedScenery;
		await showModalBottomSheet<void>(
			context: context,
			showDragHandle: true,
			builder: (context) {
				return Padding(
					padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Text(
								'Change scenery',
								style: Theme.of(context).textTheme.titleMedium,
							),
							const SizedBox(height: 8),
							...options.map(
								(option) => RadioListTile<String>(
									value: option,
									groupValue: selected,
									title: Text(option),
									onChanged: (value) {
										selected = value ?? selected;
										Navigator.pop(context);
									},
								),
							),
						],
					),
				);
			},
		);
		controller.setSelectedScenery(selected);
		_armAutoHide();
	}
}

class _FocusControlsPanel extends StatelessWidget {
	const _FocusControlsPanel({
		required this.isRunning,
		required this.selectedSound,
		required this.selectedScenery,
		required this.onPauseResume,
		required this.onSlideEnd,
		required this.onSkipArmed,
		required this.onSkipCancel,
		required this.onSkipConfirm,
		required this.showConfirmSkip,
		required this.onInteract,
	});

	final bool isRunning;
	final String selectedSound;
	final String selectedScenery;
	final VoidCallback onPauseResume;
	final VoidCallback onSlideEnd;
	final VoidCallback onSkipArmed;
	final VoidCallback onSkipCancel;
	final VoidCallback onSkipConfirm;
	final bool showConfirmSkip;
	final VoidCallback onInteract;

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		final textTheme = Theme.of(context).textTheme;
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
			decoration: BoxDecoration(
				color: scheme.surface.withOpacity(0.9),
				borderRadius: BorderRadius.circular(24),
				boxShadow: [
					BoxShadow(
						color: scheme.shadow.withOpacity(0.2),
						blurRadius: 24,
						offset: const Offset(0, 12),
					),
				],
			),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Row(
						children: [
							Expanded(
								child: FilledButton(
									onPressed: onPauseResume,
									child: Text(isRunning ? 'Pause' : 'Resume'),
								),
							),
							const SizedBox(width: 12),
							Expanded(
								child: SlideToEndControl(
									label: 'Slide to end focus',
									onCompleted: onSlideEnd,
									onInteract: onInteract,
								),
							),
						],
					),
					const SizedBox(height: 12),
					LongSwipeSkipControl(
						label: showConfirmSkip
							? 'Release confirmed - tap to skip'
							: 'Long swipe to skip session',
						showConfirm: showConfirmSkip,
						onArmed: onSkipArmed,
						onCancel: onSkipCancel,
						onConfirm: onSkipConfirm,
						onInteract: onInteract,
					),
					const SizedBox(height: 10),
					Row(
						children: [
							Icon(Icons.music_note_rounded, size: 16, color: scheme.primary),
							const SizedBox(width: 6),
							Expanded(
								child: Text(
									'${selectedSound} • ${selectedScenery}',
									style: textTheme.bodySmall?.copyWith(
										color: scheme.onSurfaceVariant,
									),
								),
							),
						],
					),
				],
			),
		);
	}
}

class SlideToEndControl extends StatefulWidget {
	const SlideToEndControl({
		required this.label,
		required this.onCompleted,
		required this.onInteract,
		super.key,
	});

	final String label;
	final VoidCallback onCompleted;
	final VoidCallback onInteract;

	@override
	State<SlideToEndControl> createState() => _SlideToEndControlState();
}

class _SlideToEndControlState extends State<SlideToEndControl> {
	double _progress = 0;

	void _updateProgress(Offset localPosition, double width) {
		final thumbSize = 36.0;
		final max = (width - thumbSize).clamp(1, width);
		final next = (localPosition.dx - thumbSize / 2).clamp(0, max) / max;
		setState(() => _progress = next);
		widget.onInteract();
	}

	void _reset() {
		setState(() => _progress = 0);
	}

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		return LayoutBuilder(
			builder: (context, constraints) {
				final width = constraints.maxWidth;
				return GestureDetector(
					onHorizontalDragUpdate: (details) =>
						_updateProgress(details.localPosition, width),
					onHorizontalDragEnd: (_) {
						if (_progress >= 0.98) {
							HapticFeedback.mediumImpact();
							widget.onCompleted();
						}
						_reset();
					},
					child: Container(
						height: 48,
						decoration: BoxDecoration(
							color: scheme.surfaceVariant,
							borderRadius: BorderRadius.circular(999),
						),
						child: Stack(
							alignment: Alignment.centerLeft,
							children: [
								AnimatedContainer(
									duration: const Duration(milliseconds: 150),
									width: (width * _progress).clamp(36, width),
									height: 48,
									decoration: BoxDecoration(
										color: scheme.primaryContainer,
										borderRadius: BorderRadius.circular(999),
									),
								),
								Center(
									child: Text(
										widget.label,
										style: Theme.of(context).textTheme.labelLarge?.copyWith(
											color: scheme.onSurface,
										),
									),
								),
								Positioned(
									left: (width - 36) * _progress,
									child: Container(
										width: 36,
										height: 36,
										margin: const EdgeInsets.all(6),
										decoration: BoxDecoration(
											color: scheme.primary,
											shape: BoxShape.circle,
										),
										child: Icon(
											Icons.chevron_right_rounded,
											color: scheme.onPrimary,
										),
									),
								),
							],
						),
					),
				);
			},
		);
	}
}

class LongSwipeSkipControl extends StatefulWidget {
	const LongSwipeSkipControl({
		required this.label,
		required this.showConfirm,
		required this.onArmed,
		required this.onCancel,
		required this.onConfirm,
		required this.onInteract,
		super.key,
	});

	final String label;
	final bool showConfirm;
	final VoidCallback onArmed;
	final VoidCallback onCancel;
	final VoidCallback onConfirm;
	final VoidCallback onInteract;

	@override
	State<LongSwipeSkipControl> createState() => _LongSwipeSkipControlState();
}

class _LongSwipeSkipControlState extends State<LongSwipeSkipControl> {
	double _progress = 0;
	bool _armed = false;

	void _updateProgress(Offset localPosition, double width) {
		final thumbSize = 30.0;
		final max = (width - thumbSize).clamp(1, width);
		final next = (localPosition.dx - thumbSize / 2).clamp(0, max) / max;
		setState(() => _progress = next);
		if (next >= 0.9 && !_armed) {
			_armed = true;
			HapticFeedback.mediumImpact();
			widget.onArmed();
		}
		widget.onInteract();
	}

	void _reset() {
		setState(() {
			_progress = 0;
			_armed = false;
		});
	}

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		return LayoutBuilder(
			builder: (context, constraints) {
				final width = constraints.maxWidth;
				if (widget.showConfirm) {
					return Container(
						padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
						decoration: BoxDecoration(
							color: scheme.errorContainer.withOpacity(0.9),
							borderRadius: BorderRadius.circular(16),
						),
						child: Row(
							children: [
								Expanded(
									child: Text(
										'Confirm skip?',
										style: Theme.of(context).textTheme.bodyMedium?.copyWith(
											color: scheme.onErrorContainer,
											fontWeight: FontWeight.w600,
										),
									),
								),
								TextButton(
									onPressed: () {
									widget.onCancel();
								},
									child: const Text('Cancel'),
								),
								const SizedBox(width: 8),
								FilledButton(
									onPressed: () {
									widget.onConfirm();
								},
									style: FilledButton.styleFrom(
										backgroundColor: scheme.error,
									),
									child: const Text('Skip'),
								),
							],
						),
					);
				}

				return GestureDetector(
					onHorizontalDragUpdate: (details) =>
						_updateProgress(details.localPosition, width),
					onHorizontalDragEnd: (_) {
						if (_progress >= 0.9) {
							widget.onArmed();
						}
						_reset();
					},
					child: Container(
						height: 44,
						decoration: BoxDecoration(
							color: scheme.surfaceVariant,
							borderRadius: BorderRadius.circular(999),
						),
						child: Stack(
							alignment: Alignment.center,
							children: [
								Center(
									child: Text(
										widget.label,
										style: Theme.of(context).textTheme.labelLarge?.copyWith(
											color: scheme.onSurface,
										),
									),
								),
								Positioned(
									left: (width - 30) * _progress,
									child: Container(
										width: 30,
										height: 30,
										margin: const EdgeInsets.all(7),
										decoration: BoxDecoration(
											color: scheme.error,
											shape: BoxShape.circle,
										),
										child: Icon(
											Icons.fast_forward_rounded,
											color: scheme.onError,
											size: 18,
										),
									),
								),
							],
						),
					),
				);
			},
		);
	}
}

class _QuickActionIcon extends StatelessWidget {
	const _QuickActionIcon({
		required this.icon,
		required this.label,
		required this.onTap,
		required this.isEnabled,
	});

	final IconData icon;
	final String label;
	final VoidCallback onTap;
	final bool isEnabled;

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		return InkWell(
			onTap: onTap,
			borderRadius: BorderRadius.circular(999),
			child: Container(
				padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
				decoration: BoxDecoration(
					color: scheme.surface.withOpacity(0.8),
					borderRadius: BorderRadius.circular(999),
					border: Border.all(
						color: scheme.outlineVariant.withOpacity(0.6),
					),
				),
				child: Row(
					children: [
						Icon(
							icon,
							size: 18,
							color: isEnabled
								? scheme.onSurface
								: scheme.onSurfaceVariant,
						),
						const SizedBox(width: 6),
						Text(
							label,
							style: Theme.of(context).textTheme.labelMedium?.copyWith(
								color: isEnabled
									? scheme.onSurface
									: scheme.onSurfaceVariant,
							),
						),
					],
				),
			),
		);
	}
}

class _FocusSceneryBackground extends StatelessWidget {
	const _FocusSceneryBackground({
		required this.scheme,
		required this.sceneryKey,
		required this.enabled,
	});

	final ColorScheme scheme;
	final String sceneryKey;
	final bool enabled;

	@override
	Widget build(BuildContext context) {
		final gradient = _sceneryGradients[sceneryKey] ?? _sceneryGradients.values.first;
		return Container(
			decoration: BoxDecoration(
				gradient: enabled
					? LinearGradient(
						begin: Alignment.topLeft,
						end: Alignment.bottomRight,
						colors: gradient,
					)
					: LinearGradient(
						begin: Alignment.topLeft,
						end: Alignment.bottomRight,
						colors: [scheme.surface, scheme.surfaceVariant],
					),
			),
		);
	}
}

const List<String> _soundOptions = [
	'Soft Chime',
	'Rain Drop',
	'White Noise',
	'Forest Bell',
];

const List<String> _sceneryOptions = [
	'Aurora',
	'Moonlight',
	'Lagoon',
	'Sunrise',
];

const Map<String, List<Color>> _sceneryGradients = {
	'Aurora': [Color(0xFF0B3D91), Color(0xFF2E9CCA), Color(0xFF62E8B0)],
	'Moonlight': [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
	'Lagoon': [Color(0xFF005C97), Color(0xFF363795), Color(0xFF00BF8F)],
	'Sunrise': [Color(0xFFFF512F), Color(0xFFDD2476), Color(0xFFFFC371)],
};

class FocusedTodayCard extends StatelessWidget {
	final Duration focusedDuration;
	const FocusedTodayCard({super.key, required this.focusedDuration});

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
													year2023: false,
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
