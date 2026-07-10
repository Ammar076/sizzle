import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/user_prefs_service.dart';
import '../main_shell.dart';
import '../onboarding_screen.dart';
import 'login_screen.dart';

/// Decides what the app shows based on auth state: the login screen when signed
/// out, the home screen when signed in.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) => user == null ? const LoginScreen() : const _SignedInGate(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const LoginScreen(),
    );
  }
}

/// Once signed in, shows the one-time onboarding until it's completed, then the
/// app. Fails open (shows the app) on any error so onboarding never blocks.
class _SignedInGate extends ConsumerWidget {
  const _SignedInGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Once dismissed this session, always show the app — even if persistence
    // failed — so onboarding can never trap the user.
    if (ref.watch(onboardingDismissedProvider)) return const MainShell();

    final onboarded = ref.watch(onboardedProvider);
    return onboarded.when(
      data: (done) => done ? const MainShell() : const OnboardingScreen(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const MainShell(),
    );
  }
}
