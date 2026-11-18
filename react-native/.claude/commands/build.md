---
description: Implement a feature (engineer hat, main loop)
argument-hint: <feature name from PRD>
---

Wear the **engineer hat** (`docs/PRINCIPLES.md § Role hats`). Implement: $ARGUMENTS

Pre-flight (stop and ask if any fail):
- PRD entry exists in `docs/PRD.md` for this feature. If `docs/BACKLOG.md` lists it, it must be `Ready`.
- Design spec exists in `docs/DESIGN.md` if a UI is involved.

Build order (strict):
1. Firestore wrapper in `lib/firebase/<collection>.ts` (typed + zod-validated) — use `/firestore` to scaffold.
2. Feature hook in `features/<name>/hooks/use<Name>.ts` (TanStack Query) — use `/hook` to scaffold.
3. Component(s) in `features/<name>/components/`, covering empty/loading/error states.
4. Route in `app/`.
5. Analytics via `/track` for any user moment that maps to a metric in `docs/TRACKING-PLAN.md`.

Constraints:
- No `any`. No direct Firestore SDK calls from components. No magic numbers — use tokens.
- No direct analytics SDK calls — always `track()` from `lib/analytics/client.ts`.
- No premature abstraction — extract a shared component on the fourth similar screen, not the second.
- Test the happy path on iOS + Android sim before declaring done.
- After done, hand off to the product owner: `/accept <feature>`, then QA: `/test <feature>`.
- Output: file diffs / paths only. No restating the spec, no code walkthrough unless asked.
