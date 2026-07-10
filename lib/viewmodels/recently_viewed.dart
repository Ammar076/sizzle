import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the recipes opened this session, most-recent first. Kept in memory
/// (no persistence) so the Home "Recently viewed" row reflects the current
/// browsing session and resets on a fresh launch.
class RecentlyViewedNotifier extends Notifier<List<String>> {
  static const _max = 10;

  @override
  List<String> build() => const [];

  /// Records that [recipeId] was opened, moving it to the front and capping
  /// the list length.
  void record(String recipeId) {
    if (recipeId.isEmpty) return;
    final next = [recipeId, ...state.where((id) => id != recipeId)];
    state = next.length > _max ? next.sublist(0, _max) : next;
  }
}

final recentlyViewedProvider =
    NotifierProvider<RecentlyViewedNotifier, List<String>>(
        RecentlyViewedNotifier.new);
