# {{PROJECT_NAME}} — Backlog

One ordered list of what gets built next. The PRD says what and why; this file says in what order and whether it is ready. Owned by the product-owner hat (`/backlog`, `/accept`).

**Order rule:** pillar-1 gaps → open P1 bugs → pillar-2 gaps → post-MVP. New scope enters through `/spec` first, never straight into this file.

## States

`Idea` → `Ready` → `In progress` → `Accepted` → (QA passes) → shipped. A rejected feature goes to `Rework`.

## Definition of Ready

An item is `Ready` only when all of these hold:

- [ ] PRD entry exists with Status `in-MVP`
- [ ] User story and 3–7 acceptance criteria, including empty, offline and error
- [ ] Design spec exists in `docs/DESIGN.md` (if it has a UI)
- [ ] Analytics events are named in `docs/TRACKING-PLAN.md`
- [ ] No open question in `docs/PRD.md § Open questions` blocks it

## Definition of Done

Accepted by the product owner against the acceptance criteria (`/accept`) **and** passed by QA (`/test`). No open P0 or P1 bug on the feature.

## Backlog

| # | Feature | Pillar | State | Value | Effort | Notes |
|---|---|---|---|---|---|---|
| 1 | {{feature}} | {{pillar}} | Idea | H / M / L | S / M / L | {{what is missing for Ready}} |
