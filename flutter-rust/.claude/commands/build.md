---
description: Implement a feature (engineer hat, main loop)
argument-hint: <feature name from PRD>
---

Wear the **engineer hat** (`docs/PRINCIPLES.md § Role hats`). Read `docs/MASTER-SPEC.md` first. Implement: $ARGUMENTS

Pre-flight (stop and ask if any fail):
- PRD entry exists in `docs/PRD.md` for this feature.
- Design spec exists in `docs/DESIGN.md` if a UI is involved.

Build order (strict):
1. Data slice — D1 migration, `rust/shared` model + validation, Worker route, `rust/core` payload builder — use `/d1` to scaffold. Then `flutter_rust_bridge_codegen generate`.
2. Riverpod provider in `lib/features/<name>/application/<name>_provider.dart` (AsyncNotifier via `@riverpod`) — use `/provider` to scaffold.
3. Widget(s) in `lib/features/<name>/presentation/`, covering empty/loading/error states.
4. Route in `lib/core/routing/routes.dart` (typed via `@TypedGoRoute`).
5. Analytics via `/track` for any user moment that maps to a metric in `docs/TRACKING-PLAN.md`.

Constraints:
- No `dynamic`. No `package:http` imports in widgets/providers — only inside `lib/core/api/`. No validation rules in Dart — they live in `rust/shared`.
- No magic values — colors/spacing/type from `lib/core/design/tokens.dart` + `Theme.of(context)`. `const` constructors wherever possible.
- Package imports only (`package:app_name/…`) across feature boundaries — no relative cross-feature imports.
- No direct analytics SDK calls — always `track(SomeEvent(...))` — `track` from `lib/core/analytics/client.dart`, event classes from `events.dart`.
- Run `dart run build_runner build --delete-conflicting-outputs` after touching `@freezed`/`@riverpod`/`@TypedGoRoute`.
- Test the happy path: `flutter test test/features/<name>/` + a manual run on iOS + Android sim before declaring done.
- After done, hand off to QA: `/test <feature>`.
- Output: file diffs / paths only. No restating the spec, no code walkthrough unless asked.
