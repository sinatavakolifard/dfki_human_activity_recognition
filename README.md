# HAR App — Progress Log

Human Activity Recognition (HAR) mobile app for Android and iOS, built with
Flutter. Records inertial measurement unit (IMU) data for research. This
file is the single source of truth across sessions — update it whenever
something material changes.

## Current status

- Version: 0.1.0+1
- Platforms enabled: Android, iOS
- Flutter SDK: ^3.10.4 (developed against Flutter 3.38.5 / Dart 3.10.4)
- Bundle / package id: `de.dfki.har_app`
- `flutter analyze`: clean
- `flutter test`: 1 passing (theme smoke test)
- Last session end: 2026-04-20

## What works end-to-end today

1. **Consent / privacy screen** (`lib/screens/consent_screen.dart`) — shown
   on first launch. Explains exactly what IMU data is collected and what is
   explicitly not collected. Blocks the rest of the app until accepted.
2. **Onboarding screen** (`lib/screens/onboarding_screen.dart`) — generates
   an anonymous UUID on first run. Collects optional age / height / weight /
   gender. Reachable later for edits from the home screen.
3. **Home screen** (`lib/screens/home_screen.dart`) — single big round
   Start/Stop button. Shows live IMU readout, elapsed time, sample counter.
   Auto-stops when the per-session maximum time is reached. Optional
   activity-description text field above the button (editable before,
   during, and after recording); on Stop with an empty field, a dialog
   prompts the user to add a label or skip.
4. **Preferences screen** (`lib/screens/preferences_screen.dart`) — choice
   chips for max recording time (5, 15, 30, 60, 120 min). Destructive
   "delete all data" action with confirmation dialog.
5. **Sessions screen** (`lib/screens/sessions_screen.dart`) — lists saved
   sessions with start time, duration, sample count, target Hz. Per-session
   share (CSV) and delete actions.

## Data pipeline

- **Capture**: `SensorService` in `lib/services/sensor_service.dart`
  subscribes to `accelerometer`, `gyroscope`, and `magnetometer` streams via
  `sensors_plus` with a sampling period slightly faster than the target rate.
  A periodic `Timer` fires every `1_000_000 / targetHz` µs (≈ 29.4 ms at
  34 Hz) and emits a `SensorSample` carrying the most recent value from each
  stream. This gives aligned rows at exactly the target frequency, which the
  raw OS streams do not guarantee.
- **Target frequency**: 34 Hz (configurable at the service level; the UI
  currently hard-codes 34).
- **Storage**: each session writes to
  `<app documents>/sessions/<session-uuid>.csv` with header
  `timestamp_ms,accel_x,accel_y,accel_z,gyro_x,gyro_y,gyro_z,mag_x,mag_y,mag_z`.
  `SessionWriter` buffers 256 rows before flushing to avoid per-sample disk
  I/O.
- **Metadata index**: `StorageService` persists a JSON list of
  `SessionMetadata` entries in `SharedPreferences`
  (`sessions_index_v1`), keyed by session UUID, pointing to the CSV on disk.
  Each entry also carries an optional user-supplied `description` (the
  activity label entered on the home screen).

## Privacy / store-readiness

- iOS: `NSMotionUsageDescription` in `ios/Runner/Info.plist` explains motion
  sensor usage in user-facing terms. No other privacy-sensitive keys added.
- Android: no runtime permissions required for accel/gyro/mag at 34 Hz.
  `uses-feature` declared for the three sensor families (not `required` for
  Play Store compatibility — see next-steps if a device lacks one).
- User identity: random v4 UUID generated locally; no account system.
- Data stays on device unless the user explicitly shares a CSV via the
  system share sheet (implemented) or uploads to a server (future).

## Dependencies pinned in `pubspec.yaml`

- `sensors_plus: ^6.1.1` — IMU streams
- `shared_preferences: ^2.3.3` — consent flag, profile, prefs, session index
- `path_provider: ^2.1.5` — app documents directory for CSV files
- `uuid: ^4.5.1` — user and session IDs
- `intl: ^0.20.1` — number and date formatting
- `share_plus: ^10.1.2` — system share sheet for CSVs

## Project layout

```
lib/
  main.dart                       # bootstraps StorageService, routes first launch
  theme.dart                      # Material 3 theme factory
  models/
    user_profile.dart             # anonymous ID + optional demographics
    sensor_sample.dart            # one IMU row + CSV serialization
    session.dart                  # SessionMetadata (index entry)
  services/
    storage_service.dart          # SharedPreferences + CSV file layout
    sensor_service.dart           # 34 Hz aligned IMU stream + SessionWriter
  screens/
    consent_screen.dart
    onboarding_screen.dart
    home_screen.dart
    preferences_screen.dart
    sessions_screen.dart
```

## Decisions worth remembering

- **Timer-driven sampling**, not raw sensor events, because `sensors_plus`
  treats the sampling period as a hint; per-sensor timestamps also do not
  line up. A shared timer gives a consistent 34 Hz grid.
- **CSV, not JSON**, for session files to keep them small and trivially
  importable into pandas / numpy / R.
- **No login**. Anonymous UUID stored locally. This avoids needing any data
  protection declaration beyond motion sensor usage for the stores.
- **Opt-in uploading deferred**. All networking is out of scope until there
  is a backend to talk to, at which point we add an explicit consent step.

## Next steps (not done yet)

- Wakelock while recording (add `wakelock_plus`) so the screen does not
  sleep mid-session. The old `keepScreenOnWhileRecording` preference was
  removed because it was wired to a no-op; reintroduce it together with the
  dependency.
- Background recording on Android via a foreground service. Currently a
  screen lock or app backgrounding will pause the sensor streams.
- Upload endpoint + explicit upload consent for the planned research DB.
- App icons and splash branding (still Flutter defaults).
- Localization (currently English-only).
- Android release signing config (still using debug keys via a TODO in
  `android/app/build.gradle.kts`).
- Privacy policy URL for Play Store / App Store listing.

## How to run

```
flutter pub get
flutter run                 # device or emulator
flutter analyze
flutter test
```

For a release artifact later:

```
flutter build apk --release    # Android
flutter build ipa --release    # iOS (macOS host + Xcode required)
```
