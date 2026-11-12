---
description: File a bug report in the standard format
argument-hint: <one-line title> — <brief repro>
---

File a bug for: $ARGUMENTS

Write the file at `docs/bugs/<YYYY-MM-DD>-<kebab-slug>.md` using the qa-engineer template (severity, repro, expected, actual, device, build, frequency, hypothesis).

If severity is unclear, infer it from the description (crash → P0, broken feature → P1, glitch → P2, polish → P3) and note "(inferred)".

Output: the bug file path + the assigned severity. No commentary.
