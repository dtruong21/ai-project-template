import 'dart:io';

import 'package:app/core/api/api_exception.dart';
import 'package:app/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AppButton', () {
    testWidgets('fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppButton(label: 'Save', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Save'));
      expect(taps, 1);
    });

    testWidgets('loading: ignores taps, shows spinner, keeps its size', (
      tester,
    ) async {
      var taps = 0;
      Widget button({required bool loading}) => _host(
        Center(
          child: AppButton(
            label: 'Save changes',
            onPressed: () => taps++,
            loading: loading,
          ),
        ),
      );

      await tester.pumpWidget(button(loading: false));
      final idleSize = tester.getSize(find.byType(FilledButton));

      await tester.pumpWidget(button(loading: true));
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);

      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)), idleSize);
    });

    testWidgets('every variant meets the 48pt touch target', (tester) async {
      for (final variant in AppButtonVariant.values) {
        await tester.pumpWidget(
          _host(
            Center(
              child: AppButton(label: 'x', onPressed: () {}, variant: variant),
            ),
          ),
        );
        final size = tester.getSize(find.byType(AppButton));
        expect(size.height, greaterThanOrEqualTo(48), reason: '$variant');
        expect(size.width, greaterThanOrEqualTo(48), reason: '$variant');
      }
    });
  });

  group('ErrorState', () {
    testWidgets('network error → offline state with working retry', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          ErrorState(
            error: ApiNetworkException(
              '/x',
              const SocketException('down'),
              StackTrace.empty,
            ),
            onRetry: () => retries++,
          ),
        ),
      );
      expect(find.text("Can't reach the server"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('no user → sign-in state', (tester) async {
      await tester.pumpWidget(
        _host(const ErrorState(error: ApiUnauthenticatedException('/x'))),
      );
      expect(find.text('Sign in required'), findsOneWidget);
    });

    testWidgets('never shows raw exception text', (tester) async {
      await tester.pumpWidget(
        _host(ErrorState(error: StateError('SELECT * FROM secrets failed'))),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.textContaining('SELECT'), findsNothing);
    });
  });

  group('AsyncValueView', () {
    Widget view(AsyncValue<List<String>> value) => _host(
      AsyncValueView<List<String>>(
        value: value,
        isEmpty: (items) => items.isEmpty,
        empty: const EmptyState(title: 'Nothing yet'),
        data: (items) => Text(items.join(',')),
      ),
    );

    testWidgets('loading', (tester) async {
      await tester.pumpWidget(view(const AsyncValue.loading()));
      expect(find.byType(LoadingState), findsOneWidget);
    });

    testWidgets('empty', (tester) async {
      await tester.pumpWidget(view(const AsyncValue.data([])));
      expect(find.text('Nothing yet'), findsOneWidget);
    });

    testWidgets('data', (tester) async {
      await tester.pumpWidget(view(const AsyncValue.data(['a', 'b'])));
      expect(find.text('a,b'), findsOneWidget);
    });

    testWidgets('error', (tester) async {
      await tester.pumpWidget(view(AsyncValue.error('boom', StackTrace.empty)));
      expect(find.byType(ErrorState), findsOneWidget);
    });
  });

  group('confirm', () {
    Future<bool?> open(WidgetTester tester, {required String tap}) async {
      bool? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await confirm(
                context,
                title: 'Delete account?',
                confirmLabel: 'Delete account',
                destructive: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      if (tap == 'outside') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.tap(find.widgetWithText(AppButton, tap));
      }
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('confirm → true', (tester) async {
      expect(await open(tester, tap: 'Delete account'), isTrue);
    });

    testWidgets('cancel → false', (tester) async {
      expect(await open(tester, tap: 'Cancel'), isFalse);
    });

    testWidgets('dismissing by tapping outside → false', (tester) async {
      expect(await open(tester, tap: 'outside'), isFalse);
    });
  });

  test('AppAvatar initials', () {
    expect(AppAvatar.initialsOf('David Truong'), 'DT');
    expect(AppAvatar.initialsOf('  alice  '), 'A');
    expect(AppAvatar.initialsOf('Jean Luc Picard'), 'JP');
    expect(AppAvatar.initialsOf('Đạt'), 'Đ');
    expect(AppAvatar.initialsOf('   '), '?');
  });

  testWidgets('UiTokens falls back when the theme did not register them', (
    tester,
  ) async {
    late UiTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            tokens = UiTokens.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tokens.radiusMd, greaterThan(0));
  });
}
