Design system — Vivasayi AI Super App

Purpose
- Provide a compact, actionable design system for developers and designers to keep the Flutter app visually consistent.

Foundations
- Brand colors (tokens):
  - Primary: #0B6E4F
  - PrimaryVariant / Dark: #084C36
  - Secondary: #F8B400
  - Background: #F6F6F8
  - Surface / Card: #FFFFFF
  - Success: #2E7D32
  - Warning: #FF9800
  - Error: #D32F2F
  - OnPrimary (text/icon on primary): #FFFFFF

- Typography
  - Font family: system default (Noto Sans / Roboto fallback)
  - Scale:
    - Display / H1: 28sp, weight 700
    - H2: 22sp, weight 600
    - H3: 18sp, weight 600
    - Body: 14sp, weight 400
    - Caption: 12sp, weight 400

- Spacing
  - Layout unit: 8px
  - Small: 8
  - Medium: 16
  - Large: 24

Components (usage guidelines)
- PrimaryButton
  - Use for primary actions (submit, save, continue).
  - Height: 56, radius: 12
  - Text: uppercase small-caps optional; center aligned.
  - Use `AppTheme.colors.primary` for background and `onPrimary` for text.

- Card / FarmCard
  - Elevation: 2, radius: 12, padding: 12.
  - Farm card layout: image (left, 72x72) + title + small meta row (area, crop)
  - Tap target: full card.

- AppBar
  - Height: default Material AppBar
  - Use primary color for background; icons and title use `onPrimary`.

- BottomNavigationBar
  - Height: default; use 3-5 items only.
  - Active item color: primary; inactive color: grey[600].

- Lists / Tables
  - Use dividers at 1px with 50% opacity on surface color.

Forms
- Inputs: filled style with surface color, radius 10, vertical padding 12.
- Label above input, helper text below.

Accessibility
- Maintain minimum contrast ratio of 4.5:1 for body text.
- Provide semantic labels for icons and images.
- Make interactive targets at least 48x48.

Localization
- Keep all user-facing strings in the `lib/l10n/` localization files.
- Use short keys and prefer explicit context where needed (e.g., `home.title`, `farm.card_area`).

Assets
- Images: place under `assets/images/` with lowercase, hyphen-separated names (e.g., `farm-hero.jpg`).
- Icons: prefer vector SVG / Flutter icons where possible.

Theming / Implementation notes
- Use `AppTheme` (existing) for color and typography tokens.
- Prefer building small reusable widgets: `PrimaryButton`, `FarmCard`, `DashboardCard`, `MetricChip`.
- Keep widgets small and composable; avoid deeply nested UI in a single file.

Example: PrimaryButton usage

```dart
PrimaryButton(
  label: 'சேமிக்கவும்',
  onPressed: () {},
)
```

Where to start
- Reference: `lib/src/theme/app_theme.dart` and component files under `lib/src/ui/components/`.
- Add new tokens here as the app grows; keep this file up-to-date.

Notes
- This is an initial, concise design system to guide current work. Expand with visual examples and a token catalog when time permits.
