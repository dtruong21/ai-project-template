---
description: Show, add to, or groom the ordered backlog (product-owner hat, main loop)
argument-hint: [add <feature> — <idea> | groom]
---

Wear the **product-owner hat** (`docs/PRINCIPLES.md § Product owner`). Work on `docs/BACKLOG.md`: $ARGUMENTS

If `docs/BACKLOG.md` does not exist, stop and say so — it ships with the template.

- **No argument — show:** print the top 5 items in order as `# · Feature · State · why not Ready (if not)`. Flag any item in progress that is not `Ready`-compliant.
- **`add <feature> — <idea>`:** append a row with state `Idea`. Do not write the PRD entry — tell the user to run `/spec` first. Never add a feature that serves no pillar in `docs/PRD.md`; say so and stop.
- **`groom`:** reorder by pillar-1 gaps → open P1 bugs (`docs/bugs/`) → pillar-2 gaps → post-MVP. For each `Idea` item check Definition of Ready (PRD entry `in-MVP` with story and 3–7 acceptance criteria incl. empty/offline/error; design spec if UI; events in `docs/TRACKING-PLAN.md`; no blocking open question). Meets it → `Ready`. Does not → stays `Idea`, with the missing item named in Notes.

Output: the table rows changed (or the top 5), and one line `Next Ready: <feature | none>`. No preamble.
