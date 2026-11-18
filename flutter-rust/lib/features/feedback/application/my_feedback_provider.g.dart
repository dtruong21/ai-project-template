// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_feedback_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in user's own feedback, newest first, loaded a page at a time.

@ProviderFor(MyFeedback)
final myFeedbackProvider = MyFeedbackProvider._();

/// The signed-in user's own feedback, newest first, loaded a page at a time.
final class MyFeedbackProvider
    extends $AsyncNotifierProvider<MyFeedback, MyFeedbackState> {
  /// The signed-in user's own feedback, newest first, loaded a page at a time.
  MyFeedbackProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myFeedbackProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myFeedbackHash();

  @$internal
  @override
  MyFeedback create() => MyFeedback();
}

String _$myFeedbackHash() => r'37a652068c4aad40a318d45d55e3d8c2919f8043';

/// The signed-in user's own feedback, newest first, loaded a page at a time.

abstract class _$MyFeedback extends $AsyncNotifier<MyFeedbackState> {
  FutureOr<MyFeedbackState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<MyFeedbackState>, MyFeedbackState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MyFeedbackState>, MyFeedbackState>,
              AsyncValue<MyFeedbackState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
