/// Feedback submission — Riverpod AsyncNotifier.
///
/// This is the reference slice for the Rust + Worker flow (see
/// `lib/core/api/README.md`): Rust validates and builds the payload, Dart
/// posts it, the Worker validates again and writes to D1.
///
/// Pattern (master spec idiom #1):
///   - `build()` returns the initial value (here: `AsyncData(null)` — nothing
///      submitted yet).
///   - Mutations set `state = const AsyncValue.loading()` then
///     `state = await AsyncValue.guard(() => ...)`. Errors propagate
///     into `state.error` automatically.
///   - Inside methods after `build()`, use `ref.read` only. `ref.watch`
///     after `build()` is gotcha #1 in the master spec.
///
/// Wiring in UI:
///
///   final state = ref.watch(feedbackSubmissionProvider);
///   state.when(
///     data: (_) => SubmitButton(onPressed: () =>
///       ref.read(feedbackSubmissionProvider.notifier).submit(input)),
///     loading: () => const CircularProgressIndicator(),
///     error: (e, _) => ErrorBanner(message: e.toString()),
///   );
///
/// Generated files this depends on (neither is written by hand):
///   - `feedback_provider.g.dart`      → `dart run build_runner watch -d`
///   - `lib/src/rust/api/feedback.dart` → `flutter_rust_bridge_codegen generate`
library;

import 'package:app/core/analytics/client.dart';
import 'package:app/core/analytics/events.dart';
import 'package:app/core/api/api_client.dart';
import 'package:app/src/rust/api/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feedback_provider.g.dart';

enum FeedbackCategory { bug, idea, praise, other }

class SubmitFeedbackInput {
  const SubmitFeedbackInput({
    required this.category,
    required this.body,
    required this.route,
    required this.appVersion,
  });

  final FeedbackCategory category;
  final String body;
  final String route;

  /// From `package_info_plus` (or a build-time constant).
  final String appVersion;
}

@riverpod
class FeedbackSubmission extends _$FeedbackSubmission {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> submit(SubmitFeedbackInput input) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Rust: same validation the Worker runs. Throws with a user-facing
      // message when the input is invalid — no request is made.
      final payload = buildFeedbackPayload(
        category: input.category.name,
        body: input.body,
        route: input.route,
        appVersion: input.appVersion,
        platform: defaultTargetPlatform.name,
      );
      await ref.read(apiClientProvider).postJson('/v1/feedback', payload);
    });

    if (state.hasError) return;

    await track(
      FeedbackSubmitted(
        category: input.category.name,
        lengthChars: input.body.length,
      ),
    );
  }
}
