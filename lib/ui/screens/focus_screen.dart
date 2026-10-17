import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'focus_controller.dart';
import 'focus_widgets.dart';

class FocusScreen extends ConsumerStatefulWidget {
	const FocusScreen({Key? key}) : super(key: key);

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
		final controller = ref.watch(focusControllerProvider);
		final isFullScreen = controller.isFullScreenActive;
		WidgetsBinding.instance.addPostFrameCallback((_) {
			_updateSystemUi(isFullScreen);
		});
		return Scaffold(
			extendBodyBehindAppBar: isFullScreen,
			appBar: isFullScreen
				? null
				: AppBar(
					title: const Text('Focus'),
					toolbarHeight: MediaQuery.of(context).size.height * 0.1,
					// centerTitle: true,
				),
			body: isFullScreen
				? const PomodoroCard()
				: SafeArea(
					top: true,
					bottom: true,
					left: true,
					right: true,
					child: const PomodoroCard(),
				),
		);
	}
}

