# HAR App — Progress Log

Journal for the HAR Flutter app. Committed to the repo. Use it to track
status snapshots, roadmap, and decisions made across sessions. Present-tense
architecture / conventions live in the `CLAUDE.md` files instead.

## Current status

- `flutter analyze`: clean
- `flutter test`: 1 passing (theme smoke test)
- Last session end: 2026-05-18

## Next steps (not done yet)

- Wakelock while recording (add `wakelock_plus`) so the screen does not
  sleep mid-session. The old `keepScreenOnWhileRecording` preference was
  removed because it was wired to a no-op; reintroduce it together with the
  dependency.
- Background recording on Android via a foreground service. Currently a
  screen lock or app backgrounding will pause the sensor streams.
- Background retry queue for failed uploads (currently the user has to tap
  "Upload to backend" from the Sessions screen). Today's wiring is one
  attempt at stop time + manual retry.
- App icons and splash branding (still Flutter defaults).
- Localization (currently English-only).
- Android release signing config (still using debug keys via a TODO in
  `android/app/build.gradle.kts`).
- Privacy policy URL for Play Store / App Store listing.
