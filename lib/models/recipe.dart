import 'package:cloud_firestore/cloud_firestore.dart';

class Recipe {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String category; // 'breakfast', 'lunch', 'dinner'
  final List<String> favoritedBy; // uids of users who favorited this recipe
  final int prepTime;
  final int cookTime;
  final int feeds;
  final DateTime? createdAt;
  final String? authorId;
  final String? authorName;
  final List<String> ingredients;
  final List<String> steps;
  final Map<String, int> ratings; // uid -> stars (1..5)
  final String? cuisine;
  final String? difficulty; // 'Easy' | 'Medium' | 'Hard'

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    this.favoritedBy = const [],
    required this.prepTime,
    required this.cookTime,
    required this.feeds,
    this.createdAt,
    this.authorId,
    this.authorName,
    this.ingredients = const [],
    this.steps = const [],
    this.ratings = const {},
    this.cuisine,
    this.difficulty,
  });

  /// Whether [uid] has favorited this recipe. Favorites are per-user.
  bool isFavoritedBy(String? uid) => uid != null && favoritedBy.contains(uid);

  /// Average of all star ratings (0 when none).
  double get averageRating {
    if (ratings.isEmpty) return 0;
    final sum = ratings.values.fold<int>(0, (a, b) => a + b);
    return sum / ratings.length;
  }

  int get ratingCount => ratings.length;

  /// The current user's own star rating, or null if they haven't rated.
  int? ratingBy(String? uid) => uid == null ? null : ratings[uid];

  factory Recipe.fromFirestore(Map<String, dynamic> data, String id) {
    final rawCreatedAt = data['createdAt'];
    return Recipe(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      category: data['category'] ?? '',
      favoritedBy: (data['favoritedBy'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      prepTime: data['prepTime'] ?? 0,
      cookTime: data['cookTime'] ?? 0,
      feeds: data['feeds'] ?? 0,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      authorId: data['authorId'],
      authorName: data['authorName'],
      ingredients: (data['ingredients'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      steps: (data['steps'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      ratings: (data['ratings'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
          const {},
      cuisine: data['cuisine'],
      difficulty: data['difficulty'],
    );
  }

  /// Fields written on every add/update. [createdAt] is intentionally excluded
  /// so an edit never overwrites the original creation time (it is set once,
  /// with a server timestamp, when the recipe is first added).
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'category': category,
      'favoritedBy': favoritedBy,
      'prepTime': prepTime,
      'cookTime': cookTime,
      'feeds': feeds,
      'authorId': authorId,
      'authorName': authorName,
      'ingredients': ingredients,
      'steps': steps,
      'ratings': ratings,
      'cuisine': cuisine,
      'difficulty': difficulty,
    };
  }

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? category,
    List<String>? favoritedBy,
    int? prepTime,
    int? cookTime,
    int? feeds,
    DateTime? createdAt,
    String? authorId,
    String? authorName,
    List<String>? ingredients,
    List<String>? steps,
    Map<String, int>? ratings,
    String? cuisine,
    String? difficulty,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      favoritedBy: favoritedBy ?? this.favoritedBy,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      feeds: feeds ?? this.feeds,
      createdAt: createdAt ?? this.createdAt,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      ratings: ratings ?? this.ratings,
      cuisine: cuisine ?? this.cuisine,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}
