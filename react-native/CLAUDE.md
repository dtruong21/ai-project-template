# {{PROJECT_NAME}} — Claude constitution

Loaded every turn — kept tight on purpose. Full standing rules: `docs/PRINCIPLES.md`. Process: `docs/WORKFLOWS.md`. Spec: `docs/PRD.md`. Design: `docs/DESIGN.md`. Analytics: `docs/TRACKING-PLAN.md`.

## Stack

- **App**: React Native (Expo, SDK latest), TypeScript strict, expo-router
- **Backend**: Firebase — Auth, Firestore, Cloud Functions
- **State**: Zustand (client) + TanStack Query (server cache)
- **UI**: NativeWind; tokens in `lib/design/tokens.ts`
- **Build**: EAS Build/Submit · **Test**: Jest + RNTL · **Validate**: zod at Firestore boundaries

## Layout

```
app/              expo-router routes
components/       shared UI primitives
features/<name>/  feature logic, hooks, components
lib/firebase/     typed Firestore + Auth wrappers (one per collection)
lib/design/       tokens.ts
functions/        Cloud Functions
docs/             specs, process, release
firestore.rules   security model (deployed)
```

## Conventions (non-negotiable)

- TS strict, no `any` — `unknown` + zod at boundaries.
- Firestore only via `lib/firebase/<collection>.ts`. Never call the SDK from components.
- Function components + hooks only. One screen = one thin route in `app/`; logic in `features/`.
- Tokens for all colors/spacing/type. No magic numbers.
- Tests in `__tests__/` next to code.

## How we work (Pro-optimized)

Routine work runs **in the main loop** via slash commands — no sub-agent spawn, no re-paid context tax. Spawn a sub-agent only when isolation genuinely pays: `/test` and `/qa-sweep` (the `qa-engineer` agent reads a lot) and wide multi-file searches (the built-in **Explore** agent). The full role roster also exists as **opt-in agents** in `.claude/agents/` (idea-validator → marketer) — spawn one only for big isolatable work; default is the hat.

Workflow: `/idea → /spec → /design → /build → /test → /release → /launch`. Each phase's output feeds the next; don't skip. If a later phase finds an earlier one wrong, fix it there. Product-owner steps: `/backlog` readies a spec'd story; `/accept` checks the build against its criteria before `/test`. Full process: `docs/WORKFLOWS.md`.

**Commands** — workflow: `/idea /spec /backlog /design /build /accept /test /release` · micro: `/scope-check /bug /next /qa-sweep /weekly-review` · scaffold: `/firestore /hook /track` · release+marketing: `/bump /aso /launch`. Index: `.claude/commands/README.md`. **Prefer commands over re-typing prompts.**

**Output discipline:** no preambles or end-of-turn recaps; report file paths, not code dumps; ask a cheap question before wide exploration; `Read` known paths, `Grep`/`Glob` for symbols — don't read whole folders.

## Standing rules (one line each — full text in `docs/PRINCIPLES.md`)

- **MVP-first.** v1 = the minimum viable subset delivering the pillar outcomes. Default verdict on new scope: **CUT**. `/scope-check` biases to cut.
- **UX wins** every trade-off except MVP scope: `MVP scope > UX > feature breadth > code elegance > dev convenience`. Empty / loading / error / offline states ship with every feature — not "polish later."
- **Analytics-first.** Every event lives in `docs/TRACKING-PLAN.md` before code. No PII. Add via `/track`; fire via `track()` in `lib/analytics/client.ts`.
- **QA gate.** No release with open P0/P1. See `.claude/agents/qa-engineer.md` + `docs/TEST-PLAN.md`.
- **Security.** Firebase web config isn't secret — rules + Auth are the model. Real secrets: Admin service account, EAS keys, OAuth secrets. `docs/SECURITY.md`.

## When stuck

Spec unclear → `/spec`. Design unclear → `/design`. Reuse unclear → `Grep` the symbol. Don't invent — ask.
