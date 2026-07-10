import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/recipe_viewmodel.dart';
import 'recipe_detail_screen.dart';
import 'widgets/error_state.dart';
import 'widgets/recipe_card.dart';
import 'widgets/skeletons.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingPhoto = false;

  Future<void> _changePhoto() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _uploadingPhoto = true);
      final ref0 = FirebaseStorage.instance.ref('profile_images/$uid.jpg');
      await ref0.putFile(File(picked.path));
      final url = await ref0.getDownloadURL();
      await ref.read(authServiceProvider).updatePhotoUrl(url);
      if (mounted) setState(() => _uploadingPhoto = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update photo: $e')),
      );
    }
  }

  Future<void> _editName() async {
    final auth = ref.read(authServiceProvider);
    final controller = TextEditingController(text: auth.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Chef Alex'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;
    await auth.updateDisplayName(newName);
    if (mounted) setState(() {}); // refresh with the new name
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sign out?',
                  style: AppText.display(20, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('You will need to sign in again to continue.',
                  style: AppText.sans(15, color: AppColors.muted)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: const Text('Sign out'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldSignOut == true) {
      // The auth gate reacts to sign-out and swaps back to the login screen.
      await ref.read(authServiceProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final recipesState = ref.watch(recipeViewModelProvider);
    final name = auth.displayName;
    final email = auth.currentUser?.email ?? '';
    final uid = auth.currentUser?.uid;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recipeViewModelProvider);
          await ref.read(recipeViewModelProvider.future);
        },
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // The header comes from auth (available immediately), so it shows
            // right away while the recipe-derived sections load below it.
            _header(name, email, initial, auth.photoUrl),
            const SizedBox(height: 20),
            recipesState.when(
              data: (recipes) {
                final mine = recipes
                    .where((r) => uid != null && r.authorId == uid)
                    .toList();
                final favorites =
                    recipes.where((r) => r.isFavoritedBy(uid)).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                              value: '${mine.length}', label: 'My recipes'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                              value: '$favorites', label: 'Favorites'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text('My recipes',
                        style: AppText.display(19, weight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    if (mine.isEmpty)
                      _emptyMyRecipes()
                    else
                      ...mine.map((recipe) => RecipeCard(
                            recipe: recipe,
                            heroTag: 'me_${recipe.id}',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecipeDetailScreen(
                                    recipe: recipe,
                                    heroTag: 'me_${recipe.id}'),
                              ),
                            ),
                          )),
                  ],
                );
              },
              loading: () => const RecipeListSkeleton(
                count: 2,
                padding: EdgeInsets.only(top: 8),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ErrorState(
                  message: "We couldn't load your recipes.",
                  onRetry: () => ref.invalidate(recipeViewModelProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialAvatar(String initial) {
    return Center(
      child: Text(initial,
          style: AppText.display(26,
              color: AppColors.primaryPressed, weight: FontWeight.w800)),
    );
  }

  Widget _header(String name, String email, String initial, String? photoUrl) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _uploadingPhoto ? null : _changePhoto,
            child: SizedBox(
              height: 66,
              width: 66,
              child: Stack(
                children: [
                  Container(
                    height: 66,
                    width: 66,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: AppColors.blush,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _uploadingPhoto
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : (photoUrl != null && photoUrl.isNotEmpty)
                            ? Image.network(photoUrl,
                                fit: BoxFit.cover,
                                height: 66,
                                width: 66,
                                errorBuilder: (_, _, _) => _initialAvatar(initial))
                            : _initialAvatar(initial),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 22,
                      width: 22,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
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
                Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(14, color: AppColors.muted)),
              ],
            ),
          ),
          IconButton(
            onPressed: _editName,
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
            tooltip: 'Edit name',
          ),
        ],
      ),
    );
  }

  Widget _emptyMyRecipes() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(Icons.menu_book_rounded,
              size: 40, color: AppColors.muted.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text("You haven't added any recipes yet.",
              textAlign: TextAlign.center,
              style: AppText.sans(14, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Text(value, style: AppText.display(26, weight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: AppText.sans(13, color: AppColors.muted)),
        ],
      ),
    );
  }
}
