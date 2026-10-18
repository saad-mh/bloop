import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/task_provider.dart';

/// Lays a confetti burst over [child] the first time the onboarding example
/// task is completed. Deleting the example, or finishing it, retires it so
/// nothing else ever sets the confetti off.
class ExampleTaskConfetti extends ConsumerStatefulWidget {
  const ExampleTaskConfetti({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ExampleTaskConfetti> createState() =>
      _ExampleTaskConfettiState();
}

class _ExampleTaskConfettiState extends ConsumerState<ExampleTaskConfetti> {
  late final ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTasksChanged(AsyncValue<List<Task>> tasks) {
    final id = ref.read(exampleTaskIdProvider);
    final list = tasks.valueOrNull;
    if (id == null || list == null) return;
    final example = list.where((t) => t.id == id).firstOrNull;
    // Gone (deleted) or done: either way the example has served its purpose.
    if (example != null && !example.isCompleted) return;
    ref.read(onboardingProvider.notifier).clearExampleTask();
    if (example == null) return;
    // Reduced motion gets the completion without the burst.
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(taskListProvider, (_, next) => _onTasksChanged(next));
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: Align(
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: ConfettiWidget(
                confettiController: _controller,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.05,
                numberOfParticles: 30,
                minBlastForce: 10,
                maxBlastForce: 40,
                gravity: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
