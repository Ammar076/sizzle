import 'dart:async';
import 'dart:io';
import '../models/recipe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

abstract class RecipeService {
  Stream<List<Recipe>> getRecipes();

  /// Adds or removes [uid] from a recipe's favorites (favorites are per-user).
  Future<void> setFavorite(String recipeId, String uid, bool favorite);

  /// Records [uid]'s star rating (1..5) for a recipe.
  Future<void> setRating(String recipeId, String uid, int stars);
  Future<void> addRecipe(Recipe recipe);
  Future<void> updateRecipe(Recipe recipe);
  Future<void> deleteRecipe(String recipeId);

  /// Uploads a picked image file to storage and returns a URL/reference that
  /// can be saved on the recipe. Returns null when the platform can't upload.
  Future<String?> uploadImage(File file);
}

/// Sorts recipes newest-first. Recipes without a [Recipe.createdAt] (older
/// documents created before this field existed) are pushed to the end. Sorting
/// on the client — rather than a Firestore `orderBy` — guarantees documents
/// missing the field still appear instead of being silently dropped.
List<Recipe> sortByNewest(List<Recipe> recipes) {
  final sorted = [...recipes];
  sorted.sort((a, b) {
    final aDate = a.createdAt;
    final bDate = b.createdAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });
  return sorted;
}

class FirestoreRecipeService implements RecipeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Stream<List<Recipe>> getRecipes() {
    return _db.collection('recipes').snapshots().map((snapshot) => sortByNewest(
        snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc.data(), doc.id))
            .toList()));
  }

  @override
  Future<void> setFavorite(String recipeId, String uid, bool favorite) async {
    await _db.collection('recipes').doc(recipeId).update({
      'favoritedBy': favorite
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Future<void> setRating(String recipeId, String uid, int stars) async {
    // Dot-path update sets just this user's entry in the ratings map.
    await _db.collection('recipes').doc(recipeId).update({
      'ratings.$uid': stars,
    });
  }

  @override
  Future<void> addRecipe(Recipe recipe) async {
    await _db.collection('recipes').add({
      ...recipe.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateRecipe(Recipe recipe) async {
    await _db.collection('recipes').doc(recipe.id).update(recipe.toFirestore());
  }

  @override
  Future<void> deleteRecipe(String recipeId) async {
    await _db.collection('recipes').doc(recipeId).delete();
  }

  @override
  Future<String?> uploadImage(File file) async {
    final fileName =
        'recipe_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(fileName);
    final uploadTask = await ref.putFile(file);
    return uploadTask.ref.getDownloadURL();
  }
}
