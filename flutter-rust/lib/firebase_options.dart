// PLACEHOLDER — replaced by `flutterfire configure` (SETUP.md Step 3).
//
// Until then the app still runs: `main.dart` catches the error below, skips
// Firebase, and the home screen shows "Firebase: not configured". Signed-in
// features (anything that calls the API) report "sign in required".
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase is not configured. Run: flutterfire configure',
  );
}
