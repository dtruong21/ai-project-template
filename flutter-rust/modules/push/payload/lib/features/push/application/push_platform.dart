import 'package:app/core/bootstrap.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PushPermission { notDetermined, denied, granted }

/// The slice of Firebase Messaging the app uses. An interface so the
/// controller can be tested without Firebase (it needs a real device).
abstract interface class PushPlatform {
  Future<PushPermission> permission();

  /// Shows the system permission dialog the first time; afterwards just
  /// reports the current answer.
  Future<PushPermission> requestPermission();

  /// Whether this install is set up to receive pushes. Persisted by Firebase,
  /// so "the user turned notifications off" survives a restart.
  bool get enabled;
  Future<void> setEnabled({required bool enabled});

  /// This device's FCM token, or `null` if none could be issued.
  Future<String?> token();
  Future<void> deleteToken();

  /// Fires when Firebase rotates the token; register the new one.
  Stream<String> get onTokenRefresh;
}

class FirebasePushPlatform implements PushPlatform {
  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  static PushPermission _map(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };

  @override
  Future<PushPermission> permission() async =>
      _map((await _fm.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _map((await _fm.requestPermission()).authorizationStatus);

  @override
  bool get enabled => _fm.isAutoInitEnabled;

  @override
  Future<void> setEnabled({required bool enabled}) async {
    await _fm.setAutoInitEnabled(enabled);
    if (enabled) {
      // iOS shows nothing while the app is open unless asked to.
      await _fm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  @override
  Future<String?> token() => _fm.getToken();

  @override
  Future<void> deleteToken() => _fm.deleteToken();

  @override
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;
}

/// `null` until Firebase is configured (see `firebaseReadyProvider`); the
/// notifications switch then shows as unavailable instead of crashing.
final pushPlatformProvider = Provider<PushPlatform?>(
  (ref) => ref.watch(firebaseReadyProvider) ? FirebasePushPlatform() : null,
);
