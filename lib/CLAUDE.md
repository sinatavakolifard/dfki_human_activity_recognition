# CLAUDE.md — lib/

Application code. Five layers, no state-management library.

## Files & subfolders

- `main.dart` — bootstraps `StorageService`, wraps it in `HarApp`, and
  routes first-launch via `_Router`.
- `theme.dart` — `buildAppTheme(Brightness)` returns a Material 3 ThemeData
  built from a fixed blue seed color. Filled/outlined buttons get 52/48 px
  minimum height and 16 px rounded corners — reuse those defaults instead
  of restyling per-screen.
- `models/` — plain data classes (see `models/CLAUDE.md`).
- `services/` — everything with I/O side effects (see `services/CLAUDE.md`).
- `screens/` — Flutter widgets (see `screens/CLAUDE.md`).

## First-launch routing (`main.dart:33-48`)

`_Router` picks the first screen synchronously from `StorageService` flags:

```
consentAccepted == false          → ConsentScreen
consentAccepted && userProfile == null → OnboardingScreen(isFirstRun: true)
otherwise                         → HomeScreen
```

`StorageService.create()` is `await`ed once in `main()` before `runApp`, so
the router can read those flags synchronously. Never make routing depend on
async work — the app should render instantly.

## Layering rules

- **Screens** may import from `models/`, `services/`, and other screens
  (for navigation).
- **Services** may import from `models/`. They must not import from
  `screens/`.
- **Models** are pure Dart — no Flutter imports, no I/O.
- Any new "cross-cutting" utility (e.g. formatting) goes in
  `services/` or a new sibling folder, **not** in `models/`.

## State-management convention

There is intentionally no Provider / Riverpod / Bloc / etc. Each screen
holds its own `State`; the shared `StorageService` is passed through
constructors (`storage: widget.storage`). When you land on a screen after
mutating shared state elsewhere, call `setState(() {})` in the returning
screen's callback (see `HomeScreen` returning from `PreferencesScreen` at
`home_screen.dart:298-306`).

If you feel the urge to add a state library — don't, unless the surface
grows well beyond five screens. The current pattern is deliberate.

## Widgets, not classes, for local UI pieces

Private helper widgets are defined at the bottom of each screen file
(`_StatusBanner`, `_LiveReadout`, `_BigButton`, `_LabelPromptDialog`, etc.).
Prefer this over cross-file widget files until a piece is reused. Keep them
private (`_`-prefixed) so they don't leak.
