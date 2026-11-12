---
description: Re-run the QA edge-case checklist against the current codebase (qa-engineer)
argument-hint: [feature name — optional, default: all]
---

Use the `qa-engineer` agent to run an edge-case sweep against: $ARGUMENTS

If no feature given, sweep `docs/TEST-PLAN.md` end-to-end. Use `flutter test` for unit/widget assertions and inspect `integration_test/` flows where the plan item is cross-screen.

For each item in the test plan:
1. Read the relevant code path.
2. Verify the behavior matches the expectation in the plan.
3. If a mismatch is found, file a bug via `/bug` and link it back to the plan item.

Output:
- Plan items checked: N
- Bugs filed: M (with severities)
- One-line verdict per item: ✅ PASS / ❌ FAIL → bug-<slug>

No prose summary. The bug files and the table ARE the artifact.
