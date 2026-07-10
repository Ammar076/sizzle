import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

final collectionsServiceProvider =
    Provider<CollectionsService>((ref) => CollectionsService());

/// The signed-in user's recipe collections: name -> list of recipe ids.
final collectionsProvider =
    StreamProvider<Map<String, List<String>>>((ref) {
  final uid = ref.watch(authServiceProvider).currentUser?.uid;
  if (uid == null) return Stream.value(const {});
  return ref.watch(collectionsServiceProvider).watch(uid);
});

/// Stores named recipe collections in a single doc `user_collections/{uid}`
/// under a `collections` map. Read-modify-write from the caller's current
/// snapshot keeps it simple for a personal, small dataset.
class CollectionsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Map<String, List<String>>> watch(String uid) {
    return _db.collection('user_collections').doc(uid).snapshots().map((doc) {
      final raw = (doc.data()?['collections'] as Map?) ?? const {};
      return raw.map((k, v) => MapEntry(
            k.toString(),
            (v as List?)?.map((e) => e.toString()).toList() ?? <String>[],
          ));
    });
  }

  Future<void> save(String uid, Map<String, List<String>> collections) {
    return _db
        .collection('user_collections')
        .doc(uid)
        .set({'collections': collections});
  }

  Future<void> delete(
      String uid, Map<String, List<String>> current, String name) {
    return save(uid, {...current}..remove(name));
  }

  Future<void> rename(String uid, Map<String, List<String>> current,
      String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty ||
        !current.containsKey(oldName) ||
        current.containsKey(trimmed)) {
      return Future.value();
    }
    final next = <String, List<String>>{};
    current.forEach((k, v) => next[k == oldName ? trimmed : k] = v);
    return save(uid, next);
  }

  Future<void> setMembership(String uid, Map<String, List<String>> current,
      String name, String recipeId, bool inCollection) {
    final list = [...(current[name] ?? const <String>[])];
    if (inCollection) {
      if (!list.contains(recipeId)) list.add(recipeId);
    } else {
      list.remove(recipeId);
    }
    return save(uid, {...current, name: list});
  }
}
