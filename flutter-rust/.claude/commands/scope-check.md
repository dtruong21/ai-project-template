---
description: Quick yes/no MVP-fit check for an idea
argument-hint: <feature idea>
---

Evaluate this against the MVP pillars defined in `docs/PRD.md § Pillars`: $ARGUMENTS

Respond in EXACTLY this format, nothing else:

```
Pillar: <which one | none>
Verdict: <IN-MVP | POST-MVP | CUT>
Reason: <one sentence>
```

**Default verdict is POST-MVP.** Only return IN-MVP if the feature is:
1. Required for a pillar outcome to function at all (not "improve", not "polish"), AND
2. The smallest version of itself that still delivers that outcome.

If either of those is shaky, downgrade to POST-MVP. Read the budget in `docs/PRD.md § Constraints` before deciding. Six-week solo budget — every "yes" costs days.
