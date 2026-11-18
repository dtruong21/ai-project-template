import 'package:app/core/api/api_client.dart';
import 'package:app/core/bootstrap.dart';
import 'package:app/features/feedback/application/my_feedback_provider.dart';
import 'package:app/features/settings/application/profile_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Deletes the Firebase Auth user and starts a fresh anonymous session.
/// A provider so tests can replace it (no Firebase in unit tests).
final authUserResetProvider = Provider<Future<void> Function()>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  return () async {
    if (!firebaseReady) return;
    await FirebaseAuth.instance.currentUser?.delete();
    await FirebaseAuth.instance.signInAnonymously();
  };
});

/// Erases the account. Order matters:
///   1. server data, while the ID token is still valid;
///   2. the auth user;
///   3. everything cached in memory.
/// If step 1 fails nothing has been deleted and the error propagates.
final deleteAccountProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(apiClientProvider).delete('/v1/account');
    await ref.read(authUserResetProvider)();
    ref
      ..invalidate(profileProvider)
      ..invalidate(myFeedbackProvider);
  };
});
