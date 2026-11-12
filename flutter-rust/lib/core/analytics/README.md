# `lib/core/analytics`

The analytics layer. Widgets and providers never call the analytics SDK directly — they call `track()` from this layer.

## Layout

```
lib/core/analytics/
  client.dart       the track() / identify() / reset() entry points
  events.dart       typed event registry (source of truth in code)
  README.md         this file
```

## The contract

1. **One source of truth in code.** All events the product can fire are declared in `events.dart` as a Dart `sealed class` hierarchy. Anything not in the hierarchy fails to compile.
2. **One source of truth in docs.** Mirror in [`docs/TRACKING-PLAN.md`](../../../docs/TRACKING-PLAN.md). They stay in sync via the `/track` command which writes both.
3. **Widgets consume `track()`, not the SDK.** The SDK choice (PostHog / Sentry / Firebase Analytics / etc.) is encapsulated in `client.dart`. Swapping providers means editing one file.
4. **Privacy is in the types.** Each event's properties are explicit fields on its class. There's no `Map<String, Object?>` escape hatch at the call site — `props` is computed inside the class. If a property isn't declared, it can't be sent.

## Adding an event

Use `/track <event_name>` — it appends a row to `TRACKING-PLAN.md` AND adds the typed entry here. Don't add events manually; the command keeps the two in sync.

## Picking a provider

The template's `client.dart` ships with a provider-agnostic skeleton. Wire one of these in:

| Provider | Use when |
|---|---|
| **PostHog** (`posthog_flutter`) | You want product analytics + session replay + feature flags. Most flexible. Free tier generous. |
| **Sentry** (`sentry_flutter`) | You're primarily after crash reporting + perf. Add analytics later. |
| **Firebase Analytics** (`firebase_analytics`) | You're already on Firebase and want zero new dependencies. Best for funnels; weakest for ad-hoc analysis. |
| **Amplitude / Mixpanel** | Funnel analysis is your primary use case. Heavier setup. |

For solo mobile MVPs, **PostHog** is the default recommendation — it covers analytics, session replay, surveys, and feature flags in one place, and its free tier (~1M events/month) carries you well past MVP. `posthog_flutter` is already pinned in `pubspec.yaml`.

## Wiring the provider

`client.dart` is structured so the body of `track()`, `identify()`, and `reset()` is the only thing you change. The function signatures are the contract — they shouldn't change when you swap providers.

## Why a sealed class (not a Map)

A sealed class buys two things a plain `Map<String, Object?>` doesn't:

- **Exhaustiveness on the consumer side.** If you ever want to route certain events to a side channel (Slack, Discord), `switch (event)` is exhaustive — the compiler tells you when you forget the new event.
- **Per-event property types.** `SignupCompleted.method` is a typed `String`, not `Object?` you have to cast. The compiler catches misspellings and wrong types at the call site.
