# Bug tracker

Active bugs live here. Closed bugs move to `closed/`.

## File naming

`<YYYY-MM-DD>-<kebab-slug>.md`

Use `/bug <title> — <repro>` to write one in the standard format — it picks the slug for you.

## States

- **Active** (in this dir): not yet fixed and verified.
- **Closed** (in `closed/`): fix shipped + `qa-engineer` confirmed the repro is dead.

## Triage rules

- P0/P1 must clear before the next release cuts.
- P2/P3 carry forward — they don't block a release but they don't disappear either.
- Duplicate? Delete the dupe, leave a one-line note in the surviving file: `Dupes filed: <date>-<slug>`.

## Severity rubric

- **P0 — Blocker**: crash, data loss, can't complete the core flow. Stop the release.
- **P1 — Major**: feature broken but workaround exists, or affects core flow on one platform.
- **P2 — Minor**: visual glitch, edge-case error, polish issue.
- **P3 — Nit**: nice-to-fix, not shipping-relevant.
