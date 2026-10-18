import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'focus_controller.dart';
import 'focus_widgets.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with WidgetsBindingObserver {
  bool _systemUiHidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(focusControllerProvider);
  }

  @override
  void dispose() {
    _updateSystemUi(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(focusControllerProvider).handleLifecycle(state);
    if (state == AppLifecycleState.resumed) {
      final controller = ref.read(focusControllerProvider);
      _updateSystemUi(controller.isFullScreenActive);
    }
  }

  Future<void> _updateSystemUi(bool hide) async {
    if (_systemUiHidden == hide) return;
    _systemUiHidden = hide;
    if (hide) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [],
      );
    } else {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFullScreen = ref.watch(
      focusControllerProvider.select((c) => c.isFullScreenActive),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSystemUi(isFullScreen);
    });
    // The card draws its own header, so the screen is just a backdrop.
    return const Scaffold(body: PomodoroCard());
  }
}
