# MovieGPT — Crash Fix Report

## Root Cause of the Crash

**The `.env` file (containing `TMDB_API_KEY`) was NOT declared in `pubspec.yaml`'s `assets:` section.**

### What happened, step by step

1. `main.dart` calls `dotenv.load(fileName: '.env')` at startup. Because `.env` was **not** listed under `flutter: assets:` in `pubspec.yaml`, Flutter did **not** bundle it into the APK. At runtime, `dotenv.load()` throws a `FileSystemException` ("Cannot load file .env ...").

2. The `try/catch` in `main.dart` swallowed that exception (so the app did not hard-crash right there), but as a result **the TMDB API key never loaded**.

3. `EnvConfig.tmdbApiKey` returned an empty string → `EnvConfig.hasApiKey == false`.

4. Every TMDB API call in `TmdbApiService._get()` threw `TmdbApiException('TMDB API key not configured. Add TMDB_API_KEY to your .env file.')`.

5. `MovieRepository.getFeatured()` / `getTrending()` / etc. rethrew `Exception('TMDB API key not configured')`.

6. The Home screen's Riverpod `FutureProvider`s all entered the **error** state. In release builds, the global `ErrorWidget.builder` fallback (in `main.dart`) displayed the branded:
   > **"Something went wrong / An unexpected error occurred."**

   and Android killed the app → the user saw:
   > **"MovieGPT closed because this app has a bug."**

### Why the build/tests passed but the app crashed at runtime

- `flutter analyze` and `flutter test` do **not** execute `dotenv.load()` against the real bundled asset list, so they could not catch the missing asset.
- `flutter build` only *warns* about some missing assets but the `.env` bundling was silently skipped because it wasn't declared.
- The crash was purely a **runtime** issue triggered by the API key never being available.

---

## The Fix

### `pubspec.yaml`
Added `.env` to the `flutter: assets:` list so it is bundled into the APK and resolvable at runtime:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - .env
```

**Verified:** After `flutter pub get` and a rebuild, the bundled asset exists at:
```
build/app/intermediates/flutter/debug/flutter_assets/.env
```

---

## Additional Hardening (added during this session)

### `lib/services/api_client.dart`
Fixed a **security leak**: the Dio `LogInterceptor` previously logged the full request URI — including the `api_key` query parameter — which would expose the TMDB key in debug logs. Added a custom `logPrint` that redacts `api_key=...` → `api_key=***`.

### `lib/services/tmdb_api_service.dart`
Improved error diagnostics: on failure, the debug log now prints the endpoint, HTTP status, Dio error type, network/timeout flags, and the TMDB `status_message` — without ever printing the API key.

---

## Verification

| Check | Result |
|-------|--------|
| `flutter pub get` | ✅ Got dependencies |
| `flutter analyze` | ✅ **0 issues** |
| `flutter test` | ✅ **27/27 tests passed** |
| `flutter build apk --debug` | ✅ Built `app-debug.apk` |
| `.env` bundled in APK | ✅ Confirmed in `flutter_assets/.env` |

---

## API / Firebase Configuration Still Required (by you)

1. **TMDB API key** — already present in your local `.env` (`TMDB_API_KEY=...`). The `.env` is gitignored, so it is not committed. **Do not commit it.**
   - For production, prefer `flutter build apk --release --dart-define=TMDB_API_KEY=...` so the key is injected at build time instead of shipped as a plaintext asset.

2. **Firebase** — `android/app/google-services.json` is **absent** and `lib/firebase_options.dart` contains **placeholder** keys. The app runs in guest mode without Firebase, but Google/Phone sign-in will show a friendly error until you run:
   ```
   flutterfire configure
   ```
   This generates the real `google-services.json` + `firebase_options.dart`. Follow `FIREBASE_SETUP.md` to enable Google + Phone sign-in in the Firebase Console and register SHA-1/SHA-256 fingerprints.

---

## Files Changed

- `pubspec.yaml` — added `.env` to assets (the actual crash fix)
- `lib/services/api_client.dart` — redact API key in logs (security)
- `lib/services/tmdb_api_service.dart` — richer, safe error diagnostics
- `CRASH_FIX_REPORT.md` — this report

---

## Trailer — Theater-Style Player (additional work)

### `pubspec.yaml`
Added `wakelock_plus: ^1.2.10` so the trailer screen can keep the display awake during playback and release it on close (screen-wake prevention).

### `lib/screens/trailer_screen.dart` (rewritten for theater mode)
The trailer player was rebuilt as a clean, theater-style screen that shows **only the video**:

- **Auto-fullscreen + forced landscape** on open (`SystemUiMode.immersiveSticky` + `DeviceOrientation.landscapeLeft/Right`).
- **Hides all YouTube UI that the API legally permits** via `YoutubePlayerParams`:
  - `showControls: false` → no progress bar, play/pause, settings, CC, share, title.
  - `showFullscreenButton: false` → we manage fullscreen ourselves.
  - `enableCaption: false`, `enableKeyboard: false`.
  - `showVideoAnnotations: false`, `strictRelatedVideos: true`.
- **Pure black background** around a 16:9-aspect-ratio player (no stretching — video is centered and letterboxed naturally).
- **Autoplay** immediately on open.
- **Screen-wake** via `WakelockPlus.enable()`; released with `WakelockPlus.disable()` in `dispose()`.
- **Restores orientation + system UI + wakelock** on exit/back (via `PopScope`).
- **Lifecycle handling** — pauses when backgrounded, resumes when foregrounded.
- **Proper disposal** — controller `close()`, animations disposed, observer removed.
- **Loading / unavailable / error states** — a subtle spinner on black, a "Trailer Not Available" fallback, and an error + retry state.
- **Crash-safe**: the YouTube controller is created in a `ref.listen` + `addPostFrameCallback` (never synchronously in `build()`), and playback state is rendered reactively via `YoutubeValueBuilder` — preventing the "setState() during build" exception.

> **Legal/technical note (documented in the code):** TMDb only supplies YouTube video IDs (no direct MP4/HLS URL), so the officially supported IFrame API is used. The YouTube IFrame API permits hiding controls, captions, annotations, related videos and the fullscreen button — all of which we hide. The small YouTube logo watermark is YouTube-owned and cannot be removed by any compliant embed config; that is the only on-screen element that remains.

### `lib/data/movie_repository.dart`
`getPrimaryTrailer()` now selects the best video with the full TMDb videos-priority spec:
1. Official English trailer → 2. Official Hindi trailer → 3. Any official trailer → 4. Any full trailer → 5. Teaser (EN/HI then any) → 6. First available YouTube video. Returns `null` when no YouTube video exists. Added debug-only `[MovieGPT][Trailer]` logging to diagnose which video is selected.

### Verification (after trailer changes)
| Check | Result |
|-------|--------|
| `flutter pub get` | ✅ wakelock_plus resolved |
| `flutter analyze` | ✅ **0 issues** |
| `flutter test` | ✅ **27/27 tests passed** |
| `flutter build apk --debug` | ✅ Built `app-debug.apk` (206 MB)

---

## Remaining Notes

- The `.env` is referenced in `pubspec.yaml` but gitignored. If another developer clones the repo without a local `.env`, the build will error on the missing asset. Consider adding a `.env.example` (with a placeholder, no real key) to the repo for onboarding, and document that a real `.env` must be created locally.
- Firebase sign-in requires real configuration (see section above).
