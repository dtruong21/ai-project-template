# Versioning policy

Deterministic. Every commit can answer: "should this bump the version?" — and if yes, which segment.

## The two numbers

Every release carries two distinct numbers, and they bump together (Flutter packs them into one line):

1. **Marketing version** — `MAJOR.MINOR.PATCH` (SemVer). What users see in the App Store / Play Store listing.
2. **Build number** — monotonic integer that never resets, never goes backward. What the stores use to enforce "no submitting the same build twice."

In this stack:
- Both live in `pubspec.yaml`: `version: 0.3.0+42` — the part before `+` is the marketing version, after is the build number.
- Flutter maps the marketing version to `CFBundleShortVersionString` (iOS) / `versionName` (Android), and the build number to `CFBundleVersion` (iOS) / `versionCode` (Android).

## When each segment bumps

| Trigger | Marketing version | Build number |
|---|---|---|
| **Bug fix** (any severity) | PATCH +1 | +1 |
| **New feature** (any user-facing capability, even small) | MINOR +1, PATCH → 0 | +1 |
| **Big refactor — internal only** (no user-visible change) | none | +1 (or 0 if not shipping) |
| **Big refactor — user-visible** (perf, animations, error messages, anything noticeable) | PATCH +1 | +1 |
| **Big refactor — data migration or breaking change** | MAJOR +1, MINOR → 0, PATCH → 0 | +1 |
| **Build-only patch** (store rejected for metadata, no code change) | none | +1 |

**Rule of thumb:** if a user could notice the change, the marketing version bumps. If only you can notice, only the build number bumps.

## When the bump happens

Not on merge to `main`. **At release-cut time.** Between releases, work accumulates in `CHANGELOG.md` under `## [Unreleased]`. The `/bump` command:

1. Inspects `[Unreleased]` to decide the bump
2. Updates `version:` in `pubspec.yaml` (both halves of `X.Y.Z+N`)
3. Promotes `[Unreleased]` to a dated `[X.Y.Z]` section in `CHANGELOG.md`
4. Outputs the new version + the git tag command to run

Run `/bump` immediately before `/release`. `/release` will call `/bump` for you — direct invocation is for preview/dry-run.

## Decision tree

```
Anything in CHANGELOG.md [Unreleased]?
├── No → don't cut a release. Stop.
└── Yes
    ├── Any "### Added" entries?
    │   └── Yes → MINOR bump
    ├── Else any "### Changed" or "### Fixed" entries?
    │   └── Yes → PATCH bump
    ├── Else any "### Removed" or breaking?
    │   └── Yes → MAJOR bump
    └── Else (only invisible refactors — no CHANGELOG entries)
        └── Build-only bump (if a store rebuild is needed), else don't cut a release
```

## CHANGELOG.md → SemVer mapping

The `/bump` command reads these headings to decide:

| CHANGELOG section | SemVer signal |
|---|---|
| `### Added` | MINOR |
| `### Changed` | PATCH (or MAJOR if breaking — annotate "(BREAKING)" if so) |
| `### Fixed` | PATCH |
| `### Deprecated` | MINOR (warning of an upcoming MAJOR) |
| `### Removed` | MAJOR |
| `### Security` | PATCH (urgency without breakage) |

Anything not user-visible (internal refactor, dev tooling, test additions, codegen updates, CI tweaks) does NOT go in `CHANGELOG.md`. The `/release` flow enforces this.

## Hotfix flow

If `production` ships a P0:

1. Branch from the last `*-production` tag: `git checkout v0.3.0-production -b hotfix/<slug>`
2. Fix + write the regression test (mandatory — see `docs/WORKFLOWS.md § Workflow 2`)
3. Add a `### Fixed` entry to `CHANGELOG.md [Unreleased]`
4. `/bump` → always PATCH (hotfixes are never MINOR, even if the fix feels big)
5. `/release production` (pushes a tag — Codemagic picks it up + builds + submits)
6. Merge the hotfix branch back into `main`

Same-day turnaround is the target. Build number ratchets forward; marketing version reflects the fix.

## Pre-release identifiers (optional)

For staging builds before a public version, SemVer supports pre-release identifiers in `pubspec.yaml`:

- `version: 0.3.0-rc.1+42` — release candidate 1
- `version: 0.3.0-rc.2+43` — next RC after fixes
- `version: 0.3.0+50` — final public version (drop the `-rc.N`)

Most solo MVPs skip this — just use channel tags (`v0.3.0-staging` vs `v0.3.0-production`). The build number is the discriminator.

## What never happens

- **Skipping a build number.** Even on a failed build, the next attempt is build+1 — never reuse.
- **Bumping the version without a CHANGELOG entry.** They move together. `/bump` enforces it.
- **Amending the version after the release tag is cut.** The release commit IS the bump.
- **Resetting build numbers.** Ever.
- **Bumping for a refactor that ships nothing visible.** Don't cut a release for invisible work; let it ride until the next user-visible change.

## How `/bump` enforces the policy

`/bump` (see `.claude/commands/bump.md`):
- Aborts if `CHANGELOG.md [Unreleased]` is empty (nothing to release)
- Decides the bump per the decision tree above
- Updates `pubspec.yaml` line: `version: <new-semver>+<new-build>`
- Renames `[Unreleased]` → `[X.Y.Z] — YYYY-MM-DD` in `CHANGELOG.md`
- Inserts a fresh empty `[Unreleased]` block at the top for next time
- Prints the tag command for `/release` to use

Override with `/bump <patch|minor|major>` if the heuristic gets it wrong (rare — but escape hatch is necessary).

Flutter has no production OTA-update mechanism — every fix is a full rebuild + store submission. The version policy assumes this: every PATCH means a fresh build + store review.
