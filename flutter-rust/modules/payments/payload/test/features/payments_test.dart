import 'dart:io';

import 'package:app/core/api/api_client.dart';
import 'package:app/features/payments/application/payments_platform.dart';
import 'package:app/features/payments/application/payments_provider.dart';
import 'package:app/features/payments/presentation/paywall_screen.dart';
import 'package:app/src/rust/api/payments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeStore implements PaymentsPlatform {
  _FakeStore({this.failWith, this.cancel = false});

  final PaymentsException? failWith;
  final bool cancel;
  final calls = <String>[];

  @override
  Future<void> logIn(String uid) async => calls.add('logIn($uid)');

  @override
  Future<List<PaywallPackage>> packages() async => const [
    PaywallPackage(
      id: 'monthly',
      title: 'Pro monthly',
      price: r'$4.99',
      period: 'monthly',
    ),
    PaywallPackage(
      id: 'annual',
      title: 'Pro annual',
      price: r'$39.99',
      period: 'annual',
    ),
  ];

  @override
  Future<void> purchase(String packageId) async {
    calls.add('purchase($packageId)');
    if (cancel) throw const PurchaseCancelled();
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> restore() async => calls.add('restore');
}

/// Tiny stand-in for the Rust parser, enough for the shapes used below.
List<EntitlementItem> _parse(String json) {
  final active = json.contains('"active":true');
  return json.contains('"name":"pro"')
      ? [
          EntitlementItem(
            name: 'pro',
            active: active,
            expiresAt: null,
            product: 'pro_monthly',
          ),
        ]
      : const [];
}

ProviderContainer _container(
  PaymentsPlatform? store,
  List<http.Request> requests, {
  String entitlementsBody = '{"entitlements":[]}',
  String refreshBody = '{"entitlements":[{"name":"pro","active":true}]}',
  bool refreshFails = false,
}) {
  final container = ProviderContainer(
    overrides: [
      paymentsPlatformProvider.overrideWithValue(store),
      currentUidProvider.overrideWithValue('uid-1'),
      entitlementParserProvider.overrideWithValue(_parse),
      apiClientProvider.overrideWithValue(
        ApiClient(
          tokenProvider: () async => 'id-token',
          baseUrl: 'https://api.test',
          httpClient: MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/refresh')) {
              if (refreshFails) throw const SocketException('down');
              return http.Response(refreshBody, 200);
            }
            return http.Response(entitlementsBody, 200);
          }),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('Paywall controller', () {
    test('no store configured → no packages, nothing called', () async {
      final container = _container(null, []);
      expect(await container.read(paywallProvider.future), isEmpty);
    });

    test('logs in with the Firebase uid before listing packages', () async {
      final store = _FakeStore();
      final container = _container(store, []);
      final packages = await container.read(paywallProvider.future);
      expect(store.calls, ['logIn(uid-1)']);
      expect(packages.map((p) => p.id), ['monthly', 'annual']);
    });

    test('purchase buys, then has the Worker confirm', () async {
      final store = _FakeStore();
      final requests = <http.Request>[];
      final container = _container(store, requests);
      await container.read(paywallProvider.future);

      await container.read(paywallProvider.notifier).purchase('monthly');

      expect(store.calls, contains('purchase(monthly)'));
      expect(
        requests.where(
          (r) => r.method == 'POST' && r.url.path == '/v1/entitlements/refresh',
        ),
        hasLength(1),
      );
      final items = container.read(entitlementsProvider).value!;
      expect(hasActive(items, proEntitlement), isTrue);
    });

    test('cancelling asks the Worker nothing', () async {
      final requests = <http.Request>[];
      final container = _container(_FakeStore(cancel: true), requests);
      await container.read(paywallProvider.future);

      await expectLater(
        container.read(paywallProvider.notifier).purchase('monthly'),
        throwsA(isA<PurchaseCancelled>()),
      );
      expect(requests.where((r) => r.url.path.endsWith('/refresh')), isEmpty);
    });

    test('a store failure is reported and the Worker is not asked', () async {
      final requests = <http.Request>[];
      final container = _container(
        _FakeStore(failWith: const PaymentsFailure('Card declined')),
        requests,
      );
      await container.read(paywallProvider.future);
      await expectLater(
        container.read(paywallProvider.notifier).purchase('monthly'),
        throwsA(isA<PaymentsFailure>()),
      );
      expect(requests.where((r) => r.url.path.endsWith('/refresh')), isEmpty);
    });

    test(
      'paid but not yet confirmed is its own outcome, not a failure',
      () async {
        final container = _container(_FakeStore(), [], refreshFails: true);
        await container.read(paywallProvider.future);
        await expectLater(
          container.read(paywallProvider.notifier).purchase('monthly'),
          throwsA(isA<PurchaseNotConfirmed>()),
        );
      },
    );

    test('restore also confirms with the Worker', () async {
      final store = _FakeStore();
      final requests = <http.Request>[];
      final container = _container(store, requests);
      await container.read(paywallProvider.future);
      await container.read(paywallProvider.notifier).restore();
      expect(store.calls, contains('restore'));
      expect(
        requests.where((r) => r.url.path.endsWith('/refresh')),
        hasLength(1),
      );
    });
  });

  group('PaywallScreen', () {
    Future<void> pump(WidgetTester tester, ProviderContainer container) =>
        tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: PaywallScreen()),
          ),
        );

    testWidgets('explains itself before purchases are set up', (tester) async {
      await pump(tester, _container(null, []));
      await tester.pumpAndSettle();
      expect(find.text("Purchases aren't set up yet"), findsOneWidget);
    });

    testWidgets('shows plans with prices and the legal footer', (tester) async {
      await pump(tester, _container(_FakeStore(), []));
      await tester.pumpAndSettle();
      expect(find.text('Pro monthly'), findsOneWidget);
      expect(find.textContaining(r'$4.99'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.textContaining('renew automatically'), findsOneWidget);
    });

    testWidgets('subscribing shows the thank-you and the active plan', (
      tester,
    ) async {
      final store = _FakeStore();
      await pump(tester, _container(store, []));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subscribe').first);
      await tester.pumpAndSettle();

      expect(store.calls, contains('purchase(monthly)'));
      expect(find.text('Thank you!'), findsOneWidget);
      expect(find.text("You're subscribed"), findsOneWidget);
    });

    testWidgets('cancelling shows nothing', (tester) async {
      await pump(tester, _container(_FakeStore(cancel: true), []));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subscribe').first);
      await tester.pumpAndSettle();
      expect(find.text('Thank you!'), findsNothing);
      expect(find.textContaining('went wrong'), findsNothing);
    });

    testWidgets('a store failure shows its message', (tester) async {
      await pump(
        tester,
        _container(
          _FakeStore(failWith: const PaymentsFailure('Card declined')),
          [],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subscribe').first);
      await tester.pumpAndSettle();
      expect(find.text('Card declined'), findsOneWidget);
    });

    testWidgets('paid but unconfirmed says the purchase went through', (
      tester,
    ) async {
      await pump(tester, _container(_FakeStore(), [], refreshFails: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subscribe').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Your purchase went through'), findsOneWidget);
    });
  });
}
