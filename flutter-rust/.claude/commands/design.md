---
description: Design a screen spec (designer hat, main loop)
argument-hint: <screen name>
---

Wear the **designer hat** (`docs/PRINCIPLES.md § Role hats`). Produce a screen spec for: $ARGUMENTS

Pre-flight: the PRD entry must exist in `docs/PRD.md`. If missing, stop and ask for a `/spec` run first.

- Apply the active design system in `docs/DESIGN.md`. Specify screens in terms of the component kit (`lib/core/ui/`: `AppButton` variants, state views, `confirm`, list rows, cards) — open the gallery (debug home → Component gallery) to see what exists. Tokens only — a new value means a new token in `lib/core/design/tokens.dart` first, and a new shared value means a field on `UiTokens` set in every design system. Material 3 `ThemeData`; semantic colors via a `ThemeExtension`.
- Reuse existing widgets / compose Material widgets (`Card`, `ListTile`, `FilledButton`) before proposing new ones.
- Design ALL states: empty, loading, error, offline, filled. States are first-class, not "polish later."
- Accessibility in v1: dark-mode parity, `Semantics` labels, dynamic type.
- Produce an SVG mockup via Artifact only when the layout is non-obvious (frame 390×844).
- Format: **Screen / Purpose / Route / Layout (top→bottom) / Widgets (new|reused|Material) / States / Interactions**.
- Append to `docs/DESIGN.md § Screen specs`. Output the appended block only.
