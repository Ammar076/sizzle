import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shopping_item.dart';
import 'auth_service.dart';

final shoppingServiceProvider =
    Provider<ShoppingService>((ref) => ShoppingService());

/// The signed-in user's shopping list, streamed from Firestore.
final shoppingListProvider = StreamProvider<List<ShoppingItem>>((ref) {
  final uid = ref.watch(authServiceProvider).currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(shoppingServiceProvider).watch(uid);
});

/// Stores each user's shopping list as a single document
/// `shopping_lists/{uid}` with an `items` array — simple and cheap for a
/// personal list.
class ShoppingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ShoppingItem>> watch(String uid) {
    return _db.collection('shopping_lists').doc(uid).snapshots().map((doc) {
      final items = (doc.data()?['items'] as List?) ?? const [];
      return items
          .map((e) => ShoppingItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    });
  }

  Future<void> save(String uid, List<ShoppingItem> items) {
    return _db.collection('shopping_lists').doc(uid).set({
      'items': items.map((e) => e.toMap()).toList(),
    });
  }
}
