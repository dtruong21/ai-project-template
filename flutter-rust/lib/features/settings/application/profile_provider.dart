import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/src/rust/api/profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_provider.g.dart';

/// The signed-in user's profile; `null` until they save one.
@riverpod
class Profile extends _$Profile {
  @override
  Future<ProfileView?> build() async {
    try {
      final body = await ref.watch(apiClientProvider).getJson('/v1/profile');
      return parseProfile(json: body);
    } on ApiResponseException catch (e) {
      // "No profile yet" is a normal state, not an error.
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Creates or updates the profile. Throws on failure and leaves the
  /// current value untouched, so the edit form can show the message and
  /// keep the user's input.
  Future<void> save(String displayName) async {
    // Rust: same rule the Worker enforces; throws a user-facing message.
    final payload = buildProfilePayload(displayName: displayName);
    final body = await ref
        .read(apiClientProvider)
        .putJson('/v1/profile', payload);
    state = AsyncData(parseProfile(json: body));
  }
}
