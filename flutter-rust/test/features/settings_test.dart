import 'dart:io';

import 'package:app/core/api/api_exception.dart';
import 'package:app/core/ui/ui.dart';
import 'package:app/features/feedback/application/my_feedback_provider.dart';
import 'package:app/features/feedback/presentation/my_feedback_screen.dart';
import 'package:app/features/settings/application/account_actions.dart';
import 'package:app/features/settings/application/profile_provider.dart';
import 'package:app/features/settings/presentation/settings_screen.dart';
import 'package:app/src/rust/api/feedback.dart';
import 'package:app/src/rust/api/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProfile extends Profile {
  _FakeProfile(this._value);

  final ProfileView? _value;

  @override
  Future<ProfileView?> build() async => _value;
}

class _FailingProfile extends Profile {
  @override
  Future<ProfileView?> build() async =>
      throw const ApiUnauthenticatedException('/v1/profile');
}

class _FakeFeedback extends MyFeedback {
  _FakeFeedback(this._initial, {this.failRemoveWith});

  final MyFeedbackState _initial;
  final Exception? failRemoveWith;
  final removed = <String>[];
  var loadMoreCalls = 0;

  @override
  Future<MyFeedbackState> build() async => _initial;

  @override
  Future<void> remove(String id) async {
    if (failRemoveWith != null) throw failRemoveWith!;
    removed.add(id);
    state = AsyncData(
      MyFeedbackState(
        items: _initial.items.where((i) => i.id != id).toList(),
        nextCursor: null,
      ),
    );
  }

  @override
  Future<void> loadMore() async => loadMoreCalls++;
}

FeedbackItem _item(String id, String body) => FeedbackItem(
  id: id,
  category: 'idea',
  body: body,
  route: '/',
  createdAt: 1700000000,
);

final _offline = ApiNetworkException(
  '/x',
  const SocketException('down'),
  StackTrace.empty,
);

/// The button can sit below the fold once modules add rows to the screen.
Future<void> _tapDeleteAccount(WidgetTester tester) async {
  final button = find.widgetWithText(AppButton, 'Delete account');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
}

void main() {
  group('SettingsScreen', () {
    Future<void> pump(
      WidgetTester tester, {
      ProfileView? profile,
      Future<void> Function()? deleteAccount,
    }) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(() => _FakeProfile(profile)),
          deleteAccountProvider.overrideWithValue(deleteAccount ?? () async {}),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    testWidgets('no profile yet → invites to add a name', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Add your name'), findsOneWidget);
    });

    testWidgets('not signed in → compact row, nothing clipped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(() => _FailingProfile()),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in to set your name'), findsOneWidget);
      // An overflowing or clipped layout reports an exception here.
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the saved name', (tester) async {
      await pump(
        tester,
        profile: const ProfileView(
          displayName: 'Alice',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('delete account: cancel deletes nothing', (tester) async {
      var deletions = 0;
      await pump(tester, deleteAccount: () async => deletions++);
      await tester.pumpAndSettle();

      await _tapDeleteAccount(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(deletions, 0);
    });

    testWidgets('delete account: confirm deletes once and says so', (
      tester,
    ) async {
      var deletions = 0;
      await pump(tester, deleteAccount: () async => deletions++);
      await tester.pumpAndSettle();

      await _tapDeleteAccount(tester);
      await tester.pumpAndSettle();
      // The dialog's confirm button is the last "Delete account" button.
      await tester.tap(find.widgetWithText(AppButton, 'Delete account').last);
      await tester.pumpAndSettle();

      expect(deletions, 1);
      expect(find.text('Your account was deleted.'), findsOneWidget);
    });

    testWidgets('delete account: offline says nothing was deleted', (
      tester,
    ) async {
      await pump(tester, deleteAccount: () async => throw _offline);
      await tester.pumpAndSettle();

      await _tapDeleteAccount(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Delete account').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing was deleted'), findsOneWidget);
      expect(find.text('Your account was deleted.'), findsNothing);
    });
  });

  group('MyFeedbackScreen', () {
    Future<_FakeFeedback> pump(
      WidgetTester tester,
      MyFeedbackState state, {
      Exception? failRemoveWith,
    }) async {
      final fake = _FakeFeedback(state, failRemoveWith: failRemoveWith);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [myFeedbackProvider.overrideWith(() => fake)],
          child: const MaterialApp(home: MyFeedbackScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('empty state offers to send feedback', (tester) async {
      await pump(tester, const MyFeedbackState(items: [], nextCursor: null));
      expect(find.text('No feedback yet'), findsOneWidget);
      expect(find.text('Send feedback'), findsOneWidget);
    });

    testWidgets('lists items; no "Load more" on the last page', (tester) async {
      await pump(
        tester,
        MyFeedbackState(
          items: [_item('a', 'first'), _item('b', 'second')],
          nextCursor: null,
        ),
      );
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('"Load more" appears when there is a next page', (
      tester,
    ) async {
      final fake = await pump(
        tester,
        MyFeedbackState(items: [_item('a', 'first')], nextCursor: '1_ab'),
      );
      await tester.tap(find.text('Load more'));
      expect(fake.loadMoreCalls, 1);
    });

    testWidgets('delete asks first; confirm removes the row', (tester) async {
      final fake = await pump(
        tester,
        MyFeedbackState(
          items: [_item('a', 'first'), _item('b', 'second')],
          nextCursor: null,
        ),
      );

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      expect(fake.removed, isEmpty); // nothing happens before confirming
      await tester.tap(find.widgetWithText(AppButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(fake.removed, ['a']);
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('failed delete keeps the row and explains', (tester) async {
      await pump(
        tester,
        MyFeedbackState(items: [_item('a', 'first')], nextCursor: null),
        failRemoveWith: _offline,
      );

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('first'), findsOneWidget);
      expect(find.textContaining('Nothing was deleted'), findsOneWidget);
    });
  });
}
