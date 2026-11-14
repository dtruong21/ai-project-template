import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/features/feedback/feedback_provider.dart';
import 'package:app/features/feedback/presentation/feedback_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records submissions instead of calling Rust + the network. The Rust rules
/// have their own tests (`cargo test` in rust/shared and rust/core); these
/// tests cover what the widget does with each outcome.
class _FakeSubmission extends FeedbackSubmission {
  _FakeSubmission({this.failWith});

  final Object? failWith;
  final submitted = <SubmitFeedbackInput>[];

  @override
  Future<void> submit(SubmitFeedbackInput input) async {
    submitted.add(input);
    state = failWith == null
        ? const AsyncValue.data(null)
        : AsyncValue.error(failWith!, StackTrace.empty);
  }
}

Future<void> _openSheet(WidgetTester tester, _FakeSubmission fake) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [feedbackSubmissionProvider.overrideWith(() => fake)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFeedbackSheet(context, route: '/test'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('submits the chosen category and text, then closes', (
    tester,
  ) async {
    final fake = _FakeSubmission();
    await _openSheet(tester, fake);

    await tester.tap(find.text('Bug'));
    await tester.enterText(find.byType(TextField), 'Button does nothing');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(fake.submitted.single.category, FeedbackCategory.bug);
    expect(fake.submitted.single.body, 'Button does nothing');
    expect(fake.submitted.single.route, '/test');
    expect(find.text('Send feedback'), findsNothing); // sheet closed
    expect(find.textContaining('Thanks'), findsOneWidget);
  });

  testWidgets('on failure keeps the sheet open with the text intact', (
    tester,
  ) async {
    final fake = _FakeSubmission(
      failWith: const ApiUnauthenticatedException('/v1/feedback'),
    );
    await _openSheet(tester, fake);

    await tester.enterText(find.byType(TextField), 'my long message');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Send feedback'), findsOneWidget); // still open
    expect(find.text('my long message'), findsOneWidget); // nothing lost
    expect(find.textContaining('Sign in is required'), findsOneWidget);
  });

  test('ApiClient reports unauthenticated when Firebase is not set up', () {
    final client = ApiClient(firebaseReady: false, baseUrl: 'http://x');
    expect(
      () => client.postJson('/v1/feedback', '{}'),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
  });
}
