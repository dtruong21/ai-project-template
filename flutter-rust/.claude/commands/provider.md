---
description: Scaffold a Riverpod AsyncNotifier provider over a repository
argument-hint: <provider name> <collection> [single | list]
---

Scaffold a Riverpod provider for: $ARGUMENTS

Create the file at `lib/features/<feature>/application/<name>_provider.dart`. Use `@riverpod` codegen — never raw `FutureProvider` or `StateNotifier`.

### Single doc pattern
```dart
@riverpod
class <Name>Notifier extends _$<Name>Notifier {
  @override
  Future<<Model>?> build(String id) async {
    return ref.watch(<collection>RepositoryProvider).get<Model>(id);
  }

  Future<void> update(Map<String, Object?> patch) async {
    final repo = ref.read(<collection>RepositoryProvider);  // read, not watch, after build()
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repo.update<Model>(state.value!.id, patch);
      return repo.get<Model>(state.value!.id);
    });
  }
}
```

### List pattern
```dart
@riverpod
class <Name>ListNotifier extends _$<Name>ListNotifier {
  @override
  Stream<List<<Model>>> build() {
    return ref.watch(<collection>RepositoryProvider).list<Model>s();
  }

  Future<void> create(<Model> data) async {
    final repo = ref.read(<collection>RepositoryProvider);
    await repo.create<Model>(data);
    // stream-backed: no manual invalidate needed
  }

  Future<void> delete(String id) async {
    final repo = ref.read(<collection>RepositoryProvider);
    await repo.delete<Model>(id);
  }
}
```

Constraints:
- Read/write through `ref.read(apiClientProvider)` from `lib/core/api/api_client.dart`, with request bodies built by the generated Rust functions in `lib/src/rust/api/`. NEVER import `package:http` here.
- `ref.watch` only inside `build()`. After `build()`, use `ref.read` — this is rule #1 in the master spec.
- Errors propagate naturally through `AsyncValue.error`. Don't catch and swallow.
- Mutations use `AsyncValue.guard` to land errors back in `state` cleanly.
- Add `part '<name>_provider.g.dart';` for the `@riverpod` generator. Run `dart run build_runner build --delete-conflicting-outputs`.

Output: the file diff only.
