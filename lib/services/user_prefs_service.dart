import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

final userPrefsServiceProvider =
    Provider<UserPrefsService>((ref) => UserPrefsService());

/// Set once the user dismisses onboarding this session, so the gate advances
/// immediately even if persisting the flag to Firestore fails (e.g. rules not
/// yet set). Persistence still runs for future launches.
final onboardingDismissedProvider =
    NotifierProvider<OnboardingDismissedNotifier, bool>(
        OnboardingDismissedNotifier.new);

class OnboardingDismissedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

/// Whether the signed-in user has finished onboarding. A missing doc (brand
/// new account) reads as `false` so they see the intro once. No signed-in user
/// reads as `true` so the gate never blocks.
final onboardedProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(authServiceProvider).currentUser?.uid;
  if (uid == null) return Stream.value(true);
  return ref.watch(userPrefsServiceProvider).watchOnboarded(uid);
});

/// Small per-user preferences doc `user_prefs/{uid}`.
class UserPrefsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<bool> watchOnboarded(String uid) {
    return _db
        .collection('user_prefs')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['onboarded'] == true);
  }

  Future<void> setOnboarded(String uid) {
    return _db
        .collection('user_prefs')
        .doc(uid)
        .set({'onboarded': true}, SetOptions(merge: true));
  }
}
