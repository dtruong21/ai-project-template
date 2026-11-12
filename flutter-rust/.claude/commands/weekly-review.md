---
description: 15-min weekly review — surfaces stalled work, open P1s, roadmap drift
---

Run a weekly review. Write the output to `docs/weekly-reviews/<YYYY-MM-DD>.md`.

Gather this state (in parallel where possible):

1. `git log --since="7 days ago" --oneline` — what shipped this week
2. `ls docs/bugs/` — active bugs (count + breakdown by severity)
3. `docs/ROADMAP.md` — phases tagged `🚧 In progress` and `⏳ Up next`
4. `docs/PRD.md` — features tagged Status: in-MVP that aren't yet shipped
5. Recent rows in the D1 `feedback` table (if `wrangler` is logged in: `cd rust/api && npx wrangler d1 execute DB --remote --command "SELECT category, body, route FROM feedback WHERE created_at > unixepoch() - 604800 ORDER BY created_at DESC"`) OR `lib/features/feedback/README.md` if not — note 1 line either way
6. `docs/TRACKING-PLAN.md` — flag any event added in the last week (new instrumentation = new dashboard need)

Then produce a structured review in EXACTLY this format:

```markdown
# Weekly review — <YYYY-MM-DD>

## What shipped this week (last 7 days)
- <commit gist 1>
- <commit gist 2>

## What's in flight
- <feature>: <% done> — blocker: <none | <thing>>

## Open bug surface
- P0: <count>  ·  P1: <count>  ·  P2: <count>  ·  P3: <count>
- Oldest P1: <slug, days open>

## Roadmap reality check
- On track for <next phase>: <Y / N — one line why>
- Slipping: <feature or N/A>
- New scope creep: <feature or N/A — run `/scope-check` if Y>

## Feedback signal
- Top theme from last 7 days: <one line, or "no new feedback">

## v1.1 backlog (post-MVP)
- New items added this week: <count, list of slugs>

## Energy check (solo-dev forcing function)
- Hours worked: <est>
- Burnout risk: <low | medium | high>
- What to cut next week to lower risk: <or "nothing">

## Next week — top 3 moves
1. <action — ≤15 words>
2. <action — ≤15 words>
3. <action — ≤15 words>
```

Constraints:
- ≤300 words total. This is a forcing function, not a report.
- If a section has nothing to report, write `—` not "(none)" or filler text.
- Energy check is real — if the user has been pushing hard, say so honestly. Burnout kills more solo projects than bugs do.
- Do NOT propose new features. The review surfaces state; new scope goes through `/spec`.

Output: file path written + the top-3-moves section quoted. Nothing else.
