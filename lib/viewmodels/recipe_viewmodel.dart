import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';

final recipeServiceProvider =
    Provider<RecipeService>((ref) => FirestoreRecipeService());

class RecipeNotifier extends StreamNotifier<List<Recipe>> {
  @override
  Stream<List<Recipe>> build() {
    final recipeService = ref.watch(recipeServiceProvider);
    return recipeService.getRecipes();
  }

  /// Toggles [recipe] in [uid]'s favorites. Favorites are stored per-user in
  /// the recipe's `favoritedBy` list.
  Future<void> setFavorite(Recipe recipe, String uid) async {
    try {
      final willFavorite = !recipe.isFavoritedBy(uid);
      await ref
          .read(recipeServiceProvider)
          .setFavorite(recipe.id, uid, willFavorite);
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  /// Records [uid]'s star rating (1..5) for [recipe].
  Future<void> setRating(Recipe recipe, String uid, int stars) async {
    try {
      await ref.read(recipeServiceProvider).setRating(recipe.id, uid, stars);
    } catch (e) {
      debugPrint('Error setting rating: $e');
    }
  }

  Future<void> addRecipe(Recipe recipe) async {
    try {
      await ref.read(recipeServiceProvider).addRecipe(recipe);
    } catch (e) {
      debugPrint('Error adding recipe: $e');
    }
  }

  Future<void> updateRecipe(Recipe recipe) async {
    try {
      await ref.read(recipeServiceProvider).updateRecipe(recipe);
    } catch (e) {
      debugPrint('Error updating recipe: $e');
    }
  }

  Future<void> deleteRecipe(String recipeId) async {
    try {
      await ref.read(recipeServiceProvider).deleteRecipe(recipeId);
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
    }
  }

  /// Uploads [file] and returns the stored image URL. Throws on failure so the
  /// UI can surface the error to the user instead of silently saving nothing.
  Future<String?> uploadImage(File file) {
    return ref.read(recipeServiceProvider).uploadImage(file);
  }
}

final recipeViewModelProvider = StreamNotifierProvider<RecipeNotifier, List<Recipe>>(
  RecipeNotifier.new,
);
