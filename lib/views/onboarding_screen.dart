import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/user_prefs_service.dart';
import '../theme/app_theme.dart';
import 'widgets/ui_kit.dart';

/// One-time intro shown on a user's first launch. Marking it done writes to
/// `user_prefs/{uid}`, and the auth gate reacts by showing the app.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _Page(
      icon: Icons.local_fire_department_rounded,
      title: 'Welcome to Sizzle',
      body: 'Discover recipes, save the ones you love, and cook them with '
          'confidence, all in one place.',
    ),
    _Page(
      icon: Icons.soup_kitchen_rounded,
      title: 'Cook hands-free',
      body: 'Step-by-step Cooking Mode keeps the screen awake, checks off '
          'ingredients, and times your steps for you.',
    ),
    _Page(
      icon: Icons.bookmark_added_rounded,
      title: 'Make it your own',
      body: 'Favorite recipes, group them into collections, jot private notes, '
          'and build a shopping list in a tap.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pages.length - 1;

  void _finish() {
    // Advance immediately (session flag), then persist for next launch as a
    // best effort — the gate no longer depends on the write succeeding.
    ref.read(onboardingDismissedProvider.notifier).dismiss();
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) {
      ref.read(userPrefsServiceProvider).setOnboarded(uid);
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                child: TextButton(
                  onPressed: _finish,
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.muted),
                  child: const Text('Skip'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const BrandMark(),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) => _pages[i],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: i == _index ? 22 : 8,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.primary : AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(_isLast ? 'Start cooking' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Page({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 132,
            width: 132,
            decoration: const BoxDecoration(
              color: AppColors.blush,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 60, color: AppColors.primary),
          ),
          const SizedBox(height: 36),
          Text(title,
              textAlign: TextAlign.center,
              style: AppText.display(28, weight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(body,
              textAlign: TextAlign.center,
              style: AppText.sans(15, color: AppColors.muted, height: 1.6)),
        ],
      ),
    );
  }
}
