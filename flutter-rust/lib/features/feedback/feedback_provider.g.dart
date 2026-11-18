// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FeedbackSubmission)
final feedbackSubmissionProvider = FeedbackSubmissionProvider._();

final class FeedbackSubmissionProvider
    extends $NotifierProvider<FeedbackSubmission, AsyncValue<void>> {
  FeedbackSubmissionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedbackSubmissionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedbackSubmissionHash();

  @$internal
  @override
  FeedbackSubmission create() => FeedbackSubmission();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$feedbackSubmissionHash() =>
    r'cf8af6eb010c8b67573d6933616baf215653e295';

abstract class _$FeedbackSubmission extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
