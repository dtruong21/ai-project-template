# Design System — Notion + GitHub (Flutter)

A calm, document-feel design language built for productivity. Inspired by Notion's typography-driven hierarchy and GitHub's contribution-graph aesthetic.

**Best for:** tracker apps, productivity tools, anything data-dense where users live for hours.

**Platforms:** iOS, Android (Material 3 via Flutter).

## Aesthetic principles

1. **Hierarchy through typography, not boxes.** Notion rarely uses cards. We don't either — prefer `Column` + `Divider` over `Card` for in-page structure.
2. **Monospace earns its place.** Numbers, dates, streak counts — JetBrains Mono. Body text — Inter.
3. **Heatmap is the icon.** When a screen needs visual identity, it gets a contribution-graph somewhere.
4. **Dark mode is first-class.** Every token has a dark value. The theme builder takes a `Brightness`.
5. **Motion is functional.** `flutter_animate` for state changes — never decoration.

## Tokens

Full reference: [`tokens.dart`](tokens.dart). Wire-up: [`theme.dart`](theme.dart). Highlights below.

### Color — surfaces

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#FFFFFF` | `#0D1117` | Scaffold / page background |
| `surface` | `#F7F6F3` | `#161B22` | Cards, modals, raised areas. Notion warm gray + GitHub dark surface |
| `border` | `#E9E9E7` | `#30363D` | Hairlines (1px `Border.all`) |
| `divider` | `#EDEDEC` | `#21262D` | Subtler than border — `Divider` between sections |

### Color — text

| Token | Light | Dark |
|---|---|---|
| `text` | `#37352F` | `#E6EDF3` |
| `muted` | `#787774` | `#7D8590` |
| `subtle` | `#9B9A97` | `#6E7681` |

### Color — accent + semantic

| Token | Value | Use |
|---|---|---|
| `accent` | `#2383E2` (light) / `#388BFD` (dark) | Primary action, links — seeds `ColorScheme.fromSeed` |
| `success` | `#26A641` / `#3FB950` | Positive state |
| `danger` | `#F85149` | Destructive action |
| `warning` | `#D29922` | Caution |

### Heatmap (GitHub canonical)

5-step scale for data-density visualizations. Access via the `ThemeExtension`:

```dart
final ext = Theme.of(context).extension<NotionGithubExtensions>()!;
final cellColor = ext.heatmap[intensity]; // 0..4
```

## Typography

- **Body**: Inter via `google_fonts`. Used everywhere by default — wired into the full `TextTheme`.
- **Mono**: JetBrains Mono via `google_fonts`. Streaks, dates, counts, handles, code. Pulled via `NotionGithubExtensions.monoTextStyle(...)`.

| Style | Size / Line | Weight | Maps to (TextTheme) |
|---|---|---|---|
| `display` | 32 / 40 | 600 | `displayLarge`, `displayMedium` |
| `h1` | 24 / 32 | 600 | `headlineLarge`, `headlineMedium`, `displaySmall` |
| `h2` | 18 / 26 | 600 | `headlineSmall`, `titleLarge` |
| `body` | 16 / 24 | 400 | `bodyLarge`, `bodyMedium`, `titleMedium` |
| `caption` | 13 / 18 | 400 | `bodySmall`, `labelSmall`, `titleSmall` |
| `monoMd` | 14 / 20 | 500 | `ext.monoTextStyle(fontSize: 14, height: 20/14)` |
| `monoLg` | 24 / 32 | 600 | `ext.monoTextStyle(fontSize: 24, height: 32/24, fontWeight: w600)` |

## Spacing

Index-addressable from `NotionGithubTokens.spacing` — multiples of 4: `[0, 4, 8, 12, 16, 24, 32, 48, 64]`. Use the index in widgets:

```dart
const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
// or
EdgeInsets.all(NotionGithubTokens.spacing[5]) // 24
```

## Radius

`sm: 4` (inputs), `md: 8` (default — buttons), `lg: 12` (cards, modals), `pill: 999`. Pre-wired into `InputDecorationTheme`, `FilledButtonThemeData`, `CardThemeData`, `ChipThemeData`.

## Motion

Subtle, fast, no bounce. `fast: 120ms`, `normal: 200ms`, `slow: 300ms`. Curve: `Curves.easeOut`. Access via the extension:

```dart
final ext = Theme.of(context).extension<NotionGithubExtensions>()!;
SomeWidget()
  .animate()
  .fadeIn(duration: ext.motionFast, curve: ext.motionEasing);
```

## Iconography

- **Line icons only.** `lucide_icons` (`LucideIcons.calendar`, etc.). Stroke weight is set per `Icon(size:)` — default `20`.
- **Avatars** are `CircleAvatar` with `radius: 16` and the first letter of the display name as fallback.

## Component primitives

### `Page`
Notion-style scrollable wrapper. `Scaffold` with `body: SafeArea(child: SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: 24), child: ...))`. No card chrome — let typography carry hierarchy.

### `PropertyRow`
Notion's inline-editable property: label left (caption + `muted`), value right (body, tappable). Build as:

```dart
InkWell(
  onTap: ...,
  child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    leading: const Icon(LucideIcons.calendar, size: 18),
    title: Text('Schedule', style: Theme.of(context).textTheme.bodySmall),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Daily', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(width: 4),
        const Icon(LucideIcons.chevronRight, size: 16),
      ],
    ),
  ),
)
```

```
🗓  Schedule          Daily  ›
🏷  Tags              health, morning  ›
```

### `Heatmap`
53 cols × 7 rows GitHub contribution grid. Build with `CustomPaint` — paint `53 * 7` `RRect`s, 11px square on mobile, 2px gap. Cell color = `ext.heatmap[intensityFor(date)]`. Wrap in `GestureDetector` and hit-test on tap → show a `Tooltip` / popover with date + intensity.

```dart
SizedBox(
  height: 7 * 11 + 6 * 2, // 89
  child: CustomPaint(
    painter: HeatmapPainter(
      cells: cells,
      palette: ext.heatmap,
    ),
  ),
)
```

For state-change feedback on cell taps, use `flutter_animate`:

```dart
heatmapCell.animate(target: justTapped ? 1 : 0).scale(end: const Offset(1.1, 1.1), duration: ext.motionFast);
```

### `StreakBadge` (or any numeric badge)
Mono count + icon. Default `monoMd`, `monoLg` for hero numbers.

```dart
Row(
  children: [
    const Icon(LucideIcons.flame, size: 16),
    const SizedBox(width: 4),
    Text(
      '47',
      style: ext.monoTextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500),
    ),
  ],
)
```

## Wiring it up

In `main.dart` (or your app shell):

```dart
import 'package:app_name/core/design/theme.dart';

MaterialApp.router(
  theme: notionGithubLightTheme(),
  darkTheme: notionGithubDarkTheme(),
  themeMode: ThemeMode.system,
  routerConfig: appRouter,
);
```

## Screen specs

Added via `/design`. One entry per screen.

---

**Source of truth:** [`tokens.dart`](tokens.dart) and [`theme.dart`](theme.dart). Every component reads from these — no magic values, no inline hex, no hardcoded font sizes. If a value isn't in the tokens, it doesn't ship.
