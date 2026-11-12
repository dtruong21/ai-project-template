# Design System — Warm Playful (Flutter)

Soft pastel palette, rounded corners, gentle spring motion. The kind of design language that says "this app is for *you*, not your manager."

**Best for:** consumer apps, wellness, habit + journal, kids/family, meditation, food, anything where warmth beats efficiency.

**Platforms:** iOS, Android, web (Flutter).

## Aesthetic principles

1. **Never pure white. Never pure black.** The bg is `#FFFAF3` (cream); dark mode bg is `#231811` (warm brown).
2. **Round more than feels right, then round more.** Buttons radius 16, cards 24. Sharp edges look hostile in this system.
3. **Color tells the story.** A 5-color accent palette (peach / sage / butter / lavender / sky) supplements the single accent. Use it for category tags, illustrations, empty states.
4. **Motion has a touch of bounce.** Spring physics, gentle overshoot. Never aggressive — `damping: 14`, not 8.
5. **Type carries weight.** Nunito 700/800 on titles. Friendly but confident.

## Tokens

Full reference: [`tokens.dart`](tokens.dart). Theme builder: [`theme.dart`](theme.dart).

Widgets read theme via `Theme.of(context)` for Material colors, and via the `WarmPlayfulExtensions` theme extension for the category palette + warm-specific semantic colors:

```dart
final wp = Theme.of(context).extension<WarmPlayfulExtensions>()!;
Container(color: wp.peach);                 // category palette
Text('caption', style: TextStyle(color: wp.muted)); // warm-brown muted text
```

### Color — surfaces (never pure white/black)

| Token | Light | Dark |
|---|---|---|
| `bg` (`scaffoldBackgroundColor`) | `#FFFAF3` (cream) | `#231811` (warm dark) |
| `surface` (`colorScheme.surface`) | `#FFF1E6` (warm peach) | `#2E211A` |
| `border` (`wp.border`) | `#F0E2D2` | `#3F2F25` |
| `divider` (`wp.divider`) | `#F7EBDD` | `#352720` |

### Color — text (warm browns, not grays)

| Token | Light | Dark |
|---|---|---|
| `text` (`colorScheme.onSurface`) | `#3D2E1F` | `#FAEBD7` |
| `muted` (`wp.muted`) | `#8C7563` | `#B5A18C` |
| `subtle` (`wp.subtle`) | `#B5A18C` | `#8C7563` |

### Color — accent + semantic

| Token | Light / Dark | Use |
|---|---|---|
| `accent` (`colorScheme.primary`) | `#FF8C7A` / `#FF9F8C` | Primary action — warm coral |
| `success` (`wp.success`) | `#7DBA8A` / `#9ED1A8` | Positive — sage green |
| `danger` (`colorScheme.error`, `wp.danger`) | `#E07A5F` / `#F09781` | Destructive — terracotta |
| `warning` (`wp.warning`) | `#F2CC8F` / `#F2D9A1` | Caution — butter yellow |

### Color — category palette (for category/tag/illustration variety)

Exposed on `WarmPlayfulExtensions`. Access via `Theme.of(context).extension<WarmPlayfulExtensions>()!`.

| Name | Light | Dark | Use |
|---|---|---|---|
| `wp.peach` | `#FBC4AB` | `#E89E84` | Default category |
| `wp.sage` | `#B5C9A1` | `#94AC81` | Calm / nature |
| `wp.butter` | `#FFE7A0` | `#E0C880` | Energy / warmth |
| `wp.lavender` | `#D6CDEA` | `#B5ABD0` | Reflection / journal |
| `wp.sky` | `#B8DCE5` | `#92BCC7` | Cool / clarity |

`wp.categoryPalette` is a `List<Color>` for index-based assignment (e.g. `palette[habit.colorIndex % 5]`).

Use these for: habit category colors, tag chips, empty-state illustrations, onboarding scenes.

## Typography

- **Body**: Nunito — rounded geometric sans, very readable, friendly. Bundled via `google_fonts`.
- **Display**: same family, just heavier weights (700/800).
- **Mono**: JetBrains Mono if you need it (numbers in stats), but most screens skip it.

| Style | Material slot | Size / Line | Weight |
|---|---|---|---|
| `display` | `displayLarge`, `displayMedium` | 32 / 42 | 800 |
| `h1` | `headlineLarge`, `headlineMedium` | 24 / 32 | 700 |
| `h2` | `titleLarge`, `titleMedium` | 18 / 26 | 700 |
| `body` | `bodyLarge`, `bodyMedium` | 16 / 26 | 500 |
| `caption` | `bodySmall`, `labelMedium` | 13 / 19 | 500 |
| `button` | `labelLarge` | 16 / 26 | 700 |

Body is `w500` (not `w400`). Nunito at 400 reads slightly anemic at body size; 500 sits perfectly.

## Spacing

Same scale as Notion: `4, 8, 12, 16, 24, 32, 48, 64`. Use `WarmPlayfulSpacing.sN` constants from `tokens.dart`.

## Radius — the signature

| Token | Value | Use |
|---|---|---|
| `WarmPlayfulRadius.sm` | 12 | Inputs, small chips |
| `WarmPlayfulRadius.md` | 16 | Buttons, list rows |
| `WarmPlayfulRadius.lg` | 24 | Cards, modals |
| `WarmPlayfulRadius.xl` | 32 | Hero cards, primary-action sheets |
| `WarmPlayfulRadius.pill` | 999 | Avatars, pills |

**Discipline:** every container should have a radius. Square corners look out of place in this system.

## Motion

Spring physics with gentle overshoot. Flutter recipes:

```dart
// 1. Built-in spring — drive an AnimationController with SpringSimulation.
final spring = SpringDescription(
  mass: WarmPlayfulMotion.springMass,
  stiffness: WarmPlayfulMotion.springStiffness,
  damping: WarmPlayfulMotion.springDamping,
);
controller.animateWith(SpringSimulation(spring, 0, 1, 0));

// 2. Implicit animation — pair `normal` with the back-out easing curve.
AnimatedContainer(
  duration: WarmPlayfulMotion.normal,
  curve: WarmPlayfulMotion.easing,
  ...
);

// 3. flutter_animate — spring scale on press.
.animate(target: pressed ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(0.96, 0.96), curve: WarmPlayfulMotion.easing)
```

Durations:
- `fast: 200ms` — instant feedback
- `normal: 350ms` — most transitions
- `slow: 500ms` — substantial state changes (sheet open, screen push)

Lottie animations (via `lottie` package) are welcome here. Empty states with a small Lottie illustration are signature.

## Iconography

- **Line icons** — `lucide_icons` package, default stroke (already on the heavier end, matches Nunito's weight).
- **Custom illustrations** are encouraged for onboarding + empty states. Soft pastels, rounded shapes, no thin lines.
- **Emoji is fine** — even encouraged for category icons and friendly touches (a 🌱 next to "Start a habit" empty state, etc.).

## Component primitives

Each example uses tokens from `tokens.dart` and the theme extension.

### `Card`

Soft container, radius `lg` (24), surface bg, no border (the radius does the work), optional soft shadow. The default `CardThemeData` (set in `theme.dart`) already configures this; for one-offs use a `Container`:

```dart
Container(
  padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0F3D2E1F), // text @ 6%
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: child,
);
```

Or the Material primitive:

```dart
Card(
  // shape, color, elevation come from CardThemeData
  child: Padding(
    padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
    child: child,
  ),
);
```

### `Pill`

Rounded full, surface bg, body text, padding-x 12. Used for tags, filter chips, category labels. Use `ChoiceChip` with the pill shape from theme:

```dart
ChoiceChip(
  label: const Text('🌱 health'),
  selected: selected,
  onSelected: onSelected,
  // shape (pill radius), backgrounds, label style all from ChipThemeData
);
```

For a non-interactive label, a plain `Container` with `BorderRadius.circular(WarmPlayfulRadius.pill)` works.

### `Button`

- **Primary** — `ElevatedButton` (theme: accent bg, cream text, radius 16, height 48). On press: scale 0.96 via `flutter_animate` with spring easing.
- **Secondary** — `FilledButton` (theme: surface bg, text color, same shape).
- **Ghost** — `TextButton` (theme: transparent bg, text color).

All three share the same height (48), radius (`md` = 16), and label weight (700) via the theme.

### `ListRow`

Surface bg, radius `md`, padding 16. Avatar/icon left, title + caption middle, action right.

```dart
Material(
  color: Theme.of(context).colorScheme.surface,
  borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
  child: InkWell(
    borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
      child: Row(children: [leading, ..., trailing]),
    ),
  ),
);
```

Use a `Divider` between rows (uses `dividerColor` from theme).

### `EmptyState`

Centered column: Lottie or illustration (200×200 area), `display` text, body-muted subtitle, primary action button below. Always playful.

```dart
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Lottie.asset('assets/lottie/empty_seedling.json', height: 200),
    const SizedBox(height: WarmPlayfulSpacing.s5),
    Text('No habits yet', style: Theme.of(context).textTheme.displayMedium),
    const SizedBox(height: WarmPlayfulSpacing.s2),
    Text(
      'Plant your first one.',
      style: TextStyle(color: wp.muted),
    ),
    const SizedBox(height: WarmPlayfulSpacing.s5),
    ElevatedButton(onPressed: onAdd, child: const Text('Start a habit')),
  ],
);
```

### `Sheet`

Bottom sheet, radius `xl` (32) top corners only, surface bg, drag handle at top. Use `showModalBottomSheet` — the theme already configures shape/handle:

```dart
showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  // backgroundColor + shape (top radius xl) + drag handle come from BottomSheetThemeData
  builder: (ctx) => Padding(
    padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
    child: child,
  ),
);
```

For full control over the shape on a custom sheet:

```dart
ClipRRect(
  borderRadius: const BorderRadius.vertical(
    top: Radius.circular(WarmPlayfulRadius.xl),
  ),
  child: Container(
    color: Theme.of(context).colorScheme.surface,
    child: child,
  ),
);
```

## Screen specs

Added via `/design`.
