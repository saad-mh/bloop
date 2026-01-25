import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';
import 'package:slide_to_act/slide_to_act.dart';

import 'focus_controller.dart';
import '../../models/scenery_config.dart';

class PomodoroCard extends ConsumerStatefulWidget {
	const PomodoroCard({super.key});

	@override
	ConsumerState<PomodoroCard> createState() => _PomodoroCardState();
}

class _PomodoroCardState extends ConsumerState<PomodoroCard> {
	Timer? _controlsTimer;
	bool _controlsVisible = false;
	bool _isInteracting = false;
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
		if (_controlsVisible && !_isInteracting) {
			_controlsTimer = Timer(_autoHideDuration, () {
				if (!mounted) return;
				setState(() {
					_controlsVisible = false;
				});
			});
		}
	}

	void _startInteraction() {
		if (!_controlsVisible) return;
		_controlsTimer?.cancel();
		if (!_isInteracting) {
			setState(() => _isInteracting = true);
		}
	}

	void _endInteraction() {
		if (_isInteracting) {
			setState(() => _isInteracting = false);
		}
		_armAutoHide();
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
												'Tap to show controls • Swipe left for settings',
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
										controlsVisible: _controlsVisible,
										onInteractionStart: _startInteraction,
										onInteractionEnd: _endInteraction,
										onPauseResume: () {
											_startInteraction();
											_showControls();
											controller.isRunning
												? controller.pause()
												: controller.start();
											_endInteraction();
										},
										onSlideEnd: () {
											_startInteraction();
											_showControls();
											_confirmActionSheet(
												context,
												title: 'End this focus session?',
												description:
													'Your current focus session will be stopped.',
												confirmLabel: 'End session',
											).then((shouldEnd) {
												if (shouldEnd) {
													controller.reset();
												}
												_endInteraction();
											});
										},
										onSkipRequested: () async {
											_startInteraction();
											final shouldSkip = await _confirmActionSheet(
												context,
												title: 'Skip this session?',
												description:
													'You will move to the next session immediately.',
												confirmLabel: 'Skip session',
											);
											if (shouldSkip) {
												controller.nextSession();
											}
											_endInteraction();
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

	Future<bool> _confirmActionSheet(
		BuildContext context, {
		required String title,
		required String description,
		required String confirmLabel,
	}) async {
		final scheme = Theme.of(context).colorScheme;
		final textTheme = Theme.of(context).textTheme;
		final result = await showModalBottomSheet<bool>(
			context: context,
			isScrollControlled: true,
			showDragHandle: true,
			backgroundColor: scheme.surface,
			shape: const RoundedRectangleBorder(
				borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
			),
			builder: (context) {
				return SafeArea(
					child: SizedBox(
						height: 220,
						child: Padding(
							padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										title,
										style: textTheme.titleLarge?.copyWith(
											fontWeight: FontWeight.w600,
										),
									),
									const SizedBox(height: 8),
									Text(
										description,
										style: textTheme.bodyMedium?.copyWith(
											color: scheme.onSurfaceVariant,
										),
									),
									const SizedBox(height: 20),
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
													style: FilledButton.styleFrom(
														backgroundColor: scheme.error,
														foregroundColor: scheme.onError,
													),
													child: Text(confirmLabel),
												),
											),
										],
									),
								],
							),
						),
					),
				);
			},
		);
		return result ?? false;
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
		var dimScreen = controller.dimScreenEnabled;
		var soundsEnabled = controller.soundsEnabled;
		var sceneryEnabled = controller.sceneryEnabled;
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
			dimScreenEnabled: dimScreen,
			soundsEnabled: soundsEnabled,
			sceneryEnabled: sceneryEnabled,
		);
		_armAutoHide();
	}

	Future<void> _openSoundPicker(
		BuildContext context,
		FocusController controller,
	) async {
		_controlsTimer?.cancel();
		final options = focusSoundAssets;
		var selected = controller.selectedSound;
		await showModalBottomSheet<void>(
			context: context,
			showDragHandle: true,
			builder: (context) {
					final maxHeight = MediaQuery.of(context).size.height * 0.6;
					return SafeArea(
						child: SizedBox(
							height: maxHeight,
							child: Padding(
								padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											'Change sound',
											style: Theme.of(context).textTheme.titleMedium,
										),
										const SizedBox(height: 8),
										Expanded(
											child: ListView(
												children: options.entries
													.map(
														(entry) => RadioListTile<String>(
															value: entry.key,
															groupValue: selected,
															title: Text(entry.key),
															onChanged: (value) {
																selected = value ?? selected;
																Navigator.pop(context);
															},
														),
													)
													.toList(growable: false),
											),
										),
									],
								),
							),
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
					final maxHeight = MediaQuery.of(context).size.height * 0.6;
					return SafeArea(
						child: SizedBox(
							height: maxHeight,
							child: Padding(
								padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											'Change scenery',
											style: Theme.of(context).textTheme.titleMedium,
										),
										const SizedBox(height: 8),
										Expanded(
											child: ListView(
												children: options
													.map(
														(option) => RadioListTile<String>(
															value: option,
															groupValue: selected,
															title: Text(option),
															onChanged: (value) {
																selected = value ?? selected;
																Navigator.pop(context);
															},
														),
													)
													.toList(growable: false),
											),
										),
									],
								),
							),
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
		required this.controlsVisible,
		required this.onInteractionStart,
		required this.onInteractionEnd,
		required this.onPauseResume,
		required this.onSlideEnd,
		required this.onSkipRequested,
		required this.onInteract,
	});

	final bool isRunning;
	final String selectedSound;
	final String selectedScenery;
	final bool controlsVisible;
	final VoidCallback onInteractionStart;
	final VoidCallback onInteractionEnd;
	final VoidCallback onPauseResume;
	final VoidCallback onSlideEnd;
	final VoidCallback onSkipRequested;
	final VoidCallback onInteract;

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		final textTheme = Theme.of(context).textTheme;
		return Listener(
			onPointerDown: (_) => onInteractionStart(),
			onPointerUp: (_) => onInteractionEnd(),
			onPointerCancel: (_) => onInteractionEnd(),
			child: Container(
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
						Center(
							child: FilledButton(
								onPressed: onPauseResume,
								style: FilledButton.styleFrom(
									minimumSize: const Size(180, 48),
								),
								child: Text(isRunning ? 'Pause' : 'Resume'),
							),
						),
						const SizedBox(height: 14),
						SizedBox(
							width: double.infinity,
							child: SlideToEndControl(
								label: 'Slide to End Focus Session',
								onCompleted: onSlideEnd,
								onInteract: onInteract,
								// destructive: true,
							),
						),
						const SizedBox(height: 12),
						AnimatedOpacity(
							opacity: controlsVisible ? 1 : 0,
							duration: const Duration(milliseconds: 160),
							curve: Curves.easeOut,
							child: Column(
								children: [
									LongSwipeSkipControl(
										label: 'Long swipe to skip session',
										onArmed: onSkipRequested,
										onInteract: onInteract,
									mutedStyle: true,
									),
								const SizedBox(height: 10),
								AnimatedOpacity(
									opacity: controlsVisible ? 1 : 0,
									duration: const Duration(milliseconds: 120),
									curve: Curves.easeOut,
									child: Row(
									  mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
										children: [
											// Icon(
											// 	Icons.music_note_rounded,
											// 	size: 16,
											// 	color: scheme.onSurfaceVariant,
											// ),
											const SizedBox(width: 6),
											Expanded(
												child: Text(
													'🎧 ${selectedSound} • 🌄 ${selectedScenery}',
													style: textTheme.bodySmall?.copyWith(
														color: scheme.onSurfaceVariant,
													),
												  softWrap: true,
												  textAlign: .center,
												),
											),
										],
									),
								),
							],
						),
					),
				],
			),
		),
		);
	}
}

class SlideToEndControl extends StatelessWidget {
	const SlideToEndControl({
		required this.label,
		required this.onCompleted,
		required this.onInteract,
		this.destructive = false,
		super.key,
	});

	final String label;
	final VoidCallback onCompleted;
	final VoidCallback onInteract;
	final bool destructive;

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		return SlideAction(
			onSubmit: () async {
				onInteract();
				onCompleted();
			},
			height: 48,
			text: label,
			textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
				color: scheme.onSurfaceVariant,
				fontWeight: FontWeight.w600,
			),
			outerColor: scheme.surfaceVariant,
			innerColor: scheme.surface,
			elevation: 0,
			borderRadius: 999,
			sliderButtonIconPadding: 1,
			sliderButtonIcon: Icon(
				Icons.chevron_right_rounded,
				color: scheme.onSurface,
				size: 32,
			),
			sliderRotate: false,
		);
	}
}

class LongSwipeSkipControl extends StatelessWidget {
	const LongSwipeSkipControl({
		required this.label,
		required this.onArmed,
		required this.onInteract,
		this.mutedStyle = false,
		super.key,
	});

	final String label;
	final VoidCallback onArmed;
	final VoidCallback onInteract;
	final bool mutedStyle;

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		return SlideAction(
			onSubmit: () async {
				onInteract();
				onArmed();
			},
			height: 48,
			text: label,
			textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
				color: scheme.onSurfaceVariant,
				fontWeight: FontWeight.w600,
			),
			outerColor: scheme.surfaceVariant,
			innerColor: scheme.surface,
			elevation: 0,
			borderRadius: 999,
			sliderButtonIconPadding: 1,
			sliderButtonIcon: Icon(
				Icons.fast_forward_rounded,
				color: scheme.onSurface,
				size: 32,
			),
			sliderRotate: false,
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
		final config = _sceneryConfigs[sceneryKey] ?? _sceneryConfigs.values.first;
		if (!enabled) {
			return Container(
				decoration: BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topLeft,
						end: Alignment.bottomRight,
						colors: [scheme.surface, scheme.surfaceVariant],
					),
				),
			);
		}
		switch (config.type) {
			case SceneryType.gradient:
				final colors = config.colors ?? [scheme.surface, scheme.surfaceVariant];
				return Container(
					decoration: BoxDecoration(
						gradient: LinearGradient(
							begin: Alignment.topLeft,
							end: Alignment.bottomRight,
							colors: colors,
						),
					),
				);
			case SceneryType.image:
				final assetPath = config.assetPath;
				if (assetPath == null || assetPath.isEmpty) {
					return Container(color: scheme.surface);
				}
				return Stack(
					fit: StackFit.expand,
					children: [
						Image.asset(
							assetPath,
							fit: BoxFit.cover,
						),
					],
				);
		}
	}
}

const Map<String, SceneryConfig> _sceneryConfigs = {
	'Aurora': SceneryConfig.gradient(
		colors: [Color(0xFF0B3D91), Color(0xFF2E9CCA), Color(0xFF62E8B0)],
	),
	'Moonlight': SceneryConfig.gradient(
		colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
	),
	'Lagoon': SceneryConfig.gradient(
		colors: [Color(0xFF005C97), Color(0xFF363795), Color(0xFF00BF8F)],
	),
	'Sunrise': SceneryConfig.gradient(
		colors: [Color(0xFFFF512F), Color(0xFFDD2476), Color(0xFFFFC371)],
	),
	'Forest Path': SceneryConfig.image(
		assetPath: 'assets/scenery/forest_1.jpg',
	),
	'Evergreen': SceneryConfig.image(
		assetPath: 'assets/scenery/forest_2.jpg',
	),
	'Quiet Library': SceneryConfig.image(
		assetPath: 'assets/scenery/library_1.jpg',
	),
	'Blue Ridge': SceneryConfig.image(
		assetPath: 'assets/scenery/mountain_1.jpg',
	),
	'Alpine Glow': SceneryConfig.image(
		assetPath: 'assets/scenery/mountain_2.jpg',
	),
};

final List<String> _sceneryOptions = _sceneryConfigs.keys.toList(growable: false);

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
