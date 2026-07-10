import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/recently_viewed.dart';
import '../viewmodels/recipe_viewmodel.dart';
import 'browse_screen.dart';
import 'create_recipe_screen.dart';
import 'main_shell.dart';
import 'recipe_detail_screen.dart';
import 'recipe_list_screen.dart';
import 'widgets/error_state.dart';
import 'widgets/recipe_card.dart';
import 'widgets/skeletons.dart';
import 'widgets/ui_kit.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _categories = [
    (label: 'Breakfast', icon: Icons.bakery_dining_rounded),
    (label: 'Lunch', icon: Icons.lunch_dining_rounded),
    (label: 'Dinner', icon: Icons.dinner_dining_rounded),
  ];

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesState = ref.watch(recipeViewModelProvider);
    // Personalise the greeting with the user's first name.
    final displayName = ref.watch(authServiceProvider).displayName;
    final firstName = displayName.split(' ').first;
    final greeting = firstName.isEmpty || firstName == 'Me'
        ? _greeting()
        : '${_greeting()}, $firstName';

    // Hidden briefly while a detail screen plays its hero return, so the
    // flying image never covers the FAB.
    final chromeHidden = ref.watch(chromeHiddenProvider);

    // Resolve the session's recently-viewed ids against the live recipe list.
    final recentIds = ref.watch(recentlyViewedProvider);
    final allRecipes = recipesState.asData?.value ?? const <Recipe>[];
    final recent = <Recipe>[
      for (final id in recentIds)
        ...allRecipes.where((r) => r.id == id).take(1),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recipeViewModelProvider);
            await ref.read(recipeViewModelProvider.future);
          },
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting,
                        style: AppText.sans(15,
                            color: AppColors.muted, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('What will you cook?',
                        style: AppText.display(28, weight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    _SearchBar(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BrowseScreen()),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text('Categories',
                        style: AppText.display(19, weight: FontWeight.w800)),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final c = _categories[index];
                    return _CategoryTile(
                      label: c.label,
                      icon: c.icon,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecipeListScreen(category: c.label),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (recent.isNotEmpty)
              SliverToBoxAdapter(child: _RecentlyViewed(recipes: recent)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Fresh from the kitchen',
                        style: AppText.display(19, weight: FontWeight.w800)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BrowseScreen()),
                      ),
                      child: Text('See all',
                          style: AppText.sans(14,
                              color: AppColors.primary,
                              weight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
            recipesState.when(
              data: (recipes) => _FeedSliver(recipes: recipes),
              loading: () => const SliverToBoxAdapter(
                child: RecipeListSkeleton(
                  count: 3,
                  padding: EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: ErrorState(
                    message: "We couldn't load your recipes.",
                    onRetry: () => ref.invalidate(recipeViewModelProvider),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: chromeHidden ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: chromeHidden,
          child: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateRecipeScreen()),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            icon: const Icon(Icons.add_rounded),
            label: Text('New recipe',
                style: AppText.sans(15,
                    weight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.muted),
            const SizedBox(width: 12),
            Text('Search recipes…',
                style: AppText.sans(15, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _CategoryTile(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(label);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: style.tint,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: style.accent, size: 21),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: AppText.sans(12.5, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _RecentlyViewed extends StatelessWidget {
  final List<Recipe> recipes;
  const _RecentlyViewed({required this.recipes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
          child: Text('Recently viewed',
              style: AppText.display(19, weight: FontWeight.w800)),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: recipes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return _RecentCard(
                recipe: recipe,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(
                        recipe: recipe, heroTag: 'recent_${recipe.id}'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  const _RecentCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'recent_${recipe.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: RecipeImage(imageUrl: recipe.imageUrl, height: 108),
              ),
            ),
            const SizedBox(height: 10),
            Text(recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(14, weight: FontWeight.w700, height: 1.25)),
          ],
        ),
      ),
    );
  }
}

class _FeedSliver extends StatelessWidget {
  final List<Recipe> recipes;
  const _FeedSliver({required this.recipes});

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                Icon(Icons.ramen_dining_rounded,
                    size: 44, color: AppColors.muted.withValues(alpha: 0.6)),
                const SizedBox(height: 12),
                Text('No recipes yet',
                    style: AppText.display(18, weight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Tap “New recipe” to add your first dish.',
                    textAlign: TextAlign.center,
                    style: AppText.sans(14, color: AppColors.muted)),
              ],
            ),
          ),
        ),
      );
    }

    // Show the most recent handful on the home feed.
    final feed = recipes.take(6).toList();
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList.builder(
        itemCount: feed.length,
        itemBuilder: (context, index) {
          final recipe = feed[index];
          return RecipeCard(
            recipe: recipe,
            heroTag: 'home_${recipe.id}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(
                    recipe: recipe, heroTag: 'home_${recipe.id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}
