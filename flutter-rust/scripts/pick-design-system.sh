#!/usr/bin/env bash
# pick-design-system.sh — copies the chosen design system into the project,
# then removes the rest. Run this once during SETUP.md Step 3.5.
#
# Usage:
#   ./scripts/pick-design-system.sh notion-github
#   ./scripts/pick-design-system.sh linear-minimal
#   ./scripts/pick-design-system.sh warm-playful

set -euo pipefail

CHOICE="${1:-}"
VALID=("notion-github" "linear-minimal" "warm-playful")

if [[ -z "$CHOICE" ]] || ! printf '%s\n' "${VALID[@]}" | grep -qx "$CHOICE"; then
  echo "Usage: $0 <system>"
  echo "  Available systems: ${VALID[*]}"
  echo ""
  echo "  Read design-systems/README.md to choose."
  exit 1
fi

SRC="design-systems/$CHOICE"
if [[ ! -d "$SRC" ]]; then
  echo "Error: $SRC not found. Run from project root."
  exit 1
fi

# Create target folders
mkdir -p lib/core/design
mkdir -p docs

# Copy the chosen system
cp "$SRC/tokens.dart" lib/core/design/tokens.dart
cp "$SRC/theme.dart" lib/core/design/theme.dart
cp "$SRC/DESIGN.md" docs/DESIGN.md
cp "$SRC/mood.svg" docs/design-mood.svg

echo "✓ Copied $CHOICE → lib/core/design/tokens.dart + lib/core/design/theme.dart"
echo "✓ Copied $CHOICE → docs/DESIGN.md + docs/design-mood.svg"

# Remove the design-systems folder — final project carries only the chosen system.
# Comment out the next line if you want to keep the others around for reference.
rm -rf design-systems
echo "✓ Removed design-systems/ — final project carries only the chosen system"

echo ""
echo "Next steps:"
echo "  1. Wire lib/core/design/theme.dart into app.dart via MaterialApp.router(theme:, darkTheme:)"
echo "     (see lib/core/design/theme.dart header comment)"
echo "  2. Install the chosen system's fonts via google_fonts (Inter / Nunito / JetBrains Mono)"
echo "  3. Review docs/DESIGN.md and customize for your brand"
