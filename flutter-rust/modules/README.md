# Modules

Optional features a project turns on only when its idea needs them. The core stays small; a module adds one capability end to end — shared rules, Worker routes, app screens, tests — and attaches to the core at a few marked places.

| Module | Adds | Enable |
|---|---|---|
| [`files`](files/README.md) | Image/PDF upload to R2, list, view, delete; per-user quota; erased with the account | `python3 modules/files/apply.py` |
| [`payments`](payments/README.md) | In-app subscriptions and unlocks via RevenueCat (App Store / Google Play): server-held entitlements, webhook, server-side gating, paywall screen; erased with the account | `python3 modules/payments/apply.py` |
| [`push`](push/README.md) | Push notifications via FCM: opt-in switch in Settings, device registry, server-side sending, dead-token cleanup; erased with the account | `python3 modules/push/apply.py` |

Not built yet, in rough order of likely need: AI endpoint, Stripe (web / physical-goods payments), realtime, offline cache. Build one when a real app needs it, not before.

## How enabling works

Each `apply.py` is a short declaration of what to change; the machinery is in `modules/apply_lib.py`. It does four things and is safe to run twice (modules can be applied in any order, and together):

1. copies the module's files into the project (never overwrites a file that already exists);
2. inserts a few lines at the `// modules: <name>` markers in the core (route table, account deletion, settings screen, router, API test);
3. adds what the module needs to `wrangler.toml`, `pubspec.yaml` and `rust/api/migrations/`;
4. runs code generation (`flutter_rust_bridge_codegen generate`, `build_runner`).

Everything it changes shows up in `git diff` — review it, run the module's tests, commit. To remove a module, `git revert` that commit.

The markers in the core are a contract. Do not delete them; a module that cannot find its marker stops with a message rather than guessing:

| Marker | File | A module adds here |
|---|---|---|
| `// modules: shared` | `rust/shared/src/lib.rs` | `pub mod <name>;` |
| `// modules: mods` | `rust/api/src/lib.rs` | `mod <name>;` |
| `// modules: routes` | `rust/api/src/lib.rs` | its routes |
| `// modules: user-tables` | `rust/api/src/account.rs` | `DELETE FROM <table> WHERE uid = ?1` |
| `// modules: before-delete` | `rust/api/src/account.rs` | cleanup that must run before rows go (e.g. stored files) |
| `// modules: core` | `rust/core/src/api/mod.rs` | `pub mod <name>;` |
| `// modules: setup` | `rust/api/tests/api_test.py` | code that runs before the Worker starts (start fakes, append to `EXTRA_VARS`) |
| `// modules: tests` | `rust/api/tests/api_test.py` | its end-to-end block |
| `// modules: teardown` | `rust/api/tests/api_test.py` | stop what `setup` started |
| `// modules: settings-links` | `lib/features/settings/presentation/settings_screen.dart` | a row linking to its screen |
| `// modules: routes` | `lib/core/routing/router.dart` | its `GoRoute`s |

## Writing a new module

Copy `files/` as the template. A module is done when it has all of these — the same bar as the core:

- **Rules once.** Validation and wire types in `rust/shared/src/<name>.rs` with unit tests: one valid case, one per rejection, hostile inputs.
- **Routes** in `rust/api/src/<name>.rs`: authenticate → parse → validate → query scoped by the token uid; errors through `http.rs`; bound parameters only; 404 (not 403) for someone else's row.
- **Account deletion.** Every table with a `uid` goes in `user-tables`; anything stored elsewhere (files, caches) is cleaned in `before-delete`, and the end-to-end test proves it by looking at storage.
- **End-to-end block** in `api_test.py`: no token → 401 on every route, two users never see each other's data, limits, and the account-deletion check. Break the ownership check on purpose once and confirm the test fails.
- **App side:** a Riverpod provider and a screen built from the component kit (`lib/core/ui/`), all four states, widget tests with fakes. Rust response parsers in `rust/core/src/api/<name>.rs`.
- **Idempotent `apply.py`** and a README that says what it adds, its limits, and what it does not do.
- Test it the way a user will: scaffold a fresh project with `scripts/new-project.sh`, apply the module, run every suite.

Guard rule: nothing moves from a module into the core until two real apps needed it.
