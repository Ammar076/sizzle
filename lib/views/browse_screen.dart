import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/recipe_viewmodel.dart';
import 'recipe_detail_screen.dart';
import 'widgets/error_state.dart';
import 'widgets/recipe_card.dart';
import 'widgets/skeletons.dart';

enum SortOption {
  newest('Newest'),
  quickest('Quickest'),
  mostSaved('Most saved'),
  topRated('Top rated');

  const SortOption(this.label);
  final String label;
}

/// Browsable list of every recipe with a live text search (title/description),
/// category filter chips, and a sort menu.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';
  SortOption _sort = SortOption.newest;

  static const _filters = ['All', 'Favorites', 'Breakfast', 'Lunch', 'Dinner'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Recipe> _applyFilters(List<Recipe> recipes) {
    final query = _query.trim().toLowerCase();
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    return recipes.where((r) {
      final matchesCategory = switch (_selectedCategory) {
        'All' => true,
        'Favorites' => r.isFavoritedBy(uid),
        _ => r.category.toLowerCase() == _selectedCategory.toLowerCase(),
      };
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;
      return r.title.toLowerCase().contains(query) ||
          r.description.toLowerCase().contains(query);
    }).toList();
  }

  /// Sorts in place per [_sort]. "Newest" keeps the provider's existing
  /// newest-first order.
  List<Recipe> _applySort(List<Recipe> recipes) {
    final list = [...recipes];
    switch (_sort) {
      case SortOption.newest:
        break;
      case SortOption.quickest:
        list.sort((a, b) =>
            (a.prepTime + a.cookTime).compareTo(b.prepTime + b.cookTime));
      case SortOption.mostSaved:
        list.sort((a, b) => b.favoritedBy.length.compareTo(a.favoritedBy.length));
      case SortOption.topRated:
        list.sort((a, b) => b.averageRating.compareTo(a.averageRating));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final recipesState = ref.watch(recipeViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        toolbarHeight: 64,
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.swap_vert_rounded),
            tooltip: 'Sort',
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              for (final option in SortOption.values)
                PopupMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      Icon(
                        _sort == option
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: _sort == option
                            ? AppColors.primary
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 10),
                      Text(option.label,
                          style: AppText.sans(14, weight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search recipes…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.muted,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                return _FilterChip(
                  label: filter,
                  selected: filter == _selectedCategory,
                  onTap: () => setState(() => _selectedCategory = filter),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(recipeViewModelProvider);
                await ref.read(recipeViewModelProvider.future);
              },
              color: AppColors.primary,
              child: recipesState.when(
                data: (recipes) {
                  final filtered = _applySort(_applyFilters(recipes));
                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.5,
                          child: _EmptyState(query: _query),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final recipe = filtered[index];
                      return RecipeCard(
                        recipe: recipe,
                        heroTag: 'search_${recipe.id}',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(
                                recipe: recipe,
                                heroTag: 'search_${recipe.id}'),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const RecipeListSkeleton(),
                error: (error, _) => ErrorState(
                  message: "We couldn't load recipes.",
                  onRetry: () => ref.invalidate(recipeViewModelProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.line),
        ),
        child: Text(
          label,
          style: AppText.sans(14,
              weight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.ink),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 56, color: AppColors.muted.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            query.isEmpty
                ? 'No recipes match this filter.'
                : 'No recipes found for “$query”.',
            style: AppText.sans(15, color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
