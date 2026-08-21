# CLAUDE.md — dfki_human_activity_recognition

Flutter app (Android + iOS) that records IMU sensor data (accelerometer,
gyroscope, magnetometer) at 34 Hz for HAR research. Sessions save locally
as CSV; optionally upload (gzipped) to the sibling `../dfki_har_backend`
FastAPI service.

## Stack

- Flutter SDK `^3.10.4` (developed against Flutter 3.38.5 / Dart 3.10.4)
- Material 3 theme (`lib/theme.dart`)
- Package id: `de.dfki.har_app`
- Key deps (see `pubspec.yaml`): `sensors_plus`, `shared_preferences`,
  `path_provider`, `uuid`, `intl`, `share_plus`, `http`, `crypto`
- No state-management library. Screens hold their own `State`; the
  `StorageService` instance is passed down via constructors.

## Directory map

```
lib/
  main.dart      # bootstraps StorageService, routes first-launch
  theme.dart     # Material 3 theme factory
  models/        # plain data classes — see lib/models/CLAUDE.md
  services/      # StorageService, SensorService, HarApi — see lib/services/CLAUDE.md
  screens/       # 5 screens, see lib/screens/CLAUDE.md
test/            # widget tests (1 smoke test today)
android/         # AndroidManifest with sensor uses-feature + INTERNET
ios/             # Info.plist with NSMotionUsageDescription
pubspec.yaml
analysis_options.yaml  # flutter_lints defaults, excludes build/ + platform dirs
```

## Cross-cutting invariants

- **Anonymous UUID identity.** Generated locally on first run
  (`StorageService.ensureUserProfile`), stored in SharedPreferences under
  `user_profile_v1`. No login, no account system, no server-assigned IDs.
  Backend accepts whatever UUID the client sends.
- **Consent gate.** First launch shows `ConsentScreen`; nothing else is
  reachable until `consent_accepted_v1` is `true`. `_Router` in
  `main.dart:33` implements the branch.
- **34 Hz is the target sample rate.** Wired at
  `HomeScreen._targetHz = 34` (`home_screen.dart:28`) and
  `SensorService(targetHz: 34)`. The `SensorSample.csvHeader` order and the
  backend's expected columns match this — don't reorder without touching
  every consumer.
- **CSV columns, in order:**
  `timestamp_ms,accel_x,accel_y,accel_z,gyro_x,gyro_y,gyro_z,mag_x,mag_y,mag_z`.
  This exact schema is what pandas / the backend expect. Kept in
  `SensorSample.csvHeader` + `SensorSample.toCsvRow` — change both together.
- **Local-first, opt-in upload.** Recordings live on-device. Backend URL +
  API key + upload toggle are all user-set in `PreferencesScreen`; the
  toggle refuses to turn on unless both fields are filled
  (`preferences_screen.dart:57-70`).
- **Upload never destroys the local CSV.** A failed upload just leaves
  `uploadedAt = null` in the session index so the user can retry from
  `SessionsScreen`. If you add auto-cleanup, gate it on `isUploaded`.
- **User-supplied text (description) is always trimmed before persisting.**
  Empty strings become `null`, not `""`, in `SessionMetadata`.

## Backend integration

Talks to `../dfki_har_backend`. `lib/services/har_api.dart` is the only
client. Contract summary:

- `PUT /v1/users/{userId}` — profile upsert (age, height_cm, weight_kg,
  gender). Called before every session upload — idempotent.
- `POST /v1/sessions` — multipart: JSON `metadata` field + gzipped CSV
  `file` field. Server re-validates `csv_sha256` and `csv_uncompressed_bytes`;
  the client must send the truth (see `HarApi.uploadSession:83-105`).
- `GET /health` — used by the "Test connection" button in Preferences.

Gender enum ↔ backend string mapping is centralized in
`_genderApiValue` (`har_api.dart:135`). Keep it stable — the backend just
stores whatever string it gets.

Emulator/simulator base URLs (from README):
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://localhost:8000`
- Deployed / LAN: the reachable URL

Cleartext HTTP works in debug; Android release blocks HTTP by default, so
the deployed backend must be behind TLS (Caddy in the backend repo).

## Platform notes

- **Android** (`android/app/src/main/AndroidManifest.xml`): declares
  `INTERNET` permission + `uses-feature` for accelerometer, gyroscope, and
  compass, all marked `required="true"`. No runtime permissions needed for
  IMU at 34 Hz.
- **iOS** (`ios/Runner/Info.plist`): `NSMotionUsageDescription` explains
  motion sensor usage. No other privacy-sensitive keys.
- **Android release signing is still debug keys** —
  `android/app/build.gradle.kts:37` has a TODO. Don't ship a release build
  without wiring a real signing config.

## Known limitations (from README "Next steps")

Do not "fix" these without checking that the intended dependency has been
added:

- **No wakelock.** Screen sleep pauses recording. The old
  `keepScreenOnWhileRecording` preference was removed because it was wired
  to a no-op; reintroduce it *together with* `wakelock_plus`.
- **No background recording on Android.** Backgrounding or lock pauses the
  sensor streams. Would need a foreground service.
- **No background upload retry.** One attempt at Stop time
  (`_maybeUploadSession`); manual retry via the Sessions screen menu.
- **App icons / splash / privacy-policy URL / localization / release
  signing** — all still defaults.

## Dev cheatsheet

```
flutter pub get
flutter run                 # device or emulator
flutter analyze             # currently clean
flutter test                # 1 passing smoke test
flutter build apk --release # Android
flutter build ipa --release # iOS (needs macOS + Xcode)
```

## Project docs — who owns what

Three doc types live in this repo. When you change code, ask which of them
now describes something that's no longer true and update accordingly:

- **`README.md`** — for outside readers (someone evaluating the app, a new
  contributor, the store-listing reviewer). Update it whenever the
  *user-facing surface* changes: a new feature, a removed feature, a
  changed setup step, a new required Flutter SDK version, a new
  dependency, new permissions requested, or changes to the backend-wiring
  flow. If a screenshot of the app would now look different in a way that
  matters, the README probably needs an edit.
- **`CLAUDE.md`** (this file, and the per-folder ones) — for people editing
  the code. Update in place when a convention, invariant, or non-obvious
  rule changes. These are overwritten, not appended.
- **`PROGRESS.md`** — shared journal, committed to the repo. Append dated
  entries with current status and roadmap items. It's the historical
  narrative; the other two are the present-tense reference.

Rule of thumb for placing a new fact: if a *user* needs it → README. If a
*code editor* needs it → CLAUDE.md. If it only makes sense with a date on
it → PROGRESS.md.
