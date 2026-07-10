import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/recipe_viewmodel.dart';
import 'recipe_detail_screen.dart';
import 'widgets/error_state.dart';
import 'widgets/recipe_card.dart';
import 'widgets/skeletons.dart';

class RecipeListScreen extends ConsumerWidget {
  final String category;

  const RecipeListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesState = ref.watch(recipeViewModelProvider);
    final uid = ref.watch(authServiceProvider).currentUser?.uid;
    final isFavorites = category.toLowerCase() == 'favorites';

    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recipeViewModelProvider);
          await ref.read(recipeViewModelProvider.future);
        },
        color: AppColors.primary,
        child: recipesState.when(
          data: (recipes) {
          final filtered = isFavorites
              ? recipes.where((r) => r.isFavoritedBy(uid)).toList()
              : recipes
                  .where((r) =>
                      r.category.toLowerCase() == category.toLowerCase())
                  .toList();

          if (filtered.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.6,
                  child: _EmptyState(
                    message: isFavorites
                        ? 'No favorites yet. Tap the heart on a recipe to save it here.'
                        : 'No $category recipes yet.',
                    icon: isFavorites
                        ? Icons.favorite_border_rounded
                        : Icons.restaurant_menu_rounded,
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filtered.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 14),
                  child: Text(
                    '${filtered.length} ${filtered.length == 1 ? 'recipe' : 'recipes'}',
                    style: AppText.sans(14, color: AppColors.muted),
                  ),
                );
              }
              final recipe = filtered[index - 1];
              return RecipeCard(
                recipe: recipe,
                heroTag: 'cat_${recipe.id}',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(
                        recipe: recipe, heroTag: 'cat_${recipe.id}'),
                  ),
                ),
              );
            },
          );
          },
          loading: () => const RecipeListSkeleton(),
          error: (error, _) => ErrorState(
            message: "We couldn't load these recipes.",
            onRetry: () => ref.invalidate(recipeViewModelProvider),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.muted.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: AppText.sans(15, color: AppColors.muted, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
