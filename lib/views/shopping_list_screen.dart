import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shopping_item.dart';
import '../services/auth_service.dart';
import '../services/shopping_service.dart';
import '../theme/app_theme.dart';
import 'widgets/error_state.dart';
import 'widgets/skeletons.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  String? get _uid => ref.read(authServiceProvider).currentUser?.uid;

  Future<void> _save(List<ShoppingItem> items) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(shoppingServiceProvider).save(uid, items);
  }

  void _add(List<ShoppingItem> current) {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    _save([...current, ShoppingItem(text: text)]);
    _addController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(shoppingListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping list'),
        actions: [
          listState.maybeWhen(
            data: (items) => items.any((i) => i.checked)
                ? TextButton(
                    onPressed: () =>
                        _save(items.where((i) => !i.checked).toList()),
                    child: const Text('Clear done'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: listState.maybeWhen(
              data: (items) => TextField(
                controller: _addController,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _add(items),
                decoration: InputDecoration(
                  hintText: 'Add an item…',
                  prefixIcon: const Icon(Icons.add_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_rounded,
                        color: AppColors.primary),
                    onPressed: () => _add(items),
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
          listState.maybeWhen(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : _ProgressLine(items: items),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: listState.when(
              data: (items) {
                if (items.isEmpty) return const _EmptyList();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.line),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Dismissible(
                      key: ValueKey('$index-${item.text}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: AppColors.blush,
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.primaryPressed),
                      ),
                      onDismissed: (_) {
                        final next = [...items]..removeAt(index);
                        _save(next);
                      },
                      child: _ItemRow(
                        item: item,
                        onToggle: () {
                          HapticFeedback.selectionClick();
                          final next = [...items];
                          next[index] =
                              item.copyWith(checked: !item.checked);
                          _save(next);
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const ListRowsSkeleton(),
              error: (error, _) => ErrorState(
                message: "We couldn't load your shopping list.",
                onRetry: () => ref.invalidate(shoppingListProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact "N of M · gathered" summary with a progress bar, shown above the
/// list so shoppers can see how far along they are at a glance.
class _ProgressLine extends StatelessWidget {
  final List<ShoppingItem> items;
  const _ProgressLine({required this.items});

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final done = items.where((i) => i.checked).length;
    final pct = total == 0 ? 0.0 : done / total;
    final allDone = done == total && total > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$done of $total',
                  style: AppText.sans(13, weight: FontWeight.w800)),
              const SizedBox(width: 6),
              Text(allDone ? 'all gathered' : 'gathered',
                  style: AppText.sans(13, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.line,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;
  const _ItemRow({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 24,
              width: 24,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: item.checked ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: item.checked ? AppColors.primary : AppColors.line,
                    width: 1.6),
              ),
              child: item.checked
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : null,
            ),
            Expanded(
              child: Text(
                item.text,
                style: AppText.sans(15,
                    weight: FontWeight.w500,
                    color: item.checked ? AppColors.muted : AppColors.ink).copyWith(
                  decoration: item.checked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
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

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 56, color: AppColors.muted.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            Text('Your list is empty',
                style: AppText.display(20, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Add items above, or tap “Add to shopping list” on a recipe.',
              textAlign: TextAlign.center,
              style: AppText.sans(14, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
