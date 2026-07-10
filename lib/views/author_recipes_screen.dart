import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/recipe_viewmodel.dart';
import 'recipe_detail_screen.dart';
import 'widgets/recipe_card.dart';

/// A chef's public profile: their photo/initial, some stats, and every recipe
/// they created. Reached by tapping the "Made by …" chip on a recipe.
class AuthorRecipesScreen extends ConsumerWidget {
  final String authorId;
  final String authorName;

  const AuthorRecipesScreen({
    super.key,
    required this.authorId,
    required this.authorName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesState = ref.watch(recipeViewModelProvider);
    final isSelf =
        ref.watch(authServiceProvider).currentUser?.uid == authorId;
    // Fetch the chef's photo straight from Storage by uid — works for anyone.
    final photoUrl = ref.watch(profilePhotoProvider(authorId)).asData?.value;
    final initial = authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: Text(isSelf ? 'You' : authorName)),
      body: recipesState.when(
        data: (recipes) {
          final theirs =
              recipes.where((r) => r.authorId == authorId).toList();
          final totalSaves =
              theirs.fold<int>(0, (sum, r) => sum + r.favoritedBy.length);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _ProfileHeader(
                name: authorName,
                initial: initial,
                photoUrl: photoUrl,
                recipeCount: theirs.length,
                totalSaves: totalSaves,
              ),
              const SizedBox(height: 24),
              Text('Recipes',
                  style: AppText.display(19, weight: FontWeight.w800)),
              const SizedBox(height: 14),
              if (theirs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text('No recipes yet.',
                        style: AppText.sans(15, color: AppColors.muted)),
                  ),
                )
              else
                ...theirs.map((recipe) => RecipeCard(
                      recipe: recipe,
                      heroTag: 'author_${recipe.id}',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecipeDetailScreen(
                              recipe: recipe, heroTag: 'author_${recipe.id}'),
                        ),
                      ),
                    )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Error: $error',
              style: AppText.sans(14, color: AppColors.muted)),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String initial;
  final String? photoUrl;
  final int recipeCount;
  final int totalSaves;

  const _ProfileHeader({
    required this.name,
    required this.initial,
    required this.photoUrl,
    required this.recipeCount,
    required this.totalSaves,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 64,
                width: 64,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: AppColors.blush,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: (photoUrl != null && photoUrl!.isNotEmpty)
                    ? Image.network(photoUrl!,
                        fit: BoxFit.cover,
                        height: 64,
                        width: 64,
                        errorBuilder: (_, _, _) => _initialText())
                    : _initialText(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.display(22, weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Home chef',
                        style: AppText.sans(14, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Stat(value: '$recipeCount', label: 'Recipes'),
              ),
              Container(width: 1, height: 34, color: AppColors.line),
              Expanded(
                child: _Stat(value: '$totalSaves', label: 'Saves'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initialText() {
    return Center(
      child: Text(initial,
          style: AppText.display(26,
              color: AppColors.primaryPressed, weight: FontWeight.w800)),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppText.display(22, weight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: AppText.sans(13, color: AppColors.muted)),
      ],
    );
  }
}
