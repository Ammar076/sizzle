import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recipe.dart';
import '../models/shopping_item.dart';
import '../services/auth_service.dart';
import '../services/collections_service.dart';
import '../services/notes_service.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../services/shopping_service.dart';
import '../theme/app_theme.dart';
import '../utils/ingredient_scaler.dart';
import '../viewmodels/recently_viewed.dart';
import '../viewmodels/recipe_viewmodel.dart';
import 'author_recipes_screen.dart';
import 'cooking_mode_screen.dart';
import 'create_recipe_screen.dart';
import 'main_shell.dart';
import 'widgets/collection_sheet.dart';
import 'widgets/recipe_card.dart';
import 'widgets/ui_kit.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final Recipe recipe;
  final String? heroTag;

  const RecipeDetailScreen({super.key, required this.recipe, this.heroTag});

  @override
  ConsumerState<RecipeDetailScreen> createState() =>
      _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  // The hero image flies in an overlay above the page and briefly covers the
  // top controls near the end of the flight. We keep the controls hidden until
  // the transition finishes, then fade them in cleanly — no flash, and the
  // favorite button never appears half-covered by the image.
  bool _controlsReady = false;
  // Dropped only when leaving via the shopping-list "View" action (the card is
  // on another tab, so a hero return would shrink the image into nothing).
  // Normal closes keep the hero and fade the shell chrome instead — see
  // [_close]. Opening always uses the hero.
  bool _heroEnabled = true;
  bool _closing = false; // guards against a double-pop from rapid back presses

  // Captured while mounted so the "Added to shopping list" snackbar's View
  // action still works after this screen is popped — the snackbar is owned by
  // the app-level ScaffoldMessenger and outlives us. Both survive disposal: the
  // tab notifier is app-scoped, the root navigator is app-level.
  SelectedTabNotifier? _tabNotifier;
  NavigatorState? _rootNav;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabNotifier = ref.read(selectedTabProvider.notifier);
    _rootNav = Navigator.of(context, rootNavigator: true);
  }

  @override
  void initState() {
    super.initState();
    // Record this open for the Home "Recently viewed" row (after the frame so
    // we don't mutate a provider mid-build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(recentlyViewedProvider.notifier).record(widget.recipe.id);
      }
    });
    // The hero image flies in an overlay above the whole page for the length
    // of the route transition, covering the top controls. Keep them hidden for
    // that entire window (wall-clock, so animation-status quirks can't leave
    // them showing), then fade them in over the settled image — no flash, and
    // the favorite button never appears half-covered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      // With reduced motion the transition is instant, so show controls now.
      if (route == null || MediaQuery.of(context).disableAnimations) {
        setState(() => _controlsReady = true);
        return;
      }
      // Reveal right as the flight lands. A tiny buffer avoids the overlay
      // still covering them; anything larger reads as a laggy pause.
      final reveal =
          route.transitionDuration + const Duration(milliseconds: 16);
      Future.delayed(reveal, () {
        if (mounted) setState(() => _controlsReady = true);
      });
    });
  }

  bool _isOwner(Recipe recipe) {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    return recipe.authorId != null && recipe.authorId == uid;
  }

  /// Closes the screen, keeping the hero return flight but fading the Home FAB
  /// and bottom nav out for its duration so the flying image (which rides in
  /// the top overlay, above them) never covers them or flashes them back.
  /// Routes every exit (back button + system back) through here.
  void _close() {
    if (_closing) return;
    _closing = true;
    // Only fade the chrome when a hero return will actually fly over it (and
    // not under reduced motion, where the transition is instant).
    if (widget.heroTag != null &&
        _heroEnabled &&
        !MediaQuery.of(context).disableAnimations) {
      final chrome = ref.read(chromeHiddenProvider.notifier);
      final flight = ModalRoute.of(context)?.transitionDuration ??
          const Duration(milliseconds: 300);
      chrome.set(true);
      // Restore once the flight has landed (the notifier outlives this widget,
      // so it still fires after we're popped).
      Future.delayed(flight + const Duration(milliseconds: 80),
          () => chrome.set(false));
    }
    Navigator.of(context).pop();
  }

  /// Switches to the Shopping tab and returns to the shell. Works whether this
  /// screen is still open (drop the hero so the image doesn't shrink into an
  /// off-tab card, then pop) or already closed (the snackbar outlives us — just
  /// switch tabs and unwind any routes back to the shell). Uses the captured
  /// notifier/navigator so it's safe to run after this state is disposed.
  void _viewShoppingList() {
    _tabNotifier?.select(1);
    if (mounted) {
      setState(() => _heroEnabled = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rootNav?.popUntil((route) => route.isFirst);
      });
    } else {
      _rootNav?.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final imageHeight = (screenHeight * 0.42).clamp(260.0, 420.0);
    final heroTag = widget.heroTag;

    // Resolve the freshest copy from the live list so state changes (e.g.
    // toggling favorite) update this screen immediately instead of only after
    // navigating away and back.
    final recipe = ref.watch(recipeViewModelProvider).maybeWhen(
          data: (list) => list.firstWhere((r) => r.id == widget.recipe.id,
              orElse: () => widget.recipe),
          orElse: () => widget.recipe,
        );

    // Only the creator may edit or delete a recipe.
    final currentUid = ref.watch(authServiceProvider).currentUser?.uid;
    final isOwner = recipe.authorId != null && recipe.authorId == currentUid;

    final useHero = heroTag != null && _heroEnabled;

    return PopScope(
      // Intercept system back so it also closes without the hero flight.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    useHero
                        ? Hero(
                            tag: heroTag,
                            child: RecipeImage(
                                imageUrl: recipe.imageUrl,
                                height: imageHeight),
                          )
                        : RecipeImage(
                            imageUrl: recipe.imageUrl, height: imageHeight),
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppRadii.sheet)),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: _content(context, recipe),
                        ),
                      ),
                    ),
                  ],
                ),
                // Favorite sits on the image/sheet seam and scrolls away with
                // the content, so it never floats over the recipe text. Held
                // hidden until the hero lands so it can't appear half-covered.
                Positioned(
                  right: 24,
                  top: imageHeight - 28,
                  child: _RevealControls(
                    visible: _controlsReady,
                    child: _FavoriteFab(recipe: recipe),
                  ),
                ),
              ],
            ),
          ),
          // Top action bar over the image.
          _RevealControls(
            visible: _controlsReady,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    _CircleButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: _close,
                      tooltip: 'Back',
                    ),
                    const Spacer(),
                    if (isOwner) ...[
                      _CircleButton(
                        icon: Icons.edit_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateRecipeScreen(recipe: recipe),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CircleButton(
                        icon: Icons.delete_outline_rounded,
                        onTap: () => _confirmDelete(context, ref, recipe),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _content(BuildContext context, Recipe recipe) {
    final cat = CategoryStyle.of(recipe.category);
    final total = recipe.prepTime + recipe.cookTime;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TagPill(label: recipe.category, tint: cat.tint, accent: cat.accent),
              if (recipe.difficulty != null)
                TagPill(
                  label: recipe.difficulty!,
                  tint: difficultyTint(recipe.difficulty!).$1,
                  accent: difficultyTint(recipe.difficulty!).$2,
                  icon: Icons.speed_rounded,
                ),
              if (recipe.cuisine != null && recipe.cuisine!.isNotEmpty)
                TagPill(
                  label: recipe.cuisine!,
                  tint: const Color(0xFFEDEDE7),
                  accent: AppColors.ink,
                  icon: Icons.public_rounded,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 56),
            child: Text(recipe.title,
                style: AppText.display(30, weight: FontWeight.w800, height: 1.1)),
          ),
          if (recipe.authorId != null && recipe.authorName != null) ...[
            const SizedBox(height: 16),
            _AuthorChip(
              authorId: recipe.authorId!,
              authorName: recipe.authorName!,
            ),
          ],
          _SavedCollectionsRow(recipe: recipe),
          if (recipe.ratingCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _StarsDisplay(value: recipe.averageRating, size: 18),
                const SizedBox(width: 8),
                Text(recipe.averageRating.toStringAsFixed(1),
                    style: AppText.sans(14, weight: FontWeight.w800)),
                const SizedBox(width: 6),
                Text(
                    '· ${recipe.ratingCount} ${recipe.ratingCount == 1 ? 'rating' : 'ratings'}',
                    style: AppText.sans(14, color: AppColors.muted)),
              ],
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.timer_outlined,
                  value: '$total min',
                  label: 'Total',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.local_fire_department_rounded,
                  value: '${recipe.cookTime} min',
                  label: 'Cook',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.people_alt_rounded,
                  value: '${recipe.feeds}',
                  label: 'Serves',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Primary action: jump straight into hands-free cooking. Only shown
          // when there's actually a method to walk through — a missing button
          // is an honest signal that the recipe has no steps.
          if (recipe.steps.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CookingModeScreen(recipe: recipe),
                  ),
                ),
                icon: const Icon(Icons.soup_kitchen_rounded),
                label: const Text('Start cooking'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Secondary actions, stacked full-width so labels never truncate.
          _SecondaryButton(
            icon: Icons.play_circle_outline_rounded,
            label: 'Watch tutorial',
            onTap: () => _watchTutorial(context, recipe),
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            icon: Icons.ios_share_rounded,
            label: 'Share recipe',
            onTap: () => _showExportSheet(context, recipe),
          ),
          if (!_isOwner(recipe)) ...[
            const SizedBox(height: 12),
            _SecondaryButton(
              icon: Icons.copy_all_rounded,
              label: 'Save a copy to my recipes',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CreateRecipeScreen(recipe: recipe, isCopy: true),
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text('About this recipe',
              style: AppText.display(18, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(recipe.description,
              style: AppText.sans(15, color: AppColors.muted, height: 1.65)),
          const SizedBox(height: 24),
          _NotesSection(recipeId: recipe.id),
          if (recipe.ingredients.isNotEmpty) ...[
            const SizedBox(height: 28),
            _IngredientsSection(
              recipe: recipe,
              onViewShoppingList: _viewShoppingList,
            ),
          ],
          if (recipe.steps.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('Method',
                style: AppText.display(18, weight: FontWeight.w800)),
            const SizedBox(height: 14),
            for (int i = 0; i < recipe.steps.length; i++)
              _StepRow(number: i + 1, text: recipe.steps[i]),
          ],
          const SizedBox(height: 28),
          _PrepBreakdown(prep: recipe.prepTime, cook: recipe.cookTime),
          const SizedBox(height: 28),
          // Rate at the end — after you've read (or made) the recipe.
          _RatingCard(recipe: recipe),
        ],
      ),
    );
  }

  Future<void> _watchTutorial(BuildContext context, Recipe recipe) async {
    final query = Uri.encodeComponent('${recipe.title} recipe tutorial');
    final url =
        Uri.parse('https://www.youtube.com/results?search_query=$query');
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open YouTube.')),
      );
    }
  }

  void _showExportSheet(BuildContext context, Recipe recipe) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Share recipe',
                  style: AppText.display(20, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Send “${recipe.title}” as text, or save it as a PDF.',
                  style: AppText.sans(14, color: AppColors.muted)),
              const SizedBox(height: 12),
              _ExportOption(
                icon: Icons.short_text_rounded,
                title: 'Share as text',
                subtitle: 'Send the recipe to any app or contact',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _runExport(context, () => ShareService.shareRecipe(recipe));
                },
              ),
              _ExportOption(
                icon: Icons.picture_as_pdf_rounded,
                title: 'Save as PDF',
                subtitle: 'Open the print dialog to save to your device',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _runExport(context, () => PdfService.printOrSave(recipe));
                },
              ),
              _ExportOption(
                icon: Icons.ios_share_rounded,
                title: 'Share as PDF',
                subtitle: 'Send a PDF file to another app',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _runExport(context, () => PdfService.share(recipe));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runExport(
      BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not share this recipe: $e')),
      );
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Recipe recipe) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('“${recipe.title}” will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !context.mounted) return;
    await ref.read(recipeViewModelProvider.notifier).deleteRecipe(recipe.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipe deleted.')),
    );
    Navigator.pop(context);
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatTile(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(value, style: AppText.sans(15, weight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: AppText.sans(12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// A small visual breakdown of prep vs cook time as a proportion bar.
class _PrepBreakdown extends StatelessWidget {
  final int prep;
  final int cook;
  const _PrepBreakdown({required this.prep, required this.cook});

  @override
  Widget build(BuildContext context) {
    final total = (prep + cook).clamp(1, 1 << 30);
    final prepFlex = prep == 0 ? 0 : prep;
    final cookFlex = cook == 0 ? 0 : cook;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time breakdown',
            style: AppText.display(18, weight: FontWeight.w800)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Row(
            children: [
              if (prepFlex > 0)
                Expanded(
                  flex: prepFlex,
                  child: Container(height: 12, color: AppColors.honey),
                ),
              if (cookFlex > 0)
                Expanded(
                  flex: cookFlex,
                  child: Container(height: 12, color: AppColors.primary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _LegendDot(color: AppColors.honey, label: 'Prep $prep min'),
            const SizedBox(width: 20),
            _LegendDot(color: AppColors.primary, label: 'Cook $cook min'),
            const Spacer(),
            Text('$total min total',
                style: AppText.sans(13,
                    weight: FontWeight.w700, color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 10,
          width: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppText.sans(13, color: AppColors.muted)),
      ],
    );
  }
}

/// Keeps the top controls (back/edit/delete + favorite) hidden until the hero
/// image has finished flying in, then fades them in over the settled image so
/// they never flash or appear half-covered by the overlay.
class _RevealControls extends StatelessWidget {
  final bool visible;
  final Widget child;
  const _RevealControls({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _CircleButton({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: AppColors.ink),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadii.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.input),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppColors.blush,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style:
                              AppText.sans(15, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: AppText.sans(13, color: AppColors.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only star row that shows [value] out of 5 with half-star precision.
class _StarsDisplay extends StatelessWidget {
  final double value;
  final double size;
  const _StarsDisplay({required this.value, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final position = i + 1;
        IconData icon;
        if (value >= position) {
          icon = Icons.star_rounded;
        } else if (value >= position - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: AppColors.honey);
      }),
    );
  }
}

/// Card showing the average rating and letting the current user tap to rate.
class _RatingCard extends ConsumerWidget {
  final Recipe recipe;
  const _RatingCard({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authServiceProvider).currentUser?.uid;
    final myRating = recipe.ratingBy(uid);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                recipe.ratingCount > 0
                    ? recipe.averageRating.toStringAsFixed(1)
                    : '–',
                style: AppText.display(30, weight: FontWeight.w800),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StarsDisplay(value: recipe.averageRating),
                    const SizedBox(height: 4),
                    Text(
                      recipe.ratingCount > 0
                          ? '${recipe.ratingCount} ${recipe.ratingCount == 1 ? 'rating' : 'ratings'}'
                          : 'No ratings yet',
                      style: AppText.sans(13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: AppColors.line),
          Text(myRating == null ? 'Tap to rate this recipe' : 'Your rating',
              style: AppText.sans(14, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (i) {
              final position = i + 1;
              final filled = myRating != null && position <= myRating;
              return GestureDetector(
                onTap: uid == null
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(recipeViewModelProvider.notifier)
                            .setRating(recipe, uid, position);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            duration: const Duration(milliseconds: 1400),
                            content: Text('You rated this $position★'),
                          ));
                      },
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 36,
                    color: AppColors.honey,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Appears once a recipe is saved (favorited) or already filed somewhere, and
/// is the single, visible home for organizing it into collections — so
/// collections are never hidden behind a separate button. The heart FAB stays
/// the one save control; this row handles the optional "...into a group" step.
class _SavedCollectionsRow extends ConsumerWidget {
  final Recipe recipe;
  const _SavedCollectionsRow({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authServiceProvider).currentUser?.uid;
    final fav = recipe.isFavoritedBy(uid);
    final collections =
        ref.watch(collectionsProvider).asData?.value ?? const {};
    final inCollections = [
      for (final entry in collections.entries)
        if (entry.value.contains(recipe.id)) entry.key
    ]..sort();

    // Only surfaces once the recipe is in the user's library.
    if (!fav && inCollections.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 13, 14, 15),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(fav ? Icons.favorite_rounded : Icons.folder_rounded,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(fav ? 'Saved' : 'In collections',
                  style: AppText.sans(14,
                      weight: FontWeight.w800,
                      color: AppColors.primaryPressed)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  inCollections.isEmpty
                      ? '· add it to a collection'
                      : '· ${inCollections.length} ${inCollections.length == 1 ? 'collection' : 'collections'}',
                  style: AppText.sans(13, color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in inCollections)
                _CollectionChip(
                  label: name,
                  onRemove: uid == null
                      ? null
                      : () => ref
                          .read(collectionsServiceProvider)
                          .setMembership(
                              uid, collections, name, recipe.id, false),
                ),
              _AddChip(onTap: () => showCollectionSheet(context, recipe.id)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionChip extends StatelessWidget {
  final String label;
  final VoidCallback? onRemove;
  const _CollectionChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.sans(13, weight: FontWeight.w700)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Tooltip(
              message: 'Remove from $label',
              child: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text('Add',
                style: AppText.sans(13,
                    weight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// A private, per-user note for this recipe (e.g. "I doubled the garlic").
/// Stored in `user_notes/{uid}`; never shown to other cooks.
class _NotesSection extends ConsumerWidget {
  final String recipeId;
  const _NotesSection({required this.recipeId});

  Future<void> _edit(
      BuildContext context, WidgetRef ref, String existing) async {
    final controller = TextEditingController(text: existing);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('My notes', style: AppText.display(20, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Private to you — not shown to other cooks.',
                style: AppText.sans(13, color: AppColors.muted)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. I doubled the garlic and used less salt.',
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => Navigator.pop(sheetContext, controller.text),
              child: const Text('Save note'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) {
      await ref.read(notesServiceProvider).setNote(uid, recipeId, result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(notesProvider).asData?.value[recipeId] ?? '';
    final hasNote = note.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.sage,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_outlined,
                  size: 18, color: AppColors.forest),
              const SizedBox(width: 8),
              Text('My notes',
                  style: AppText.display(17, weight: FontWeight.w800)),
              const Spacer(),
              TextButton(
                onPressed: () => _edit(context, ref, note),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.forest,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(hasNote ? 'Edit' : 'Add'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (hasNote)
            Text(note,
                style: AppText.sans(15, color: AppColors.ink, height: 1.55))
          else
            Text('Add a private note, tweaks, swaps, reminders.',
                style: AppText.sans(14, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Ingredients with a serving scaler (adjusts quantities), a tap-to-check
/// list, and an "add all to shopping list" action.
class _IngredientsSection extends ConsumerStatefulWidget {
  final Recipe recipe;
  final VoidCallback onViewShoppingList;
  const _IngredientsSection(
      {required this.recipe, required this.onViewShoppingList});

  @override
  ConsumerState<_IngredientsSection> createState() =>
      _IngredientsSectionState();
}

class _IngredientsSectionState extends ConsumerState<_IngredientsSection> {
  late int _servings;
  final Set<int> _checked = {};

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.feeds < 1 ? 1 : widget.recipe.feeds;
  }

  double get _factor {
    final base = widget.recipe.feeds;
    return base <= 0 ? 1 : _servings / base;
  }

  List<String> get _scaled => widget.recipe.ingredients
      .map((e) => scaleIngredient(e, _factor))
      .toList();

  Future<void> _addToShoppingList() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    final current = ref.read(shoppingListProvider).asData?.value ?? const [];
    final additions = _scaled.map((t) => ShoppingItem(text: t));
    await ref
        .read(shoppingServiceProvider)
        .save(uid, [...current, ...additions]);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Added ${_scaled.length} items to your shopping list'),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: widget.onViewShoppingList,
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final scaled = _scaled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Ingredients',
                style: AppText.display(18, weight: FontWeight.w800)),
            const Spacer(),
            _ServingStepper(
              servings: _servings,
              onChanged: (v) => setState(() {
                _servings = v;
                _checked.clear();
              }),
            ),
          ],
        ),
        if (_servings != widget.recipe.feeds) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 14, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Adjusted from ${widget.recipe.feeds} '
                  '${widget.recipe.feeds == 1 ? 'serving' : 'servings'}',
                  style: AppText.sans(12, color: AppColors.muted),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _servings = widget.recipe.feeds < 1 ? 1 : widget.recipe.feeds;
                  _checked.clear();
                }),
                child: Text('Reset',
                    style: AppText.sans(12,
                        weight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        for (int i = 0; i < scaled.length; i++) _row(i, scaled[i]),
        const SizedBox(height: 14),
        _SecondaryButton(
          icon: Icons.add_shopping_cart_rounded,
          label: 'Add to shopping list',
          onTap: _addToShoppingList,
        ),
      ],
    );
  }

  Widget _row(int i, String text) {
    final checked = _checked.contains(i);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        if (checked) {
          _checked.remove(i);
        } else {
          _checked.add(i);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 24,
              width: 24,
              margin: const EdgeInsets.only(top: 1, right: 12),
              decoration: BoxDecoration(
                color: checked ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: checked ? AppColors.primary : AppColors.line,
                    width: 1.6),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : null,
            ),
            Expanded(
              child: Text(
                text,
                style: AppText.sans(15,
                    color: checked ? AppColors.muted : AppColors.ink,
                    height: 1.5,
                    weight: FontWeight.w500).copyWith(
                  decoration:
                      checked ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact "− N serving(s) +" stepper.
class _ServingStepper extends StatelessWidget {
  final int servings;
  final ValueChanged<int> onChanged;
  const _ServingStepper({required this.servings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepButton(Icons.remove_rounded,
              servings > 1 ? () => onChanged(servings - 1) : null),
          Text('$servings ${servings == 1 ? 'serving' : 'servings'}',
              style: AppText.sans(13, weight: FontWeight.w700)),
          _stepButton(Icons.add_rounded,
              servings < 50 ? () => onChanged(servings + 1) : null),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      color: AppColors.primary,
      disabledColor: AppColors.line,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final String text;
  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 30,
            width: 30,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: AppColors.blush,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text('$number',
                style: AppText.sans(14,
                    weight: FontWeight.w800, color: AppColors.primaryPressed)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text,
                  style: AppText.sans(15, color: AppColors.ink, height: 1.6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorChip extends StatelessWidget {
  final String authorId;
  final String authorName;
  const _AuthorChip({required this.authorId, required this.authorName});

  @override
  Widget build(BuildContext context) {
    final initial = authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AuthorRecipesScreen(
            authorId: authorId,
            authorName: authorName,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: const BoxDecoration(
              color: AppColors.blush,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(initial,
                style: AppText.sans(13,
                    color: AppColors.primaryPressed, weight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Text('Made by ', style: AppText.sans(14, color: AppColors.muted)),
          Flexible(
            child: Text(authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(14,
                    weight: FontWeight.w700, color: AppColors.primary)),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forest,
          side: const BorderSide(color: AppColors.line),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.button)),
          textStyle: AppText.sans(14, weight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _FavoriteFab extends ConsumerWidget {
  final Recipe recipe;
  const _FavoriteFab({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authServiceProvider).currentUser?.uid;
    final fav = recipe.isFavoritedBy(uid);
    return Tooltip(
      message: fav ? 'Remove from favorites' : 'Add to favorites',
      child: Semantics(
        button: true,
        label: fav ? 'Remove from favorites' : 'Add to favorites',
        child: Material(
          color: fav ? Colors.white : AppColors.primary,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: AppColors.primary.withValues(alpha: 0.5),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => toggleFavoriteWithFeedback(context, ref, recipe),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(
                fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: fav ? AppColors.primary : Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
