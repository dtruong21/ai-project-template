# Slash command library

Type these in Claude Code to skip the long prompts. Each pre-fills context so you don't re-type it.

**How they run (Pro-optimized):** all of these run **in the main loop** — they make Claude wear a "hat" (`docs/PRINCIPLES.md § Role hats`) rather than spawning a fresh sub-agent. The only exceptions are `/test` and `/qa-sweep`, which spawn the `qa-engineer` agent because QA reads a lot and isolation keeps that off the main thread. Every hat also has an **opt-in sub-agent** in `.claude/agents/` (idea-validator → marketer) for when the work is big enough to isolate — each agent file's description says when. Default stays the hat.

## Workflow (one per phase)

| Command | What it does | Runs as |
|---|---|---|
| `/idea <business idea>` | Validate before speccing — GO / PIVOT / KILL | strategist hat |
| `/spec <name> — <idea>` | Write PRD entry, reject if not pillar-fit | strategist hat |
| `/design <screen>` | Design screen spec, append to DESIGN.md | designer hat |
| `/build <feature>` | Implement: repository → provider → widget → route | engineer hat |
| `/test <feature>` | Tests + edge-case sweep, file bugs | **qa-engineer agent** |
| `/release <staging\|production>` | Run checklist, print build commands | release hat |

## Quick micro-tasks

| Command | What it does |
|---|---|
| `/bug <title> — <repro>` | File bug in standard format |
| `/scope-check <idea>` | 3-line IN-MVP / POST-MVP / CUT verdict |
| `/next` | One-line "what to build next" recommendation |
| `/qa-sweep` | Re-run edge-case checklist on current code (**qa-engineer agent**) |
| `/weekly-review` | 15-min Monday forcing function (state + top 3 next moves) |

## Scaffolds

| Command | What it does |
|---|---|
| `/d1 <table> [field:type ...]` | D1 migration + shared Rust model/validation + Worker route + app payload builder |
| `/provider <name> <table>` | Riverpod `@riverpod` AsyncNotifier over an `ApiClient` call |
| `/track <event> — <when> — [props]` | Add an event to tracking plan + typed registry |

## Release + marketing

| Command | What it does |
|---|---|
| `/bump [patch\|minor\|major]` | Read `CHANGELOG.md [Unreleased]`, bump `version:` in `pubspec.yaml`, promote changelog. See `docs/VERSIONING.md`. |
| `/aso [focus]` | ASO research + draft updates to STORE_METADATA.md (marketer hat) |
| `/launch <channel>` | Produce launch asset — product-hunt / tweet / email / community / press (marketer hat) |

## How they save tokens

On Claude Pro, total tokens (not just main-loop cleanliness) count against your usage limits. So the commands:

1. **Run in the main loop** — no sub-agent spawn re-loading CLAUDE.md + a role definition + re-reading docs. The one context you're already paying for does the work.
2. **Pre-fill the prompt** — you don't re-type "follow the PRD format, reject if not pillar-fit…".
3. **Constrain output** — explicit "no preamble", "file path only" lines keep responses short.

Spawn a sub-agent only when isolation genuinely pays: `/test`, `/qa-sweep` (heavy QA reads), or the built-in **Explore** agent for wide multi-file searches.

## Adding a new command

Drop a file at `.claude/commands/<name>.md`:

```markdown
---
description: <one line, shown in /help>
argument-hint: <expected args>
---

<the prompt body. use $ARGUMENTS for the full arg string, or $1 $2 for positional.>
```

Keep the body under ~20 lines and make it wear a hat (`docs/PRINCIPLES.md`) rather than spawn an agent, unless the work is genuinely heavy and isolatable.
