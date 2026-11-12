# Template setup — instantiate a new project

This template gives you the Claude config + docs scaffolding. You bring the actual Expo project. The steps below are the one-time bootstrap to wire them together.

---

## Step 1 — Clone the template into a new project directory

```bash
# Clone — replaces the directory name with your project's name
git clone https://github.com/dtruong21/ai-project-template.git my-new-app
cd my-new-app

# Detach from the template's git history — this project gets its own
rm -rf .git

# Drop this SETUP.md once you've followed it — it's not project content
rm SETUP.md
```

(If you've cloned this template before and want a clean local copy without the network round-trip, `cp -R <local-template-path>/. .` works just the same.)

---

## Step 2 — Initialize the Expo project on top

The template carries no native code, no `package.json`, no `app.json`. Generate them with the official Expo CLI:

```bash
# From inside the new project dir
npx create-expo-app@latest . --template blank-typescript

# Add expo-router + the canonical deps
npx expo install expo-router expo-linking expo-constants expo-status-bar \
  react-native-safe-area-context react-native-screens \
  react-native-reanimated react-native-svg \
  @react-native-async-storage/async-storage

# State + cache
npm install zustand @tanstack/react-query

# Firebase + validation
npm install firebase zod

# Styling
npm install nativewind tailwindcss
npx tailwindcss init

# Tests + lint
npm install -D jest jest-expo @testing-library/react-native @types/jest \
  eslint eslint-config-expo prettier patch-package typescript
```

Then enable `expo-router` per the docs: set `"main": "expo-router/entry"` in `package.json`, add `scheme` to `app.json`, and create the `app/` folder.

---

## Step 3 — Fill in the placeholders

The template uses `{{PROJECT_NAME}}` and other markers. Run a quick find/replace in your editor:

| Placeholder | What to put |
|---|---|
| `{{PROJECT_NAME}}` | Your project's display name |
| `{{ONE_LINE_PITCH}}` | One sentence — what it does |
| `{{WHY}}` | One paragraph — why it exists |
| `{{DIFFERENTIATOR}}` | One sentence — what makes it different |
| `{{DATE}}` | Today's date |
| `{{N}}` (in PRD constraints) | Number of weeks budgeted |

Files that need editing:
- `CLAUDE.md`
- `docs/PRD.md`
- `docs/DESIGN.md`
- `docs/ROADMAP.md`
- `docs/SECURITY.md`
- `docs/RELEASE.md`
- `docs/STORE_METADATA.md`
- `docs/legal/privacy.md`
- `docs/legal/terms.md`

A one-liner that does most of the work (replace `MyApp` first):
```bash
PROJECT_NAME="MyApp" grep -rl "{{PROJECT_NAME}}" . --exclude-dir=node_modules \
  | xargs sed -i "" "s/{{PROJECT_NAME}}/$PROJECT_NAME/g"
```

---

## Step 3.5 — Pick a design system

The template ships with three pre-built design systems under [`design-systems/`](design-systems/). All three are cross-platform (iOS + Android + web). Pick one based on your project's vibe:

| System | Vibe | Best for |
|---|---|---|
| `notion-github` | Calm, data-dense | Trackers, productivity |
| `linear-minimal` | Sharp, monochrome | SaaS tools, dev apps |
| `warm-playful` | Soft, rounded | Consumer, wellness, habit, journal |

Read [`design-systems/README.md`](design-systems/README.md) and inspect each `mood.svg` before deciding. When torn, default to `notion-github` — most neutral and ages best.

Run the picker:

```bash
./scripts/pick-design-system.sh notion-github       # or linear-minimal / warm-playful
```

The script:
1. Copies the chosen `tokens.ts` → `lib/design/tokens.ts`
2. Copies the chosen `tailwind.preset.js` → `lib/design/tailwind.preset.js`
3. Copies the chosen `DESIGN.md` → `docs/DESIGN.md`
4. Removes the `design-systems/` folder (the final project carries only its chosen system)

After running:
- Wire `lib/design/tailwind.preset.js` into `tailwind.config.js` (preset import).
- Bundle the system's fonts via `expo-font` (Inter / Nunito / JetBrains Mono).
- Review `docs/DESIGN.md` and tweak colors/values for your brand if needed.

**Switching later is expensive.** If you've built >3 screens and want to change, expect a 1–2 day swap. Pick deliberately the first time.

---

## Step 4 — Define your pillars in `docs/PRD.md`

Open `docs/PRD.md` and replace the pillar placeholders with 2–4 *actual* pillars for your product. **This is the most important step.** Every future feature will be scored against these pillars by `/spec` (strategist hat) and `/scope-check`. If the pillars are vague, the gatekeeping is vague.

A good pillar:
- Is one sentence.
- Names a user outcome, not a feature.
- Is in tension with the others (so you have to choose).

A bad pillar:
- "Be easy to use." (Every app says this.)
- "Push notifications." (That's a feature, not an outcome.)

---

## Step 5 — Set up Firebase

1. Create a Firebase project at https://console.firebase.google.com
2. Enable **Authentication** (start with Anonymous; add Email/Password and OAuth later)
3. Create a **Firestore database** (start in test mode; the deploy in Step 7 swaps in real rules)
4. **Project Settings → Your apps → Add app → Web** (even for RN — we use the JS SDK)
5. Copy the config values into `.env`:

```bash
cp .env.example .env
# Edit .env with your Firebase config
```

6. Install + sign in to Firebase CLI:
```bash
npm install -g firebase-tools
firebase login
firebase use --add        # picks the project and writes .firebaserc
```

---

## Step 6 — Create the lib/firebase client

You'll want a `lib/firebase/client.ts` that initializes the app once and exports `auth` + `db`. Drop this file in by hand (the collection-wrapper scaffolds import from it):

```ts
// lib/firebase/client.ts
import { initializeApp, getApps, getApp } from 'firebase/app';
import { initializeAuth, getReactNativePersistence } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import AsyncStorage from '@react-native-async-storage/async-storage';

const firebaseConfig = {
  apiKey: process.env.EXPO_PUBLIC_FIREBASE_API_KEY!,
  authDomain: process.env.EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN!,
  projectId: process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID!,
  storageBucket: process.env.EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET!,
  messagingSenderId: process.env.EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID!,
  appId: process.env.EXPO_PUBLIC_FIREBASE_APP_ID!,
};

const app = getApps().length ? getApp() : initializeApp(firebaseConfig);

export const auth = initializeAuth(app, {
  persistence: getReactNativePersistence(AsyncStorage),
});
export const db = getFirestore(app);
```

Then scaffold your first collection wrapper with `/firestore`:

```bash
# Inside Claude Code in the project dir
/firestore users displayName:string handle:string createdAt:timestamp
```

This drops a typed wrapper at `lib/firebase/users.ts` following the canonical pattern.

---

## Step 6.5 — Wire the analytics provider

The template ships an analytics layer at [`lib/analytics/`](lib/analytics/) but no provider is wired by default. Pick one and wire it before you instrument any events.

Default recommendation: **PostHog** (free tier ~1M events/month, covers MVP):

```bash
npm install posthog-react-native
```

Create the PostHog project at https://posthog.com → grab the project API key → set it in `.env`:

```
EXPO_PUBLIC_POSTHOG_KEY=<your_key>
EXPO_PUBLIC_POSTHOG_HOST=https://us.i.posthog.com
```

Open `lib/analytics/client.ts` and uncomment the PostHog wiring lines (provider import + the `posthog.capture()` / `posthog.identify()` / `posthog.reset()` calls inside `track` / `identify` / `reset`). The function signatures don't change — only the bodies.

Then write your North-Star Metric into `docs/TRACKING-PLAN.md` § NSM before adding any events. **No event gets added until the NSM is defined.**

For crash reporting, separately wire Sentry (`EXPO_PUBLIC_SENTRY_DSN` in `.env`) — analytics + crashes are different concerns.

---

## Step 7 — Deploy the starter Firestore rules

The template ships with a placeholder `firestore.rules` (you'll write it as features ship). For the initial deploy:

```bash
firebase deploy --only firestore:rules
```

Test the rules in the Firebase Console → Firestore → Rules → Playground tab before deploying to production environments.

---

## Step 8 — Write your first PRD entry

```bash
# Inside Claude Code
/spec sign-in — Email/password auth with anonymous-account linking
```

`/spec` (strategist hat) will write the entry under the matching pillar. Iterate until you're happy.

---

## Step 9 — Run the development loop

The workflow is strict and the slash commands enforce it:

```
/spec    →  /design   →  /build   →  /test   →  /release
```

Each command runs in the main loop as a role "hat" (except `/test`, which spawns the `qa-engineer` sub-agent). Each phase's output is the next phase's input. **Don't skip.**

When you're not sure where to pick up:

```bash
/next        # one-line recommendation
git status   # what's in the working tree
```

---

## Step 10 — Configure git

```bash
git init
git add .
git commit -m "Initial scaffolding from project template"
```

Add a remote when you have one.

---

## What's intentionally NOT in this template

- **`package.json`** — generated by `create-expo-app` in Step 2.
- **`app.json`** — generated by `create-expo-app`. You edit it per project (name, slug, bundle ID).
- **`firestore.rules`** — placeholder only. Real rules ship as features ship.
- **`lib/firebase/client.ts`** — copy the snippet from Step 6 once you've filled `.env`.
- **`lib/design/tokens.ts`** — picked from the design-system family in Step 3.5, not pre-included.
- **`lib/analytics/client.ts` provider body** — pick PostHog/Sentry/etc. and wire it in Step 6.5.
- **`components/`, `app/` folders** — created as you build. (Note: `lib/analytics/` and `features/feedback/` ARE pre-included as scaffolding.)

This keeps the template small and avoids stale boilerplate. The Claude config + docs are the durable parts; the code scaffolding stays specific to each project.

---

## Token-saving setup verification

Before you start serious work, verify the token discipline is in place:

1. Open Claude Code in the project dir.
2. Type `/help` — you should see all 17 slash commands listed.
3. Type `/scope-check coffee tracker` — should return a 3-line verdict.

If both work, the template is wired correctly.
