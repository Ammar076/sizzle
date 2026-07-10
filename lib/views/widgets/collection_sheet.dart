import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/collections_service.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet for adding/removing a recipe to/from the user's collections,
/// with an inline "new collection" field.
Future<void> showCollectionSheet(BuildContext context, String recipeId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CollectionSheet(recipeId: recipeId),
  );
}

class _CollectionSheet extends ConsumerStatefulWidget {
  final String recipeId;
  const _CollectionSheet({required this.recipeId});

  @override
  ConsumerState<_CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends ConsumerState<_CollectionSheet> {
  final _newController = TextEditingController();

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  void _createAndAdd(Map<String, List<String>> current) {
    final name = _newController.text.trim();
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (name.isEmpty || uid == null || current.containsKey(name)) return;
    // Create the collection with this recipe already inside — a single write.
    ref
        .read(collectionsServiceProvider)
        .save(uid, {...current, name: [widget.recipeId]});
    _newController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(collectionsProvider);
    final uid = ref.watch(authServiceProvider).currentUser?.uid;
    final service = ref.read(collectionsServiceProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
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
            Text('Save to collection',
                style: AppText.display(20, weight: FontWeight.w800)),
            const SizedBox(height: 12),
            collectionsAsync.when(
              data: (collections) {
                final names = collections.keys.toList()..sort();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (names.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('No collections yet, create one below.',
                            style: AppText.sans(14, color: AppColors.muted)),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final name in names)
                              _CollectionRow(
                                name: name,
                                count: collections[name]!.length,
                                checked:
                                    collections[name]!.contains(widget.recipeId),
                                onTap: uid == null
                                    ? null
                                    : () => service.setMembership(
                                          uid,
                                          collections,
                                          name,
                                          widget.recipeId,
                                          !collections[name]!
                                              .contains(widget.recipeId),
                                        ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _createAndAdd(collections),
                      decoration: InputDecoration(
                        hintText: 'New collection…',
                        prefixIcon: const Icon(Icons.create_new_folder_outlined),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_rounded,
                              color: AppColors.primary),
                          onPressed: () => _createAndAdd(collections),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Could not load your collections.',
                    style: AppText.sans(14, color: AppColors.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  final String name;
  final int count;
  final bool checked;
  final VoidCallback? onTap;
  const _CollectionRow({
    required this.name,
    required this.count,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(
              checked
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: checked ? AppColors.primary : AppColors.line,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(name,
                  style: AppText.sans(15, weight: FontWeight.w700)),
            ),
            Text('$count',
                style: AppText.sans(13, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
