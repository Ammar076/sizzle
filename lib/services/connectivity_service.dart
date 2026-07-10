import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` when the app is serving Firestore data from its local cache
/// instead of the server — i.e. the device is effectively offline. Uses
/// snapshot metadata (`isFromCache`) rather than a network plugin, so it
/// reflects Firestore's real sync state, and includes metadata changes so it
/// flips back as soon as the connection returns.
final offlineProvider = StreamProvider<bool>((ref) {
  return FirebaseFirestore.instance
      .collection('recipes')
      .snapshots(includeMetadataChanges: true)
      .map((snap) => snap.metadata.isFromCache);
});
