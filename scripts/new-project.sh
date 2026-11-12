#!/usr/bin/env bash
# new-project.sh — bootstrap a fresh project from a chosen template stack.
#
# Usage:
#   ./scripts/new-project.sh react-native ~/Documents/my-new-app
#   ./scripts/new-project.sh flutter      ~/Documents/my-new-app
#
# What it does:
#   1. Copies <stack>/ into <target-dir> (git-tracked files only — no gitignored
#      local cruft like .claude/settings.local.json or .env leaks through).
#   2. Initializes a fresh git repo on `main` in the target.
#   3. Prints next steps (follow the target's SETUP.md from Step 2).

set -euo pipefail

STACK="${1:-}"
TARGET="${2:-}"
VALID=("react-native" "flutter")

# ── Validate args ────────────────────────────────────────────────────────────

if [[ -z "$STACK" ]] || [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <stack> <target-dir>"
  echo "  Stacks: ${VALID[*]}"
  exit 1
fi

if ! printf '%s\n' "${VALID[@]}" | grep -qx "$STACK"; then
  echo "Error: unknown stack '$STACK'."
  echo "  Available: ${VALID[*]}"
  exit 1
fi

# ── Resolve paths ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SRC="$REPO_ROOT/$STACK"

if [[ ! -d "$SRC" ]]; then
  echo "Error: stack source not found at $SRC"
  echo "Did you clone the template repo fully? Run: git clone https://github.com/dtruong21/ai-project-template.git"
  exit 1
fi

# Expand ~ in target if present
TARGET="${TARGET/#\~/$HOME}"

if [[ -e "$TARGET" ]] && [[ -n "$(ls -A "$TARGET" 2>/dev/null)" ]]; then
  echo "Error: target dir '$TARGET' exists and is not empty."
  echo "  Pick a fresh path, or delete the existing dir first."
  exit 1
fi

# ── Copy + init ──────────────────────────────────────────────────────────────

mkdir -p "$TARGET"

# Copy the stack subdir into the target. Prefer a git-tracked-files-only copy so
# gitignored local cruft (.claude/settings.local.json, .env, build artifacts)
# never leaks into the new project. Intended-empty dirs survive via their tracked
# .gitkeep. If the template isn't a git checkout (e.g. extracted from a tarball),
# fall back to a raw copy that still excludes .git and known local settings.
if git -C "$SRC" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ( cd "$SRC" && git ls-files -z | tar --null --files-from=- -cf - ) | ( cd "$TARGET" && tar -xf - )
else
  ( cd "$SRC" && tar --exclude=".git" --exclude="settings.local.json" -cf - . ) | ( cd "$TARGET" && tar -xf - )
fi

cd "$TARGET"
git init -b main >/dev/null

echo ""
echo "✓ New $STACK project initialized at: $TARGET"
echo ""
echo "Next steps:"
echo "  cd $TARGET"
echo "  cat SETUP.md      # follow from Step 2 (Step 1 — clone — is already done)"
echo ""
echo "After bootstrap completes, make your first commit:"
echo "  git add ."
echo "  git commit -m 'Initial commit from $STACK template'"
