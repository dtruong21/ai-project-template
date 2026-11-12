---
description: Scaffold a Riverpod AsyncNotifier provider over the Worker API
argument-hint: <provider name> <table> [mutation | list]
---

Scaffold a Riverpod provider for: $ARGUMENTS

Reference: `lib/features/feedback/feedback_provider.dart`. Create `lib/features/<feature>/application/<name>_provider.dart` with `@riverpod` codegen — never raw `FutureProvider` or `StateNotifier`.

### Mutation pattern (create / update / submit)
```dart
@riverpod
class <Name> extends _$<Name> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> submit(<Input> input) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final payload = build<Table>Payload(/* fields */);  // Rust: same rules as the Worker
      await ref.read(apiClientProvider).postJson('/v1/<table>', payload);
    });
  }
}
```

### List pattern
No realtime listeners exist: `build()` fetches once, mutations call `ref.invalidateSelf()`.
```dart
@riverpod
class <Name>List extends _$<Name>List {
  @override
  Future<List<<Model>>> build() async {
    final body = await ref.watch(apiClientProvider).getJson('/v1/<table>');
    return <Model>.listFromJson(body);  // freezed + json_serializable, no hand parsing
  }

  Future<void> create(<Input> input) async {
    await ref.read(apiClientProvider).postJson('/v1/<table>', build<Table>Payload(/* fields */));
    ref.invalidateSelf();
  }
}
```
`ApiClient` only has `postJson` today. If the list pattern needs `getJson`, add it next to `postJson` in `lib/core/api/api_client.dart` with the same auth header and error mapping — never a second HTTP path.

Constraints:
- Backend only via `ref.read(apiClientProvider)`; request bodies come from the generated Rust functions in `lib/src/rust/api/`. NEVER import `package:http` here, never validate in Dart.
- `ref.watch` only inside `build()`. After `build()`, use `ref.read` — rule #1 in the master spec.
- Errors propagate through `AsyncValue.error` (`ApiException` subtypes). Don't catch and swallow.
- Add `part '<name>_provider.g.dart';` and run `dart run build_runner build --delete-conflicting-outputs`.

Output: the file diff only.
