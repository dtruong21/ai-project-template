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
3. **Append a new subclass** of the sealed `AppEvent` class in `lib/core/analytics/events.dart`, in the style already there (plain `final class`, no freezed):
   ```dart
   final class <PascalName> extends AppEvent {
     const <PascalName>({required this.<propName>});
     final <PropType> <propName>;  // narrow types: prefer enums over String, bool over flags, no PII

     @override
     String get name => '<snake_case_name>';

     @override
     Map<String, Object?> get props => {'<prop_name>': <propName>};
   }
   ```
   The class is PascalCase (`HabitCreated`); `name` is the original snake_case (`habit_created`); prop keys are snake_case. Scalars only.
4. **Confirm the metric link.** Every event must serve a metric in TRACKING-PLAN.md § NSM or § Supporting metrics. If it serves none, reject the event and tell the user to add a metric or drop the event.
5. **No codegen.** The registry is plain Dart; nothing to regenerate.

Output:
- Path to the row added
- Path to the variant added
- Metric it serves
- One-line example call: `track(<PascalName>(<prop>: <value>))` — e.g. `track(HabitCreated(schedule: 'daily', hasReminder: true))`

No commentary. The diff IS the artifact.
