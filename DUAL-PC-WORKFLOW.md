# Dual-PC workflow — Claude Code Pro + ChatGPT Go

Two machines, two subscriptions, one pipeline. This doc is the standing split: which work goes to which PC so neither usage limit becomes the bottleneck. It applies to every project built from this template.

## The two machines

| | **PC A — build PC** | **PC B — support PC** |
|---|---|---|
| Tool | Claude Code (Pro, $20/mo) | ChatGPT Go ($8/mo): browser chat + **Codex CLI** |
| Budget | ~45 prompts per 5-hour window + weekly cap, **pooled with claude.ai chat** | 10× free-tier messages; Codex CLI has its own 5-hour + weekly limits |
| Strength | Agentic work inside this template — the hats, the commands, the QA gate | Cheap abundant tokens for research, drafting, copy, triage; Codex for mechanical repo chores |
| Doesn't get | Unlimited tokens — this is the scarce resource | Deep Research; repo judgment (MVP bias, UX rubric, gate discipline live in Claude's config) |

**One principle: Claude's window is the bottleneck. Spend it only on work that needs Claude Code's judgment plus this repo's pipeline. Everything that is research, drafting, or mechanical moves to PC B.**

## One-time setup

**PC A (build PC)**
1. Full toolchain: Node + Expo / Flutter SDK, Android Studio or Xcode, Firebase CLI, EAS or Codemagic CLI.
2. Claude Code signed into Pro.
3. Clone the project repo(s) from GitHub.
4. Real secrets (Firebase Admin service account, EAS/Codemagic keys, OAuth secrets) live **only here**. PC B never releases, so it never needs them.

**PC B (support PC)**
1. `git` + clone of the same repos from GitHub.
2. Codex CLI (`npm i -g @openai/codex`), signed in with the ChatGPT Go account.
3. Browser ChatGPT for research and drafting.
4. Optional: just enough toolchain to run the test suite (`npm test` / `flutter test`) so Codex can verify its own chores. No emulators, no store credentials.

**Git is the only sync channel.** Never copy files between PCs by hand; never leave a PC without pushing.

## Task routing

| Pipeline stage | PC B (ChatGPT Go) does | PC A (Claude Code) does |
|---|---|---|
| `/idea` | Market scan, competitor list, pricing research in browser chat → commit notes to `docs/research/` | `/idea` verdict (GO/PIVOT/KILL) + PRD draft, fed by the research |
| `/spec` | Brainstorm edge cases, user-story variants | `/spec` — the MVP bias and PRD format live here |
| `/design` | Microcopy variants, UX copy alternatives, screenshot critique | `/design` — design system + tokens are in the repo |
| `/build` | — (don't split feature work across tools) | `/build`, exclusively |
| `/test` | Paste stack traces / logs for first-pass triage and hypothesis ranking | `/test`, `/qa-sweep`, `/bug` — the QA gate is Claude's |
| chores | **Codex CLI on a `chore/*` branch**: rename sweeps, test boilerplate from a written checklist, lint/format fixes, doc drafts, translations | Review only if the chore touches Firestore rules, auth, payments, or analytics events |
| `/release` | — | `/bump` + `/release` (cheap, and the gate must hold) |
| `/aso`, `/launch` | **Draft everything here** — keywords, store copy, PH/tweet/email assets are pure copywriting | Paste draft in, run `/aso` / `/launch` to format, file, and sanity-check against PRD |
| anytime | Rubber-ducking, "how does X API work", library comparisons, error-message lookups | Only questions that need repo context |

Rule of thumb before typing into Claude Code: **"Does this need the repo or the hats?" If no → PC B.**

## Git protocol (so the PCs don't step on each other)

1. `main` is the merge target. **Pull before starting, push before walking away** — on both PCs, every time.
2. Claude Code works on `feature/*` branches. Codex works on `chore/*` branches. Never point both tools at the same branch.
3. You review Codex diffs yourself. Only spend Claude tokens reviewing Codex output when it touches security-sensitive surface (rules, auth, payments, analytics events).
4. The QA gate is unchanged: nothing releases without `/qa-sweep` clean on PC A. Codex output gets no exemption.

## Claude window discipline

- **Prep on PC B, execute on PC A.** Before opening a Claude session: research done, spec text drafted, decisions made, everything committed and pushed. Claude tokens go to code, not conversation.
- Session shape: pull → one pipeline stage → push → close. Don't idle-chat; claude.ai chat drains the same pool.
- **Window burns out mid-build?** Push WIP, walk to PC B, run the parallel track (launch drafts, research for the next feature, a Codex chore), come back when the window resets. The two limits are independent — a day where both are exhausted is a very productive day.
- `/weekly-review` on Monday stays on PC A — it reads the repo.

## Handoff prompts for ChatGPT Go

Paste-ready prompts that produce output in the exact shape the Claude commands expect, so nothing needs reformatting on PC A.

**Idea research (feeds `/idea`)**
> Research this app idea: `<idea>`. Give me exactly four blocks, each ≤3 lines: **Problem** (who hurts, when) / **Alternatives** (top 3 existing options + the gap in each) / **Wedge** (why a new entrant wins — "nicer UI" doesn't count) / **Monetization** (who pays; reachable without ad spend?). No verdict, no fluff — I'll judge it elsewhere.

**Edge-case brainstorm (feeds `/spec`)**
> Feature: `<one-line feature>`. List every edge case a solo QA would test, grouped: empty states / loading / error / offline / permissions / weird-input. One line each. No solutions, just cases.

**Bug triage (feeds `/bug`)**
> Stack: `<Expo RN | Flutter>` + Firebase. Symptom: `<what happens>`. Trace/log below. Rank the 3 most likely root causes with a one-line check for each. Then stop.

**ASO draft (feeds `/aso`)**
> Product: `<vision + pillars pasted from PRD>`. Do an ASO pass: 20 candidate search terms grouped high-intent / aspirational / generic; score each for relevance (1-5), competition (1-5, high=niche), volume (low/med/high); pick 8-12 for a 100-char comma-separated keyword field (no spaces); draft title (≤30 chars), subtitle (≤30 chars), promo text (≤170 chars, evergreen), and the first 3 sentences of the description.

**Launch asset (feeds `/launch <channel>`)**
> Product: `<vision + pillars>`. Draft a `<product-hunt | tweet | email | community | press>` launch asset. Product Hunt: tagline ≤60 chars, description ≤260, 3-5 topics, first-comment 200-400 chars in my voice, 5 gallery captions ≤80 chars. Tweet: 5-9 thread, each ≤250 chars, hook first, CTA last. Email: subject ≤50, preheader ≤90, body ≤80 words, one CTA.

Land the output in the repo from PC B (`docs/research/` for research, or paste into the target doc), commit, push — then PC A pulls and the Claude command formats and files it.
