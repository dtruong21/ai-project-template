---
description: Accept or reject a built feature against its acceptance criteria (product-owner hat, main loop)
argument-hint: <feature name from PRD>
---

Wear the **product-owner hat** (`docs/PRINCIPLES.md § Product owner`). Check the built feature against its story: $ARGUMENTS

Pre-flight (stop and say which fails): the feature has a PRD entry with acceptance criteria in `docs/PRD.md`, and it is `In progress` in `docs/BACKLOG.md` (or not listed).

For EACH acceptance criterion, find evidence — a code path, a test, or a run of the project's test command (see CLAUDE.md). Judge the code and tests; do not accept on "looks done". A criterion with no way to test it is `UNTESTABLE`: send it back to `/spec` to rewrite.

Output, exactly:

```
Feature: <name>
| Criterion | Result | Evidence |
|---|---|---|
| <criterion> | PASS / FAIL / UNTESTABLE | <file:line or test name> |
Verdict: ACCEPT | REJECT
Next: /test <feature>   (on ACCEPT)   |   /build <feature> — fix: <failed criteria>   (on REJECT)
```

Then update the item's state in `docs/BACKLOG.md`: ACCEPT → `Accepted`, REJECT → `Rework`. Do not change the PRD status — that becomes `shipped` only after QA passes. Do not edit code. No preamble.
