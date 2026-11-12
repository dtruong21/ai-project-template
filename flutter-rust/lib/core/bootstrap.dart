/// Startup wiring that `main.dart` runs before the first frame.
library;

import 'package:app/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether Firebase initialized. `false` until `flutterfire configure` has
/// replaced the placeholder `lib/firebase_options.dart`. Overridden in
/// `main.dart`; widgets and the API client read it instead of touching
/// `Firebase.apps`.
final firebaseReadyProvider = Provider<bool>((ref) => false);

/// Initializes Firebase and signs in anonymously so every user has a uid from
/// the first launch (link it to a real account later — the uid is preserved).
///
/// Returns `false` instead of throwing when Firebase is not configured or the
/// sign-in fails (offline first launch), so the app always boots.
Future<bool> initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError catch (e) {
    debugPrint('[bootstrap] Firebase skipped: ${e.message}');
    return false;
  }
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } on FirebaseAuthException catch (e) {
    // Offline or Anonymous sign-in not enabled in the Firebase console.
    debugPrint('[bootstrap] anonymous sign-in failed: ${e.code}');
  }
  return true;
}
