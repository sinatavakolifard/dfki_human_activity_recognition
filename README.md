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
- Last session end: 2026-05-18

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
   sessions with start time, duration, sample count, target Hz, and upload
   status. Per-session share (CSV), upload-to-backend, and delete actions.
6. **Backend uploads** (opt-in) — when configured in Preferences, completed
   recordings are sent to the sibling `dfki_har_backend` FastAPI service
   (see `lib/services/har_api.dart`). Failures keep the local CSV so the
   user can retry from the Sessions list.

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
  system share sheet or opts in to backend uploads in Preferences. Backend
  base URL + API key are user-supplied and persisted in SharedPreferences;
  the upload toggle is off by default.

## Dependencies pinned in `pubspec.yaml`

- `sensors_plus: ^6.1.1` — IMU streams
- `shared_preferences: ^2.3.3` — consent flag, profile, prefs, session index
- `path_provider: ^2.1.5` — app documents directory for CSV files
- `uuid: ^4.5.1` — user and session IDs
- `intl: ^0.20.1` — number and date formatting
- `share_plus: ^10.1.2` — system share sheet for CSVs
- `http: ^1.2.2` — backend client
- `crypto: ^3.0.5` — SHA-256 for upload integrity check

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
    har_api.dart                  # FastAPI client (upsertUser, uploadSession)
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
- **Opt-in uploading**. Backend uploads are off by default; the Preferences
  screen exposes server URL + API key fields and a separate "Upload
  recordings" switch. The switch refuses to turn on until both fields are
  filled. Failed uploads keep the local CSV so the Sessions screen can
  retry. Backend integrity is enforced server-side via SHA-256 +
  uncompressed-length checks on the gzipped CSV (see
  `../dfki_har_backend/README.md`).

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

## Wiring it to the backend

The sibling `dfki_har_backend` repo ships a FastAPI + Postgres service that
ingests gzipped session CSVs. To send recordings there:

1. Bring the backend up locally (`docker compose up --build` in
   `../dfki_har_backend`) — it serves on `http://localhost:8000`.
2. In the app, open Preferences → *Backend uploads*:
   - **Server base URL** — `http://10.0.2.2:8000` for the Android emulator,
     `http://localhost:8000` for the iOS simulator, or the LAN /
     deployed URL.
   - **API key** — the `HAR_API_KEY` value from `../dfki_har_backend/.env`.
3. Tap **Test connection** — it hits `/health` and snackbar-confirms.
4. Flip **Upload recordings** on. From then on, every Stop pushes the
   gzipped CSV; older recordings can be sent from Sessions via the popup
   menu → *Upload to backend*.

See `../dfki_har_backend/README.md` for the API surface, deploy notes, and
how to inspect stored sessions via psql or curl.
