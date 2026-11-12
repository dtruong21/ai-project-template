# `features/feedback`

In-app feedback collection — and the **reference slice** for this stack's Rust + Worker + D1 flow. Copy its shape for new features (`/d1` does it for you).

 Solo devs need a tight feedback loop with their small user base — without one, you're guessing at what's broken.

## The pattern

1. A floating "Feedback" button (or settings row) on every screen → opens the feedback sheet.
2. Sheet has 4 category buttons (Bug / Idea / Praise / Other) + free-text input.
3. On submit:
   - Rust (`rust/core`) validates and builds the JSON payload; `ApiClient` posts it to `POST /v1/feedback`; the Worker verifies the token, validates again, and inserts into the D1 `feedback` table (category + body + app_version, platform, route; uid from the token).
   - Fire `feedback_submitted` event.
   - Show a quick toast / SnackBar: "Thanks — David personally reads every message."
4. You read it with a `wrangler d1 execute` query (below). Add a Worker Cron Trigger for a digest when volume justifies it.

## What gets stored

```rust
// rust/shared/src/lib.rs — what the app sends
pub struct NewFeedback {
    pub category: FeedbackCategory,   // bug | idea | praise | other
    pub body: String,                 // 1..=2000 characters, validated on both sides
    pub route: String,                // where they were when they tapped feedback
    pub app_version: String,
    pub platform: String,             // 'iOS' | 'android'
}
```

```sql
-- rust/api/migrations/0001_feedback.sql — what the server adds
id          -- random, column default
uid         -- from the verified Firebase ID token, never from the client
created_at  -- unixepoch(), column default
```

No email is collected explicitly — if they want a reply, they sign in (you already have the uid, and Auth has their email).

## Why this pattern

- **Categories filter signal from noise.** You can mark "Bug" feedback as P1+ instantly without reading 200 ideas.
- **Route context catches "this screen is broken" patterns** without the user having to describe where they were.
- **Praise is a category** — solo devs underestimate how much "this is nice" feedback matters for motivation. Filter it; read it on bad days.
- **Email-free** lowers the friction of submitting. The uid bridges back when you need to reply.

## Files

```
lib/features/feedback/
  feedback_provider.dart                 Riverpod AsyncNotifier — submit() mutation, fires the event
  presentation/
    feedback_button.dart                 floating button or settings row      (you build)
    feedback_sheet.dart                  bottom sheet with category + text    (you build)
rust/shared/src/lib.rs                   NewFeedback + validate() + tests
rust/core/src/api/feedback.rs            build_feedback_payload (called from Dart)
rust/api/src/lib.rs                      POST /v1/feedback
rust/api/migrations/0001_feedback.sql    the table + indexes
```

The provider is already wired end to end; only the two presentation widgets are left to build.

## Reading the firehose

For an MVP scale (≤500 active users), the simplest path is good enough:

- Daily, from `rust/api/`:
  ```bash
  npx wrangler d1 execute DB --remote --command \
    "SELECT datetime(created_at, 'unixepoch') AS at, category, route, body FROM feedback ORDER BY created_at DESC LIMIT 20"
  ```
- Weekly: included in the `/weekly-review` command output (it pulls the last 7 days of feedback).

When volume grows past ~10/day, add a Worker Cron Trigger that forwards new rows to Slack / Discord / an email digest.
