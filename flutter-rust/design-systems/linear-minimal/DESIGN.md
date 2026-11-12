# Design System — Linear / Vercel Minimal (Flutter)

High-contrast monochrome, sharp typography, generous negative space. The chrome gets out of the way so the product can speak.

**Best for:** modern SaaS tools, developer-facing apps, anything where seriousness and speed are the brand.

**Platforms:** iOS, Android, web.

## Aesthetic principles

1. **Monochrome with one accent.** The palette is grayscale. The accent is reserved for primary actions only.
2. **Tight typography.** Negative letter-spacing on titles. Body at 15px, not 16. Density is intentional.
3. **Sharp corners.** Radius stays under 8px. No cards-as-pillows.
4. **Snappy motion.** 100–250ms. Linear's signature easing curve. Never bouncy. Never spring physics.
5. **Dark mode is the canonical mode.** Light works, but the brand lives in dark.

## Tokens

Full reference: [`tokens.dart`](tokens.dart). Theme wiring: [`theme.dart`](theme.dart).

Components reach tokens via the theme, never via direct imports:

```dart
final cs = Theme.of(context).colorScheme;
final palette = Theme.of(context).extension<AppPalette>()!;
final text = Theme.of(context).textTheme;
```

### Color — surfaces

| Token | Light | Dark | Material slot |
|---|---|---|---|
| `bg` | `#ffffff` | `#0a0a0a` | `colorScheme.surface` |
| `surface` | `#fafafa` | `#141414` | `colorScheme.surfaceContainerLow` |
| `border` | `#eaeaea` | `#2a2a2a` | `colorScheme.outline` |
| `divider` | `#f0f0f0` | `#1f1f1f` | `AppPalette.divider` |

### Color — text

| Token | Light | Dark | How to read |
|---|---|---|---|
| `text` | `#0a0a0a` | `#fafafa` | `colorScheme.onSurface` / default `TextStyle.color` |
| `muted` | `#666666` | `#999999` | `AppPalette.muted` |
| `subtle` | `#999999` | `#666666` | `AppPalette.subtle` |

### Color — accent + semantic

| Token | Light / Dark | Use | How to read |
|---|---|---|---|
| `accent` | `#5e6ad2` / `#8d95f2` | Primary action only — used sparingly | `colorScheme.primary` |
| `success` | `#0a9956` / `#3dd68c` | Positive state | `AppPalette.success` |
| `danger` | `#e5484d` / `#ff6369` | Destructive | `colorScheme.error` / `AppPalette.danger` |
| `warning` | `#ee9d2b` / `#ffb648` | Caution | `AppPalette.warning` |

**Discipline:** at most one accent-colored element per viewport. If you find two, downgrade one to `onSurface` or `AppPalette.muted`.

## Typography

- **Body**: Inter via `google_fonts`. Tight tracking on titles.
- **Mono**: JetBrains Mono. Used only for code-like elements — IDs, paths, command output. Not for numbers in body copy.

| Style | Size / Line | Weight | Tracking | TextTheme slot |
|---|---|---|---|---|
| `display` | 40 / 44 | 700 | -0.4 | `displayLarge` / `displayMedium` / `displaySmall` |
| `h1` | 28 / 32 | 600 | -0.3 | `headlineLarge` / `headlineMedium` / `titleLarge` |
| `h2` | 20 / 26 | 600 | -0.15 | `headlineSmall` / `titleMedium` |
| `body` | 15 / 22 | 400 | 0 | `bodyLarge` / `bodyMedium` (default — note 15, not 16) |
| `caption` | 13 / 18 | 400 | 0 | `bodySmall` / `labelMedium` |
| `monoMd` | 13 / 18 | 500 | 0 | `KeyboardHint` widget only |

Read via `Theme.of(context).textTheme.headlineLarge` etc. — never instantiate `TextStyle` inline.

## Spacing

Tighter scale than Notion: `4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 96`. The extra 20 and 40 let you tune density when 16/24/32 feel too coarse.

Use the named constants — they read better at call sites than `EdgeInsets.all(16)`:

```dart
const EdgeInsets.symmetric(
  horizontal: AppSpacing.s4,
  vertical: AppSpacing.s3,
);
SizedBox(height: AppSpacing.s6);
```

## Radius

`sm: 4`, `md: 6` (default), `lg: 8`, `pill: 999`. **Stay under 8** — anything rounder breaks the aesthetic.

```dart
BorderRadius.circular(AppRadius.md); // default for cards, modals, inputs
```

## Motion

Linear's signature feel:

- `AppMotion.fast` — 100ms — instant feedback (hover, press, ripples)
- `AppMotion.normal` — 150ms — most transitions (page, modal in/out)
- `AppMotion.slow` — 250ms — substantial layout changes
- Easing: `AppMotion.curve` = `Cubic(0.32, 0.72, 0, 1)` — Linear's curve

```dart
AnimatedContainer(
  duration: AppMotion.normal,
  curve: AppMotion.curve,
  // ...
);
```

**Never use spring physics.** No `Curves.elasticOut`, no `Curves.bounceIn`. Crispness is the brand.

## Iconography

- **Line icons only.** `lucide_icons` package, stroke 1.5. Same as Notion-GitHub.
- **No emoji.** Linear doesn't use them. If your product needs personality, get it from type and motion, not from emoji decoration.

```dart
Icon(LucideIcons.search, size: 20);
```

## Component primitives

### CommandPalette
The flagship pattern. A search-driven action picker bound to a keyboard shortcut. Implement as `showDialog` with a translucent `Theme.of(context).extension<AppPalette>()` backdrop. Body 15, results in a dense `ListView` of mono-styled rows.

### ListRow
Dense `ListTile` (44 logical px tall via `minVerticalPadding: AppSpacing.s2`), divider-separated. Title in `bodyMedium`, trailing meta in `bodySmall` (`muted`). No card chrome.

### Modal
Use `showDialog` with `barrierColor: AppColors.dark.bg.withValues(alpha: 0.6)`, content `surface`, radius `AppRadius.md`. Animate in `AppMotion.normal` with `AppMotion.curve`. Backdrop tap to dismiss.

### Button

| Variant | Widget | Style |
|---|---|---|
| **Primary** | `ElevatedButton` | `text` bg + `bg` text — pure black/white inversion. Themed by `elevatedButtonTheme`. |
| **Accent** | `FilledButton` | `accent` bg + white text. Reserved for the single most-important action per screen. |
| **Ghost** | `TextButton` | Transparent bg + `text`. Default for secondary actions. |
| **Outlined** | `OutlinedButton` | `border` outline + `text`. Use for tertiary actions in form footers. |

All variants pre-themed in `theme.dart`. **Do not pass `style:` overrides in widgets** — change the theme instead.

### KeyboardHint
Inline chip showing a keyboard shortcut. Required for any pro-feeling app.

```dart
Container(
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.s2,
    vertical: 2,
  ),
  decoration: BoxDecoration(
    color: palette.hintBackground,
    border: Border.all(color: palette.hintBorder),
    borderRadius: BorderRadius.circular(AppRadius.sm),
  ),
  child: Text(
    'Cmd+K',
    style: GoogleFonts.jetBrainsMono(textStyle: AppTypography.monoMd)
        .copyWith(color: palette.hintText),
  ),
);
```

The `hintBackground` / `hintBorder` / `hintText` tokens are exposed on the `AppPalette` ThemeExtension specifically for this primitive.

## Screen specs

Added via `/design`.
