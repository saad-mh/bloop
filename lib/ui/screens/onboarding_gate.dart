import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/onboarding_provider.dart';
import 'app_shell.dart';
import 'onboarding_screen.dart';

/// Onboarding until it is done, then the app. Sits in front of [AppShell], so
/// its first-launch permission prompts wait until onboarding has finished.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(onboardingProvider);
    return done ? const AppShell() : const OnboardingScreen();
  }
}
