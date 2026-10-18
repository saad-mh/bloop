import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slide_to_act/slide_to_act.dart';

import 'focus_controller.dart';
import '../../models/scenery_config.dart';
import '../theme/tokens.dart';
import '../widgets/bloop_icon_button.dart';
import '../widgets/floating_nav.dart';
import '../widgets/screen_header.dart';

/// Diameter of the timer ring on the focus screen.
const double _kDialSize = 260;

/// Colours for text and the ring. On the full-screen session they sit over
/// the scenery or a dimmed scrim, so they stay light whatever the theme.
@immutable
class _FocusInk {
  const _FocusInk({
    required this.ink,
    required this.muted,
    required this.track,
  });

  final Color ink;
  final Color muted;
  final Color track;

  factory _FocusInk.themed(BloopTokens t) =>
      _FocusInk(ink: t.ink, muted: t.muted, track: t.border);

  static const onScene = _FocusInk(
    ink: Color(0xFFFFFFFF),
    muted: Color(0xC7FFFFFF),
    track: Color(0x40FFFFFF),
  );
}

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
    if (controller.isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }
    return controller.isFullScreenActive
        ? _buildSession(context, controller)
        : _buildIdle(context, controller);
  }

  /// The tab as seen between sessions: header, ring, start button and the
  /// total for today.
  Widget _buildIdle(BuildContext context, FocusController controller) {
    final tokens = BloopTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final ink = _FocusInk.themed(tokens);
    final canStart = !controller.isRunning;
    return Column(
      children: [
        ScreenHeader(
          title: 'Focus',
          actions: [
            BloopIconButton(
              icon: Icons.tune,
              tooltip: 'Timer settings',
              onPressed: () => _openSettings(context, ref),
            ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  BloopSpace.x4,
                  BloopSpace.x4,
                  BloopSpace.x4,
                  floatingNavClearance(context),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight -
                        floatingNavClearance(context) -
                        BloopSpace.x4,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SessionHeading(
                        controller: controller,
                        ink: ink,
                        showTitleWithoutTask: !controller.isFocusSession,
                      ),
                      const SizedBox(height: BloopSpace.x8),
                      _TimerDial(
                        remaining: controller.remaining,
                        progress: controller.progress,
                        paused:
                            controller.isSessionActive && !controller.isRunning,
                        ink: ink,
                      ),
                      const SizedBox(height: BloopSpace.x6),
                      Text(
                        controller.focusHintText,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: tokens.muted,
                        ),
                      ),
                      const SizedBox(height: BloopSpace.x6),
                      FilledButton.icon(
                        onPressed: () {
                          canStart ? controller.start() : controller.pause();
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(200, 56),
                          shape: const StadiumBorder(),
                        ),
                        icon: Icon(
                          canStart ? Icons.play_arrow : Icons.pause,
                          size: 20,
                        ),
                        label: Text(
                          canStart
                              ? (controller.isSessionActive
                                    ? 'Resume'
                                    : 'Start')
                              : 'Pause',
                        ),
                      ),
                      TextButton(
                        onPressed: controller.reset,
                        child: const Text('Reset'),
                      ),
                      const SizedBox(height: BloopSpace.x6),
                      FocusedTodayCard(
                        focusedDuration: controller.totalFocusSpent,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// The running session: scenery, ring and time, with controls that fade in
  /// on tap.
  Widget _buildSession(BuildContext context, FocusController controller) {
    final tokens = BloopTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final insets = MediaQuery.paddingOf(context);
    // Over scenery or a dimmed scrim the text is light; on the plain
    // background it follows the theme.
    final onScene = controller.sceneryEnabled || controller.dimScreenEnabled;
    final ink = onScene ? _FocusInk.onScene : _FocusInk.themed(tokens);
    final scrim = controller.dimScreenEnabled
        ? 0.6
        : (controller.sceneryEnabled ? 0.45 : 0.0);
    final hideHint = controller.isFocusSession && controller.taskTitle != null;

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
            tokens: tokens,
            sceneryKey: controller.selectedScenery,
            enabled: controller.sceneryEnabled,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            color: Colors.black.withValues(alpha: scrim),
          ),
          Column(
            children: [
              SizedBox(height: insets.top + 72),
              _SessionHeading(
                controller: controller,
                ink: ink,
                showTitleWithoutTask: true,
              ),
              const Spacer(),
              _TimerDial(
                remaining: controller.remaining,
                progress: controller.progress,
                paused: !controller.isRunning,
                ink: ink,
              ),
              if (!hideHint)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BloopSpace.x8,
                    BloopSpace.x6,
                    BloopSpace.x8,
                    0,
                  ),
                  child: Text(
                    controller.focusHintText,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(color: ink.muted),
                  ),
                ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.only(bottom: insets.bottom + BloopSpace.x8),
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 0 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: Text(
                    'Tap to show controls • Swipe left for settings',
                    style: textTheme.bodySmall?.copyWith(color: ink.muted),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: insets.top + BloopSpace.x4,
            right: BloopSpace.x3,
            child: ExcludeSemantics(
              excluding: !_controlsVisible,
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QuickActionChip(
                        icon: Icons.music_note_outlined,
                        label: 'Sound',
                        isEnabled: controller.soundsEnabled,
                        onTap: () {
                          _showControls();
                          _openSoundPicker(context, controller);
                        },
                      ),
                      const SizedBox(width: BloopSpace.x2),
                      _QuickActionChip(
                        icon: Icons.landscape_outlined,
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
            left: BloopSpace.x5,
            right: BloopSpace.x5,
            bottom: insets.bottom + BloopSpace.x6,
            child: ExcludeSemantics(
              excluding: !_controlsVisible,
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  child: AnimatedSlide(
                    offset: _controlsVisible
                        ? Offset.zero
                        : const Offset(0, 0.08),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    child: _FocusControlsPanel(
                      isRunning: controller.isRunning,
                      selectedSound: controller.selectedSound,
                      selectedScenery: controller.selectedScenery,
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
    final tokens = BloopTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BloopSpace.x5,
              BloopSpace.x2,
              BloopSpace.x5,
              BloopSpace.x4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.headlineSmall),
                const SizedBox(height: BloopSpace.x2),
                Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(color: tokens.muted),
                ),
                const SizedBox(height: BloopSpace.x5),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: BloopSpace.x3),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.error,
                          foregroundColor: tokens.onError,
                        ),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
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
    final sessionsController = TextEditingController(
      text: controller.totalSessions.toString(),
    );
    var autoStart = controller.autoStartNext;
    var focusMinutes = controller.focusDuration.inMinutes;
    var shortMinutes = controller.shortBreakDuration.inMinutes;
    var longMinutes = controller.longBreakDuration.inMinutes;

    try {
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: BloopSpace.x5,
                  right: BloopSpace.x5,
                  top: BloopSpace.x2,
                  bottom:
                      MediaQuery.viewInsetsOf(context).bottom + BloopSpace.x5,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timer settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: BloopSpace.x4),
                    _buildDurationControl(
                      context,
                      label: 'Focus length (min)',
                      min: 5,
                      max: 60,
                      value: focusMinutes,
                      controller: focusController,
                      onChanged: (v) => setModalState(() => focusMinutes = v),
                    ),
                    const SizedBox(height: BloopSpace.x3),
                    _buildDurationControl(
                      context,
                      label: 'Short break (min)',
                      min: 1,
                      max: 20,
                      value: shortMinutes,
                      controller: shortController,
                      onChanged: (v) => setModalState(() => shortMinutes = v),
                    ),
                    const SizedBox(height: BloopSpace.x3),
                    _buildDurationControl(
                      context,
                      label: 'Long break (min)',
                      min: 5,
                      max: 30,
                      value: longMinutes,
                      controller: longController,
                      onChanged: (v) => setModalState(() => longMinutes = v),
                    ),
                    const SizedBox(height: BloopSpace.x3),
                    TextField(
                      controller: sessionsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sessions per cycle',
                      ),
                    ),
                    const SizedBox(height: BloopSpace.x3),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: autoStart,
                      onChanged: (v) => setModalState(() => autoStart = v),
                      title: const Text('Auto-start next session'),
                    ),
                    const SizedBox(height: BloopSpace.x4),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: BloopSpace.x3),
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

      final parsedFocus =
          int.tryParse(focusController.text.trim()) ?? focusMinutes;
      final parsedShort =
          int.tryParse(shortController.text.trim()) ?? shortMinutes;
      final parsedLong =
          int.tryParse(longController.text.trim()) ?? longMinutes;
      final sessions =
          int.tryParse(sessionsController.text.trim()) ??
          controller.totalSessions;

      controller.applySettings(
        focusMinutes: parsedFocus,
        shortMinutes: parsedShort,
        longMinutes: parsedLong,
        totalSessions: sessions,
        autoStartNext: autoStart,
      );
    } finally {
      focusController.dispose();
      shortController.dispose();
      longController.dispose();
      sessionsController.dispose();
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
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  BloopSpace.x5,
                  BloopSpace.x2,
                  BloopSpace.x5,
                  BloopSpace.x4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: BloopSpace.x3),
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
                    const SizedBox(height: BloopSpace.x3),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
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
    var selected = controller.selectedSound;
    await _showPickerSheet(
      context,
      title: 'Change sound',
      children: [
        for (final name in focusSoundAssets.keys)
          _PickerTile(
            title: name,
            selected: name == selected,
            onTap: () {
              selected = name;
              Navigator.pop(context);
            },
          ),
      ],
    );
    controller.setSelectedSound(selected);
    _armAutoHide();
  }

  Future<void> _openSceneryPicker(
    BuildContext context,
    FocusController controller,
  ) async {
    _controlsTimer?.cancel();
    var selected = controller.selectedScenery;
    await _showPickerSheet(
      context,
      title: 'Change scenery',
      children: [
        for (final name in _sceneryOptions)
          _PickerTile(
            title: name,
            selected: name == selected,
            leading: _SceneryThumb(config: _sceneryConfigs[name]!),
            onTap: () {
              selected = name;
              Navigator.pop(context);
            },
          ),
      ],
    );
    controller.setSelectedScenery(selected);
    _armAutoHide();
  }

  Future<void> _showPickerSheet(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BloopSpace.x5,
                  BloopSpace.x2,
                  BloopSpace.x5,
                  BloopSpace.x2,
                ),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Flexible(child: ListView(shrinkWrap: true, children: children)),
            ],
          ),
        );
      },
    );
  }
}

/// "Focusing on" and the task title while a task is attached, else the session number
/// and (when [showTitleWithoutTask]) the session name.
class _SessionHeading extends StatelessWidget {
  const _SessionHeading({
    required this.controller,
    required this.ink,
    required this.showTitleWithoutTask,
  });

  final FocusController controller;
  final _FocusInk ink;
  final bool showTitleWithoutTask;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final taskTitle = controller.isFocusSession ? controller.taskTitle : null;
    final caption = taskTitle != null
        ? 'Focusing on'
        : 'Session ${controller.sessionIndex} of ${controller.totalSessions}';
    final title =
        taskTitle ?? (showTitleWithoutTask ? controller.sessionLabel : null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            caption.toUpperCase(),
            textAlign: TextAlign.center,
            style: textTheme.labelMedium?.copyWith(
              color: ink.muted,
              letterSpacing: 0.8,
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: BloopSpace.x2),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.headlineMedium?.copyWith(
                color: ink.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ring with the time left in the middle. [progress] is 0..1 of the session
/// elapsed. A [paused] session dims the time and says so.
class _TimerDial extends StatelessWidget {
  const _TimerDial({
    required this.remaining,
    required this.progress,
    required this.ink,
    this.paused = false,
  });

  final Duration remaining;
  final double progress;
  final bool paused;
  final _FocusInk ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final timeColor = paused ? ink.muted : ink.ink;
    return Semantics(
      label:
          'Time left $minutes minutes $seconds seconds'
          '${paused ? ', paused' : ''}',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: _kDialSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  color: ink.ink,
                  backgroundColor: ink.track,
                  year2023: false,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$minutes:$seconds',
                  style: textTheme.displayLarge?.copyWith(
                    fontSize: 64,
                    height: 72 / 64,
                    fontWeight: FontWeight.w500,
                    color: timeColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (paused)
                  Text(
                    'Paused',
                    style: textTheme.bodySmall?.copyWith(
                      color: ink.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusControlsPanel extends StatelessWidget {
  const _FocusControlsPanel({
    required this.isRunning,
    required this.selectedSound,
    required this.selectedScenery,
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
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;
  final VoidCallback onPauseResume;
  final VoidCallback onSlideEnd;
  final VoidCallback onSkipRequested;
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final summaryStyle = textTheme.bodySmall?.copyWith(color: tokens.muted);
    return Listener(
      onPointerDown: (_) => onInteractionStart(),
      onPointerUp: (_) => onInteractionEnd(),
      onPointerCancel: (_) => onInteractionEnd(),
      child: Container(
        padding: const EdgeInsets.all(BloopSpace.x4),
        decoration: BoxDecoration(
          color: tokens.raised,
          borderRadius: BorderRadius.circular(BloopRadii.lg),
          border: Border.all(color: tokens.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: onPauseResume,
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 56),
                shape: const StadiumBorder(),
              ),
              icon: Icon(isRunning ? Icons.pause : Icons.play_arrow, size: 20),
              label: Text(isRunning ? 'Pause' : 'Resume'),
            ),
            const SizedBox(height: BloopSpace.x3),
            SlideToEndControl(
              label: 'Slide to end session',
              onCompleted: onSlideEnd,
              onInteract: onInteract,
            ),
            const SizedBox(height: BloopSpace.x3),
            LongSwipeSkipControl(
              label: 'Long swipe to skip session',
              onArmed: onSkipRequested,
              onInteract: onInteract,
              mutedStyle: true,
            ),
            const SizedBox(height: BloopSpace.x3),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: BloopSpace.x4,
              runSpacing: BloopSpace.x1,
              children: [
                _SummaryItem(
                  icon: Icons.music_note_outlined,
                  label: selectedSound,
                  style: summaryStyle,
                ),
                _SummaryItem(
                  icon: Icons.landscape_outlined,
                  label: selectedScenery,
                  style: summaryStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.style,
  });

  final IconData icon;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: style?.color),
        const SizedBox(width: BloopSpace.x1),
        Flexible(child: Text(label, style: style)),
      ],
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
    return _SlideControl(
      label: label,
      icon: Icons.chevron_right_rounded,
      onSubmit: () {
        onInteract();
        onCompleted();
      },
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
    return _SlideControl(
      label: label,
      icon: Icons.fast_forward_rounded,
      onSubmit: () {
        onInteract();
        onArmed();
      },
    );
  }
}

/// A sunken track with a raised knob, shared by the end and skip controls.
class _SlideControl extends StatelessWidget {
  const _SlideControl({
    required this.label,
    required this.icon,
    required this.onSubmit,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    return SlideAction(
      onSubmit: () async => onSubmit(),
      height: 48,
      text: label,
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: tokens.muted),
      outerColor: tokens.sunken,
      innerColor: tokens.raised,
      elevation: 0,
      borderRadius: 999,
      sliderButtonIconPadding: 1,
      sliderButtonIcon: Icon(icon, color: tokens.ink, size: 32),
      sliderRotate: false,
    );
  }
}

/// Small pill over the scenery that opens a picker.
class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
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
    final tokens = BloopTokens.of(context);
    final color = isEnabled ? tokens.ink : tokens.muted;
    return Material(
      color: tokens.raised,
      shape: StadiumBorder(side: BorderSide(color: tokens.border)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kBloopMinTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: BloopSpace.x2),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row in the sound and scenery pickers; a check marks the current one.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(title),
      trailing: selected ? const Icon(Icons.check) : null,
      selected: selected,
      onTap: onTap,
    );
  }
}

/// Swatch of a scenery, for the picker.
class _SceneryThumb extends StatelessWidget {
  const _SceneryThumb({required this.config});

  final SceneryConfig config;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final Widget fill = switch (config.type) {
      SceneryType.gradient => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: config.colors ?? [tokens.surface, tokens.sunken],
          ),
        ),
      ),
      SceneryType.image => Image.asset(
        config.assetPath ?? '',
        fit: BoxFit.cover,
        cacheWidth: 96,
        errorBuilder: (_, _, _) => ColoredBox(color: tokens.sunken),
      ),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(BloopRadii.md),
      child: SizedBox.square(dimension: 40, child: fill),
    );
  }
}

class _FocusSceneryBackground extends StatelessWidget {
  const _FocusSceneryBackground({
    required this.tokens,
    required this.sceneryKey,
    required this.enabled,
  });

  final BloopTokens tokens;
  final String sceneryKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final config = _sceneryConfigs[sceneryKey] ?? _sceneryConfigs.values.first;
    final plain = [tokens.surface, tokens.sunken];
    if (enabled && config.type == SceneryType.image) {
      final assetPath = config.assetPath;
      if (assetPath != null && assetPath.isNotEmpty) {
        return Image.asset(assetPath, fit: BoxFit.cover);
      }
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: enabled ? config.colors ?? plain : plain,
        ),
      ),
    );
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
  'Forest Path': SceneryConfig.image(assetPath: 'assets/scenery/forest_1.jpg'),
  'Evergreen': SceneryConfig.image(assetPath: 'assets/scenery/forest_2.jpg'),
  'Quiet Library': SceneryConfig.image(
    assetPath: 'assets/scenery/library_1.jpg',
  ),
  'Blue Ridge': SceneryConfig.image(assetPath: 'assets/scenery/mountain_1.jpg'),
  'Alpine Glow': SceneryConfig.image(
    assetPath: 'assets/scenery/mountain_2.jpg',
  ),
};

final List<String> _sceneryOptions = _sceneryConfigs.keys.toList(
  growable: false,
);

/// Total focused time today, as a quiet bordered row.
class FocusedTodayCard extends StatelessWidget {
  final Duration focusedDuration;
  const FocusedTodayCard({super.key, required this.focusedDuration});

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final totalMinutes = focusedDuration.inMinutes;
    final displayText = totalMinutes < 60
        ? '${totalMinutes}m'
        : '${(totalMinutes / 60).toStringAsFixed(1)}h';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: BloopSpace.x4,
        vertical: BloopSpace.x3,
      ),
      decoration: BoxDecoration(
        color: tokens.raised,
        borderRadius: BorderRadius.circular(BloopRadii.lg),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom_outlined, color: tokens.muted),
          const SizedBox(width: BloopSpace.x3),
          Expanded(child: Text('Focused today', style: textTheme.titleMedium)),
          Text(displayText, style: textTheme.headlineSmall),
        ],
      ),
    );
  }
}
