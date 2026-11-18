import 'dart:async';
import 'dart:io';

import 'package:app/core/api/api_client.dart';
import 'package:app/features/push/application/push_platform.dart';
import 'package:app/features/push/application/push_provider.dart';
import 'package:app/features/push/presentation/push_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakePlatform implements PushPlatform {
  _FakePlatform({
    this.current = PushPermission.notDetermined,
    this.willGrant = true,
    this.isEnabled = false,
  });

  PushPermission current;
  final bool willGrant;
  String? deviceToken = 'tok:123';
  bool isEnabled;
  final calls = <String>[];
  final refreshes = StreamController<String>.broadcast();

  @override
  Future<PushPermission> permission() async => current;

  @override
  Future<PushPermission> requestPermission() async {
    calls.add('requestPermission');
    if (current == PushPermission.notDetermined) {
      current = willGrant ? PushPermission.granted : PushPermission.denied;
    }
    return current;
  }

  @override
  bool get enabled => isEnabled;

  @override
  Future<void> setEnabled({required bool enabled}) async {
    calls.add('setEnabled($enabled)');
    isEnabled = enabled;
  }

  @override
  Future<String?> token() async => deviceToken;

  @override
  Future<void> deleteToken() async => calls.add('deleteToken');

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;
}

class _FakePayloads extends PushPayloads {
  const _FakePayloads();

  @override
  String registration(String token, String platform) =>
      '{"token":"$token","platform":"${platform.toLowerCase()}"}';

  @override
  String removal(String token) => '{"token":"$token"}';
}

/// A signed-in client whose requests are recorded; [handler] decides replies.
ProviderContainer _container(
  _FakePlatform? platform,
  List<http.Request> requests, {
  Future<http.Response> Function(http.Request)? handler,
}) {
  final container = ProviderContainer(
    overrides: [
      pushPlatformProvider.overrideWithValue(platform),
      pushPayloadsProvider.overrideWithValue(const _FakePayloads()),
      apiClientProvider.overrideWithValue(
        ApiClient(
          tokenProvider: () async => 'id-token',
          baseUrl: 'https://api.test',
          httpClient: MockClient((request) async {
            requests.add(request);
            return handler != null ? handler(request) : http.Response('', 204);
          }),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('PushController', () {
    test('unavailable until Firebase is configured', () async {
      final container = _container(null, []);
      final state = await container.read(pushControllerProvider.future);
      expect(state.available, isFalse);
      expect(state.enabled, isFalse);
      await expectLater(
        container.read(pushControllerProvider.notifier).enable(),
        throwsStateError,
      );
    });

    test('starts off, and does not ask for permission by itself', () async {
      final platform = _FakePlatform();
      final container = _container(platform, []);
      final state = await container.read(pushControllerProvider.future);
      expect(state.enabled, isFalse);
      expect(platform.calls, isEmpty); // no dialog at launch
    });

    test('enable: asks permission, then registers this device once', () async {
      final platform = _FakePlatform();
      final requests = <http.Request>[];
      final container = _container(platform, requests);
      await container.read(pushControllerProvider.future);

      await container.read(pushControllerProvider.notifier).enable();

      expect(platform.calls, ['requestPermission', 'setEnabled(true)']);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'PUT');
      expect(requests.single.url.path, '/v1/push/token');
      expect(requests.single.body, contains('"token":"tok:123"'));
      expect(requests.single.headers['Authorization'], 'Bearer id-token');
      expect(container.read(pushControllerProvider).value!.enabled, isTrue);
    });

    test('enable when the user says no: nothing is registered', () async {
      final platform = _FakePlatform(willGrant: false);
      final requests = <http.Request>[];
      final container = _container(platform, requests);
      await container.read(pushControllerProvider.future);

      await container.read(pushControllerProvider.notifier).enable();

      expect(requests, isEmpty);
      expect(platform.calls, ['requestPermission']); // never turned on
      final state = container.read(pushControllerProvider).value!;
      expect(state.enabled, isFalse);
      expect(state.denied, isTrue);
    });

    test('enable: a server failure rolls back and throws', () async {
      final platform = _FakePlatform();
      final container = _container(
        platform,
        [],
        handler: (request) async => throw const SocketException('down'),
      );
      await container.read(pushControllerProvider.future);

      await expectLater(
        container.read(pushControllerProvider.notifier).enable(),
        throwsA(anything),
      );

      expect(platform.isEnabled, isFalse); // rolled back
      expect(container.read(pushControllerProvider).value!.enabled, isFalse);
    });

    test('disable: tells the server, deletes the token, turns off', () async {
      final platform = _FakePlatform(
        current: PushPermission.granted,
        isEnabled: true,
      );
      final requests = <http.Request>[];
      final container = _container(platform, requests);
      expect(
        (await container.read(pushControllerProvider.future)).enabled,
        isTrue,
      );

      await container.read(pushControllerProvider.notifier).disable();

      expect(requests.single.method, 'DELETE');
      expect(requests.single.body, '{"token":"tok:123"}');
      expect(platform.calls, ['deleteToken', 'setEnabled(false)']);
      expect(container.read(pushControllerProvider).value!.enabled, isFalse);
    });

    test('disable works offline', () async {
      final platform = _FakePlatform(
        current: PushPermission.granted,
        isEnabled: true,
      );
      final container = _container(
        platform,
        [],
        handler: (request) async => throw const SocketException('down'),
      );
      await container.read(pushControllerProvider.future);

      await container.read(pushControllerProvider.notifier).disable();

      expect(platform.calls, ['deleteToken', 'setEnabled(false)']);
      expect(container.read(pushControllerProvider).value!.enabled, isFalse);
    });

    test('a rotated token is registered again while enabled', () async {
      final platform = _FakePlatform(
        current: PushPermission.granted,
        isEnabled: true,
      );
      final requests = <http.Request>[];
      final container = _container(platform, requests);
      await container.read(pushControllerProvider.future);

      platform.refreshes.add('rotated:456');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(requests, hasLength(1));
      expect(requests.single.body, contains('rotated:456'));
    });

    test('permission revoked in system settings shows as off', () async {
      final platform = _FakePlatform(
        current: PushPermission.denied,
        isEnabled: true,
      );
      final container = _container(platform, []);
      final state = await container.read(pushControllerProvider.future);
      expect(state.enabled, isFalse);
      expect(state.denied, isTrue);
    });
  });

  group('PushSettingsTile', () {
    Future<void> pumpTile(WidgetTester tester, ProviderContainer container) =>
        tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: PushSettingsTile()),
            ),
          ),
        );

    testWidgets('disabled with an explanation before Firebase is set up', (
      tester,
    ) async {
      await pumpTile(tester, _container(null, []));
      await tester.pumpAndSettle();
      expect(find.text('Available once Firebase is set up'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
    });

    testWidgets('turning it on registers the device', (tester) async {
      final requests = <http.Request>[];
      await pumpTile(tester, _container(_FakePlatform(), requests));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });

    testWidgets('a failure explains itself and leaves the switch off', (
      tester,
    ) async {
      await pumpTile(
        tester,
        _container(
          _FakePlatform(),
          [],
          handler: (request) async => throw const SocketException('down'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Notifications were not changed'),
        findsOneWidget,
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    });

    testWidgets('denied in system settings: switch is disabled and says why', (
      tester,
    ) async {
      await pumpTile(
        tester,
        _container(_FakePlatform(current: PushPermission.denied), []),
      );
      await tester.pumpAndSettle();
      expect(find.text('Turned off in system settings'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
    });
  });
}
