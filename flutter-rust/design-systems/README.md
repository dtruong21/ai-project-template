# Design system family

Three reusable, cross-platform (iOS / Android / web) design systems. Pick **one** per project during [`SETUP.md`](../SETUP.md) Step 3.5. The picker copies the chosen system into `lib/core/design/` + `docs/DESIGN.md` and deletes the others — the final project carries only what it uses.

## The three systems at a glance

| System | Vibe | Best for | Signature |
|---|---|---|---|
| [`notion-github`](notion-github/) | Calm, document-feel, data-dense | Trackers, productivity, dashboards | Contribution-graph heatmap, monospace numerals |
| [`linear-minimal`](linear-minimal/) | High-contrast monochrome, sharp | SaaS tools, dev apps, serious products | Tight tracking, sub-6px radius, single accent, command palette |
| [`warm-playful`](warm-playful/) | Soft pastels, rounded, friendly | Consumer, wellness, habit, journal | 5-color palette, 16/24/32 radius, spring motion, illustrations |

Each system folder contains:

```
<system>/
  DESIGN.md            principles, tokens, primitives, screen spec template
  tokens.dart          the actual Dart token file (copied into lib/core/design/)
  theme.dart           buildTheme(Brightness) → ThemeData matching the tokens
  mood.svg             quick visual reference
```

## How to pick

Read each `DESIGN.md` § Aesthetic principles. Open the `mood.svg` for the visual gist. Then ask:

1. **Who is the user?** Pro / power-user → Linear. Productivity-curious adult → Notion-GitHub. Consumer / casual / wellness → Warm-playful.
2. **What is the dominant content?** Numbers and grids → Notion-GitHub. Lists and dense interaction → Linear. Single focal element per screen → Warm-playful.
3. **What's the brand tone?** Calm + serious → Notion-GitHub. Sharp + confident → Linear. Friendly + soft → Warm-playful.

When you're torn, default to **Notion-GitHub** — it's the most neutral and ages the best.

## Discipline once picked

The chosen system is the contract:
- Add new tokens via `/design` (see `docs/PRINCIPLES.md` � Role hats).
- Components import from `lib/core/design/tokens.dart` — never use magic values.
- If you find yourself fighting the system on 3+ screens, you picked the wrong one. Reset by re-running the picker — but ONLY before you've built much. Switching mid-build is expensive.

## Extending the family

Adding a fourth system later? Create `design-systems/<new-name>/` with the same four files (`DESIGN.md`, `tokens.dart`, `theme.dart`, `mood.svg`). The `tokens.dart` file exports `const` raw values under an `AppTokens` class. The `theme.dart` file exposes `ThemeData buildTheme(Brightness brightness)` built via `ColorScheme.fromSeed` plus any app-specific `ThemeExtension<T>` subclasses. Update this README's table. Update the picker in `SETUP.md`. The other three keep working.

Good candidates for additions:
- **iOS-native** — SF Pro, native blurs, large titles, system grouped lists. (Skipped from the initial set because it doesn't translate cleanly to Android + web.)
- **Editorial serif** — content apps with a print sensibility.
- **Dark techno** — neon accents on near-black, for crypto / gaming / fintech.

Don't add a fourth until you've shipped a project on at least two of the existing three. Premature design systems gather dust.
