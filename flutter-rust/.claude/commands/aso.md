---
description: ASO (App Store Optimization) research + draft (marketer hat, main loop)
argument-hint: [optional: focus area — e.g. "keyword research" or "title rewrite"]
---

Wear the **marketer hat** (`docs/PRINCIPLES.md § Role hats`). Do ASO work for the current project: $ARGUMENTS

Default scope (when no args): full ASO pass:
1. Read `docs/PRD.md § Vision` + `docs/PRD.md § Pillars` to understand the product.
2. List 20 candidate search terms a target user might type. Group into: high-intent ("habit tracker for couples") vs aspirational ("be more consistent") vs generic ("productivity app").
3. Score each candidate: relevance (1-5), competition heuristic (1-5, high=niche), volume guess (low/med/high).
4. Pick 8-12 for the App Store keyword field (100-char comma-separated, no spaces — saves chars).
5. Draft the title (30 chars) and subtitle (30 chars) tuned to the picked keywords.
6. Draft the promo text (170 chars, evergreen — no "launch day!" wording).
7. Draft the first 3 sentences of the full description (the only part the user reads before tapping "more").

Update `docs/STORE_METADATA.md` with the new drafts. Mark the previous values commented out below the new ones — never overwrite without leaving the previous draft visible.

Output:
- Path: `docs/STORE_METADATA.md`
- 3-bullet summary: title rewrite (Y/N), keywords (count), promo updated (Y/N)
- One-line verdict: SHIP / NEEDS-INPUT

No commentary on the rationale unless the user asks.
