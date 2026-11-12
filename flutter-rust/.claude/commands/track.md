---
description: Add a new event to the tracking plan (updates docs + typed registry)
argument-hint: <event_name> — <when it fires> — [prop1:type prop2:type ...]
---

Add an event to the tracking plan: $ARGUMENTS

Steps (run in order):

1. **Validate the name.** Must be `noun_verb` past-tense snake_case (e.g. `habit_created`, `friend_request_sent`). Reject `addedHabit`, `clickHabit`, `userDidX`.
2. **Append a row** to the event registry table in `docs/TRACKING-PLAN.md`:
   ```
   | `<event_name>` | <when> | `<prop>: <type>, ...` | <metric this feeds — ask if unclear> |
   ```
3. **Append a new subclass** to the sealed `AppEvent` class in `lib/core/analytics/events.dart`. Use freezed sealed union syntax:
   ```dart
   @freezed
   sealed class AppEvent with _$AppEvent {
     // ...existing variants...
     const factory AppEvent.<pascalName>({
       required <PropType> <propName>,
       // narrow types: prefer enums over String, bool over flags, no PII
     }) = <PascalName>Event;
   }
   ```
   Dart class names are PascalCase (`HabitCreated`); the variant factory is `camelCase` (`habitCreated`); the wire-format `name` field used by the analytics client is the original `snake_case` (`habit_created`) — mapped in `lib/core/analytics/client.dart`.
4. **Confirm the metric link.** Every event must serve a metric in TRACKING-PLAN.md § NSM or § Supporting metrics. If it serves none, reject the event and tell the user to add a metric or drop the event.
5. **Re-run codegen.** `dart run build_runner build --delete-conflicting-outputs`.

Output:
- Path to the row added
- Path to the variant added
- Metric it serves
- One-line example call: `track(AppEvent.<camelName>(<prop>: <value>))` — e.g. `track(AppEvent.habitCreated(schedule: 'daily', hasReminder: true))`

No commentary. The diff IS the artifact.
