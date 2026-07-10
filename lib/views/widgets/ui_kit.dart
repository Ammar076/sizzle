import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A soft, rounded pill showing an icon + label. Used for recipe meta such as
/// total time and servings across cards and the detail screen.
class MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? background;
  final Color? foreground;

  const MetaPill({
    super.key,
    required this.icon,
    required this.label,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? AppColors.forest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background ?? AppColors.sage,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label, style: AppText.sans(13, weight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// Colour identity for each recipe category, so chips and badges feel varied
/// but cohesive.
class CategoryStyle {
  final Color tint;
  final Color accent;
  const CategoryStyle(this.tint, this.accent);

  static CategoryStyle of(String category) {
    switch (category.toLowerCase()) {
      case 'breakfast':
        return const CategoryStyle(Color(0xFFFFF1D6), Color(0xFFB77500));
      case 'lunch':
        return const CategoryStyle(AppColors.sage, AppColors.forest);
      case 'dinner':
        return const CategoryStyle(Color(0xFFE7EDF6), Color(0xFF2C4A7A));
      case 'favorites':
        return const CategoryStyle(AppColors.blush, AppColors.primaryPressed);
      default:
        return const CategoryStyle(AppColors.blush, AppColors.primaryPressed);
    }
  }
}

/// (background, foreground) colours for a difficulty label.
(Color, Color) difficultyTint(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return (AppColors.sage, AppColors.forest);
    case 'medium':
      return (const Color(0xFFFFF1D6), const Color(0xFFB77500));
    case 'hard':
      return (AppColors.blush, AppColors.primaryPressed);
    default:
      return (AppColors.sage, AppColors.forest);
  }
}

/// A small tinted pill (icon optional) used for category/difficulty/cuisine.
class TagPill extends StatelessWidget {
  final String label;
  final Color tint;
  final Color accent;
  final IconData? icon;
  const TagPill({
    super.key,
    required this.label,
    required this.tint,
    required this.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: accent),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: AppText.sans(12, weight: FontWeight.w700, color: accent)),
        ],
      ),
    );
  }
}

/// The wordmark used on the auth screens and as a small brand cue.
class BrandMark extends StatelessWidget {
  final double size;
  final bool showText;
  const BrandMark({super.key, this.size = 56, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.32),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.restaurant_menu_rounded,
              color: Colors.white, size: size * 0.5),
        ),
        if (showText) ...[
          const SizedBox(height: 18),
          Text('Sizzle', style: AppText.display(34, weight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('RECIPES',
              style: AppText.sans(12,
                  weight: FontWeight.w800,
                  color: AppColors.primary,
                  spacing: 7)),
        ],
      ],
    );
  }
}
