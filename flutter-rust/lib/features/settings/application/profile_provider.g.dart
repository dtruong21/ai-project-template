// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in user's profile; `null` until they save one.

@ProviderFor(Profile)
final profileProvider = ProfileProvider._();

/// The signed-in user's profile; `null` until they save one.
final class ProfileProvider
    extends $AsyncNotifierProvider<Profile, ProfileView?> {
  /// The signed-in user's profile; `null` until they save one.
  ProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileHash();

  @$internal
  @override
  Profile create() => Profile();
}

String _$profileHash() => r'272ef041763ce15ce80bcbc40eecfb702c2ef17a';

/// The signed-in user's profile; `null` until they save one.

abstract class _$Profile extends $AsyncNotifier<ProfileView?> {
  FutureOr<ProfileView?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ProfileView?>, ProfileView?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProfileView?>, ProfileView?>,
              AsyncValue<ProfileView?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
