import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/recipe.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/recipe_viewmodel.dart';
import 'ui_kit.dart';

/// Toggles [recipe] in the current user's favorites with haptic + snackbar
/// feedback so the tap is always confirmed. Shared by the card and detail
/// buttons. Favorites are per-user.
void toggleFavoriteWithFeedback(
    BuildContext context, WidgetRef ref, Recipe recipe) {
  final uid = ref.read(authServiceProvider).currentUser?.uid;
  if (uid == null) return;
  HapticFeedback.lightImpact();
  final willFavorite = !recipe.isFavoritedBy(uid);
  ref.read(recipeViewModelProvider.notifier).setFavorite(recipe, uid);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1400),
        content: Text(willFavorite
            ? 'Added to favorites'
            : 'Removed from favorites'),
      ),
    );
}

/// The recipe list card used across the list, browse and home screens. Handles
/// its own favorite toggle; the parent supplies the tap action.
class RecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final String? heroTag;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = CategoryStyle.of(recipe.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.card)),
                  child: heroTag != null
                      ? Hero(
                          tag: heroTag!,
                          child:
                              RecipeImage(imageUrl: recipe.imageUrl, height: 190),
                        )
                      : RecipeImage(imageUrl: recipe.imageUrl, height: 190),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  right: 60,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      TagPill(
                          label: recipe.category,
                          tint: cat.tint,
                          accent: cat.accent),
                      if (recipe.difficulty != null)
                        TagPill(
                          label: recipe.difficulty!,
                          tint: difficultyTint(recipe.difficulty!).$1,
                          accent: difficultyTint(recipe.difficulty!).$2,
                          icon: Icons.speed_rounded,
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _FavoriteButton(recipe: recipe),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(20, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    recipe.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(14, color: AppColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      MetaPill(
                        icon: Icons.schedule_rounded,
                        label: '${recipe.prepTime + recipe.cookTime} min',
                      ),
                      const SizedBox(width: 8),
                      MetaPill(
                        icon: Icons.people_alt_rounded,
                        label: '${recipe.feeds} serves',
                      ),
                      if (recipe.ratingCount > 0) ...[
                        const Spacer(),
                        const Icon(Icons.star_rounded,
                            size: 18, color: AppColors.honey),
                        const SizedBox(width: 4),
                        Text(recipe.averageRating.toStringAsFixed(1),
                            style:
                                AppText.sans(14, weight: FontWeight.w800)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  final Recipe recipe;
  const _FavoriteButton({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authServiceProvider).currentUser?.uid;
    final fav = recipe.isFavoritedBy(uid);
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => toggleFavoriteWithFeedback(context, ref, recipe),
        child: Tooltip(
          message: fav ? 'Remove from favorites' : 'Add to favorites',
          child: Semantics(
            button: true,
            label: fav ? 'Remove from favorites' : 'Add to favorites',
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              fav
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              key: ValueKey(fav),
              size: 20,
              color: fav ? AppColors.primary : AppColors.muted,
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders a recipe image from a network URL, a bundled asset, or a local file
/// path, with a graceful placeholder while loading or on error.
class RecipeImage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final double? width;

  const RecipeImage({
    super.key,
    required this.imageUrl,
    required this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
          height: height,
          width: width ?? double.infinity,
          color: AppColors.sage,
          child: Icon(Icons.restaurant_rounded,
              size: 44, color: AppColors.forest.withValues(alpha: 0.35)),
        );

    Widget errorFallback(_, _, _) => placeholder();

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        height: height,
        width: width ?? double.infinity,
        fit: BoxFit.cover,
        errorBuilder: errorFallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder(),
      );
    }
    if (imageUrl.startsWith('/') || imageUrl.contains(':\\')) {
      return Image.file(
        File(imageUrl),
        height: height,
        width: width ?? double.infinity,
        fit: BoxFit.cover,
        errorBuilder: errorFallback,
      );
    }
    return Image.asset(
      imageUrl,
      height: height,
      width: width ?? double.infinity,
      fit: BoxFit.cover,
      errorBuilder: errorFallback,
    );
  }
}
