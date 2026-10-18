import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/onboarding_provider.dart';
import '../widgets/example_task_confetti.dart';
import 'app_shell.dart';
import 'onboarding_screen.dart';

/// Onboarding until it is done, then the app. Sits in front of [AppShell], so
/// its first-launch permission prompts wait until onboarding has finished.
///
/// The example task's confetti is laid over the whole app rather than Home, so
/// completing the example from the Focus tab still shows it.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(onboardingProvider);
    return done
        ? const ExampleTaskConfetti(child: AppShell())
        : const OnboardingScreen();
  }
}
