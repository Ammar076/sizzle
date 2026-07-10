import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';

/// Shares a recipe as plain text via the OS share sheet — a lightweight
/// alternative to the PDF export for "send this to a friend".
class ShareService {
  static Future<void> shareRecipe(Recipe recipe) async {
    final b = StringBuffer();
    b.writeln(recipe.title);
    if (recipe.description.trim().isNotEmpty) {
      b.writeln();
      b.writeln(recipe.description.trim());
    }

    final total = recipe.prepTime + recipe.cookTime;
    final meta = <String>[
      '$total min',
      'Serves ${recipe.feeds}',
      if (recipe.difficulty != null && recipe.difficulty!.isNotEmpty)
        recipe.difficulty!,
    ];
    b.writeln();
    b.writeln(meta.join(' · '));

    if (recipe.ingredients.isNotEmpty) {
      b.writeln();
      b.writeln('Ingredients');
      for (final ing in recipe.ingredients) {
        b.writeln('• $ing');
      }
    }

    if (recipe.steps.isNotEmpty) {
      b.writeln();
      b.writeln('Method');
      for (var i = 0; i < recipe.steps.length; i++) {
        b.writeln('${i + 1}. ${recipe.steps[i]}');
      }
    }

    b.writeln();
    b.writeln('Shared from Sizzle Recipes');

    await SharePlus.instance.share(
      ShareParams(text: b.toString(), subject: recipe.title),
    );
  }
}
