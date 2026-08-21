# CLAUDE.md — lib/screens/

Five screens, each in its own file. Every screen takes the shared
`StorageService` via constructor.

## Files & role

| File | Reached by | What it does |
| --- | --- | --- |
| `consent_screen.dart` | `_Router` when consent not accepted | One-way gate; on accept sets `consentAccepted=true`, generates the anonymous UUID, and pushes onboarding |
| `onboarding_screen.dart` | `_Router` when no profile; also from Home's Profile button | Collects optional age / height / weight / gender |
| `home_screen.dart` | `_Router` after consent+profile | Start/Stop recording, live IMU readout, elapsed time, optional description field |
| `preferences_screen.dart` | Home's Preferences button | Max recording time, backend URL/key/toggle, destructive "delete all" |
| `sessions_screen.dart` | Home's Sessions button | Lists saved sessions; per-item share / upload / delete |

## First-launch flow

```
ConsentScreen ──[accept]──> OnboardingScreen(isFirstRun: true) ──[Continue/Skip]──> HomeScreen
```

- `ConsentScreen._accept` writes both the consent flag **and** eagerly
  calls `ensureUserProfile` so the UUID exists before onboarding renders.
- `OnboardingScreen` distinguishes first-run vs. subsequent-edit via
  `isFirstRun`. First run → "Continue" (pushReplacement to Home) + "Skip
  for now" (also to Home). Subsequent → "Save" pops back.

## Per-screen invariants

### HomeScreen

- **Only one screen with real complexity.** Holds the SensorService,
  writer, subscription, and two timers (elapsed + auto-stop).
- **Start/Stop is guarded by `_busy`.** Prevents double-tap between the
  async setup phases. Always set `_busy=true` at entry, clear in `finally`.
- **`_cleanupFailedStart` exists** because a partial start can leave any of
  { file open, subscription live, timer scheduled, service running }.
  Extend it if you add another resource in `_start`.
- **Auto-stop timer** fires at `prefs.maxRecordingMinutes` and calls
  `_stop(reason: 'auto')` — snackbar wording branches on that reason.
- **Empty-description Stop opens a dialog** (`_LabelPromptDialog`) prompting
  the user to add a label. Skip is allowed. Never block Stop on this — the
  session data must always be saved first, label second.
- **Upload-on-Stop is fire-and-forget** (`unawaited(_maybeUploadSession)`).
  Failures surface as a SnackBar telling the user to retry from Sessions;
  the local CSV is never touched on failure.
- **Profile / Preferences buttons are disabled while recording**
  (`onPressed: _isRecording ? null : ...`). Sessions is always enabled.
- **Preferences may change `maxRecordingMinutes`** — Home calls
  `setState(() {})` after `.push` returns so the footer text updates.

### PreferencesScreen

- **`_saveBackend()` runs on every keystroke** in the URL/API-key text
  fields (`onChanged`). Cheap because SharedPreferences writes are async
  but small. Don't debounce prematurely.
- **`_toggleUploadOptIn` refuses to enable uploads unless both URL and API
  key are filled** — this is the single validation gate for the entire
  upload feature.
- **`_testConnection` hits `/health`**, which the backend leaves open
  (no auth). It's a diagnostic — the auth-check happens implicitly on the
  next real upload.
- **"Delete all" wipes SharedPreferences too** — the app will re-enter
  the consent flow on next launch. Keep the confirmation dialog.

### SessionsScreen

- **Not reactive to StorageService writes.** Loads `_sessions` in
  `initState` and re-reads after any mutation via `setState`. If you add a
  path that mutates the index elsewhere while this screen is open, plumb an
  explicit refresh.
- **`_uploading` is a `Set<String>` of session IDs currently uploading.**
  The list item swaps to a spinner while its ID is in the set, and the
  popup menu disappears until it clears. Don't share this state with
  HomeScreen's auto-upload.
- **List title falls back to timestamp** when `description` is null/empty.
  The stats line always shows duration · samples · target Hz. The status
  line ends with either "Not uploaded" or `Uploaded <timestamp>`.
- **"Re-upload" and "Upload to backend" are the same action** — the label
  just adapts to whether `isUploaded`. The backend will 409 on duplicate
  session IDs, so re-upload will fail unless the session was deleted
  server-side first. (Consider surfacing this if it becomes a common trap.)

### OnboardingScreen

- **Height / weight inputs allow decimals** (`[0-9.]` filter). Age is
  digits-only, max 3 chars.
- **Gender dropdown has an explicit "—" option** mapped to `null` so the
  user can clear their choice.
- **`_save` always calls `ensureUserProfile`** before applying edits. On
  first-run the profile was already created by `ConsentScreen`, but the
  double-check is defensive against navigating here in odd orders.

### ConsentScreen

- **Stateless.** All copy is inline; sections use a private `_Section`
  helper widget at the bottom of the file. If you translate the app, this
  is one of the two screens with the most user-facing prose (the other is
  Preferences).
- **The "18+" line at the bottom is legally load-bearing** for the store
  listings' age gate. Don't remove without a legal review.

## Navigation

Screens use plain `MaterialPageRoute` + `Navigator.push` / `pushReplacement`.
No named routes, no router library. `pushReplacement` is used **only** for
first-launch transitions (Consent → Onboarding → Home) so Back doesn't
regress users into a completed step.
