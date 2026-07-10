import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

final notesServiceProvider = Provider<NotesService>((ref) => NotesService());

/// The signed-in user's private per-recipe notes, keyed by recipe id.
final notesProvider = StreamProvider<Map<String, String>>((ref) {
  final uid = ref.watch(authServiceProvider).currentUser?.uid;
  if (uid == null) return Stream.value(const {});
  return ref.watch(notesServiceProvider).watch(uid);
});

/// Stores personal recipe notes in a single doc `user_notes/{uid}` under a
/// `notes` map (recipeId -> text). Private to each user.
class NotesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Map<String, String>> watch(String uid) {
    return _db.collection('user_notes').doc(uid).snapshots().map((doc) {
      final raw = (doc.data()?['notes'] as Map?) ?? const {};
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    });
  }

  Future<void> setNote(String uid, String recipeId, String text) {
    final doc = _db.collection('user_notes').doc(uid);
    final trimmed = text.trim();
    // Merge writes just this recipe's entry; an empty note removes it.
    return doc.set({
      'notes': {recipeId: trimmed.isEmpty ? FieldValue.delete() : trimmed},
    }, SetOptions(merge: true));
  }
}
