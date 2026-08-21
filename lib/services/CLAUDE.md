# CLAUDE.md — lib/services/

Everything with side effects lives here. Three services, each with a single
responsibility:

| File | What it owns |
| --- | --- |
| `storage_service.dart` | SharedPreferences keys, CSV file layout on disk, sessions index CRUD |
| `sensor_service.dart` | IMU stream fan-in + timer-driven emission + `SessionWriter` |
| `har_api.dart` | HTTP client for the FastAPI backend |

## StorageService

**Single instance, created once in `main()` before `runApp`.** Passed to
every screen via constructor. Do not build a second instance.

### SharedPreferences key catalog

| Key | Type | Purpose |
| --- | --- | --- |
| `consent_accepted_v1` | bool | Consent gate for `_Router` |
| `user_profile_v1` | String (JSON) | `UserProfile.encode()` |
| `max_recording_minutes` | int | From `preferences_screen.dart` chips (5/15/30/60/120) |
| `sessions_index_v1` | StringList | Encoded `SessionMetadata` entries |
| `backend_base_url` | String | User-entered backend URL |
| `backend_api_key` | String | `X-API-Key` value |
| `backend_upload_opt_in` | bool | Master switch for auto-upload on Stop |

Keys are private constants at the top of the file. **The `_v1` suffix
matters** — if you ever break the encoding, bump the suffix and add a
migration path rather than silently reading garbage.

### File layout

```
<app documents>/sessions/<session-uuid>.csv
```

- `createSessionFile(sessionId)` returns the `File` handle;
  `_sessionsDir()` creates the folder lazily.
- `sessionFileFullPath(relativePath)` resolves the relative index entry
  back to an absolute path. **Always go through this** — iOS sandbox paths
  can change between installs, so absolute paths in the index would rot.
- `deleteSession` removes both the index entry and the file.
- `wipeAll` deletes every CSV *and* calls `_prefs.clear()` (nukes consent
  and profile too — used by the Preferences "Delete all" action).

### Sessions index invariants

- Sorted **newest first** by `startedAt` on read (`listSessions`).
- `addSession` appends; **no dedup**. Session UUIDs are v4 so collisions
  are effectively impossible, but nothing enforces uniqueness at this layer.
- `markSessionUploaded` rewrites the whole list. Fine at current scale (~
  handful of sessions per user), watch it if that ever changes.

## SensorService

### Why the timer, not raw events

`sensors_plus` treats the sampling period as a **hint** — the OS may deliver
faster or slower, and per-sensor timestamps don't line up. To get aligned
rows at exactly the target frequency we:

1. Ask each of the three streams for a period ≈ 0.8× the target
   (`sensor_service.dart:46-48`) so a fresh value is usually available.
2. Cache the most recent `(x, y, z)` from each stream into `_ax/_ay/...`
   fields with `_haveAccel/_haveGyro/_haveMag` flags.
3. Emit one `SensorSample` on a periodic timer at `1_000_000 / targetHz` µs.
4. Skip emission until all three flags are true — the first tick with a
   full row wins.

Don't "simplify" this to per-event emission. The whole point is the fixed
grid.

### Lifecycle

- `start()` is idempotent (guarded by `isRunning`).
- `stop()` cancels the timer and all subscriptions and resets the "have"
  flags so a subsequent `start()` re-primes cleanly.
- `dispose()` closes the broadcast controller — call from screen `dispose`
  so the stream doesn't leak.

### SessionWriter

Buffers CSV rows in memory and flushes every `flushEvery` rows
(default 256). Rationale: at 34 Hz that's a flush every ~7.5 s, which
matters on some Android devices where per-line writes cause noticeable
sample jitter. The header line is written on `open()`. Always call `close()`
before writing metadata — the final flush happens there.

## HarApi

Thin HTTP client. **Instances are per-call**: the callers in
`home_screen.dart` and `sessions_screen.dart` build a `HarApi`, use it in a
`try`/`finally`, and `close()` it. Do not cache one at file scope — API
key / URL can change from Preferences at any time.

### Timeouts

- `_defaultTimeout = 30s` for JSON endpoints (`upsertUser`, `deleteSession`,
  `health`).
- Upload uses `5 minutes` (`har_api.dart:107`). Coordinated with the
  backend's Caddy read/write timeouts (10 minutes) — do not tighten
  without checking the backend Caddyfile.

### Upload contract (must not drift from the backend)

`uploadSession` sends a multipart POST to `/v1/sessions`:

- `X-API-Key` header
- `metadata` form field: JSON with `id, user_id, started_at (UTC ISO-8601),
  duration_ms, sample_count, target_hz, [description],
  csv_uncompressed_bytes, csv_sha256`
- `file` form field: gzip-encoded CSV bytes, filename `<uuid>.csv.gz`

The server re-computes SHA-256 and uncompressed length and rejects
mismatches with HTTP 400 (see the backend's
`app/routes/sessions.py:35-62`). So the client must:

- Read the **uncompressed** CSV to compute `sha256` and `csv_uncompressed_bytes`.
- Gzip *only for transport*.

`deleteSession` treats 404 as a success (`har_api.dart:126`) — deleting an
already-deleted session is a no-op, not an error.

### Gender mapping

`_genderApiValue` (`har_api.dart:135`) maps the Dart `Gender` enum to
stable short strings (`male | female | other | prefer_not_to_say`). Keep
these stable — re-uploading the same profile should be a no-op on the
backend.

### Error handling

- `health()` returns `bool`, swallowing every exception. It's a diagnostic;
  the caller only decides whether to show "connected" or "not connected".
- Everything else throws `HarApiException` on non-2xx and lets the caller
  surface a SnackBar. Callers must always wrap in `try`/`finally` and
  `close()` the client.
