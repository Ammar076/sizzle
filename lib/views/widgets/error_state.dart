import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Friendly, reusable "couldn't load" state with a Retry action. Screens pass
/// an [onRetry] that re-fetches (typically `ref.invalidate(theProvider)`), so
/// users never see a raw Firestore error string.
class ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;
  const ErrorState({
    super.key,
    required this.onRetry,
    this.message = "We couldn't load this right now.",
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColors.muted.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            Text('Something went wrong',
                style: AppText.display(20, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('$message\nCheck your connection and try again.',
                textAlign: TextAlign.center,
                style: AppText.sans(14, color: AppColors.muted, height: 1.5)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest,
                side: const BorderSide(color: AppColors.line),
                backgroundColor: AppColors.surface,
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button)),
                textStyle: AppText.sans(15, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
