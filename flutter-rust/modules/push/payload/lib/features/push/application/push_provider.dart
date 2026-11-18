import 'dart:async';

import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/push/application/push_platform.dart';
import 'package:app/src/rust/api/push.dart' as rust;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'push_provider.g.dart';

/// Builds the request bodies with the Rust rules. A provider so tests can
/// replace it (they cannot load the Rust library).
class PushPayloads {
  const PushPayloads();

  String registration(String token, String platform) =>
      rust.buildPushTokenPayload(token: token, platform: platform);

  String removal(String token) => rust.buildPushRemovalPayload(token: token);
}

final pushPayloadsProvider = Provider<PushPayloads>(
  (ref) => const PushPayloads(),
);

class PushState {
  const PushState({
    required this.available,
    required this.enabled,
    required this.permission,
  });

  /// `false` until Firebase is configured.
  final bool available;
  final bool enabled;
  final PushPermission permission;

  bool get denied => permission == PushPermission.denied;
}

/// Whether this device gets push notifications, and the switch for it.
///
/// Turning on is the only time the system permission dialog appears — never
/// at launch. Turning off unregisters the device on the server and deletes
/// the local token, so nothing more arrives.
@riverpod
class PushController extends _$PushController {
  static const _path = '/v1/push/token';
  StreamSubscription<String>? _refreshes;

  @override
  Future<PushState> build() async {
    final platform = ref.watch(pushPlatformProvider);
    if (platform == null) {
      return const PushState(
        available: false,
        enabled: false,
        permission: PushPermission.notDetermined,
      );
    }
    final permission = await platform.permission();
    final enabled = permission == PushPermission.granted && platform.enabled;
    if (enabled) _followTokenRefreshes(platform);
    return PushState(available: true, enabled: enabled, permission: permission);
  }

  void _followTokenRefreshes(PushPlatform platform) {
    if (_refreshes != null) return;
    _refreshes = platform.onTokenRefresh.listen((token) async {
      try {
        await _register(token);
      } on Exception catch (e) {
        // Best effort: the next app start or toggle registers it again.
        debugPrint('[push] could not register the refreshed token: $e');
      }
    });
    ref.onDispose(() => unawaited(_refreshes?.cancel()));
  }

  Future<void> _register(String token) => ref
      .read(apiClientProvider)
      .putJson(
        _path,
        ref
            .read(pushPayloadsProvider)
            .registration(token, defaultTargetPlatform.name),
      );

  /// Asks permission (first time), then registers this device. Throws on
  /// failure and leaves notifications off.
  Future<void> enable() async {
    final platform = ref.read(pushPlatformProvider);
    if (platform == null) {
      throw StateError('Push is unavailable: Firebase is not configured.');
    }

    final permission = await platform.requestPermission();
    if (permission != PushPermission.granted) {
      state = AsyncData(
        PushState(available: true, enabled: false, permission: permission),
      );
      return;
    }

    await platform.setEnabled(enabled: true);
    try {
      final token = await platform.token();
      if (token == null) {
        throw StateError('No device token was issued.');
      }
      await _register(token);
    } on Object {
      await platform.setEnabled(enabled: false);
      rethrow;
    }
    _followTokenRefreshes(platform);
    state = const AsyncData(
      PushState(
        available: true,
        enabled: true,
        permission: PushPermission.granted,
      ),
    );
  }

  /// Unregisters this device and stops pushes. Works offline: if the server
  /// cannot be told, deleting the local token still ends delivery, and the
  /// stale server row is removed the first time FCM reports it dead.
  Future<void> disable() async {
    final platform = ref.read(pushPlatformProvider);
    if (platform == null) return;

    String? token;
    try {
      token = await platform.token();
    } on Exception {
      token = null;
    }
    if (token != null) {
      try {
        await ref
            .read(apiClientProvider)
            .deleteJson(_path, ref.read(pushPayloadsProvider).removal(token));
      } on ApiException catch (e) {
        debugPrint('[push] server was not told about opt-out: $e');
      }
    }
    await platform.deleteToken();
    await platform.setEnabled(enabled: false);
    await _refreshes?.cancel();
    _refreshes = null;
    state = AsyncData(
      PushState(
        available: true,
        enabled: false,
        permission: state.value?.permission ?? PushPermission.granted,
      ),
    );
  }
}
