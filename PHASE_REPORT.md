# MovieGPT — Part 1: Stabilization Audit & Fixes — Report

**Status:** ✅ Complete
**Deliverables verified:** `flutter analyze` clean · `flutter test` passing · debug APK builds successfully

This report documents every issue identified during the full technical audit of the
MovieGPT Flutter project and the fixes applied. No UI was redesigned in this phase —
all changes are backend/startup/architecture/data-stability focused.

---

## 1. Executive Summary

The project was audited across all six phases. The codebase was already in good shape
(clean analyzer, passing tests, working offline cache). The audit focused on:

- **Removing dead code** (unused providers, widgets, constants).
- **Eliminating duplicate logic** (redundant providers).
- **Fixing misleading configuration** (an un-bundled font declaration).
- **Eliminating the Android startup white flash** to match the dark theme.
- **Fixing a latent data bug** where paginated lists shared a single cache key.
- **Verifying** Firebase, TMDB, DB, and startup stability paths already present.

No crashes, red screens, or runtime exceptions were introduced or found to be active.

---

## 2. Phase 1 — Complete Project Audit

### Issues Found & Fixed

| # | Category | File | Issue | Fix |
|---|----------|------|-------|-----|
| 1 | Dead code | `lib/state/providers.dart` | `FavoritesNotifier` + `favoritesProvider` were defined but never used anywhere in the app (the app uses `WatchlistNotifier`). | Removed both. |
| 2 | Duplicate logic | `lib/state/providers.dart` | `upcomingBlockbustersProvider` was a duplicate of `forYouMoviesProvider` (both call `getForYou()`). | Removed `upcomingBlockbustersProvider`. |
| 3 | Unused widget | `lib/widgets/typing_indicator.dart` | `TypingIndicator` public widget was unused; `ai_chat_screen.dart` has its own private `_TypingDots`. | Deleted the file. |
| 4 | Unused constant | `lib/config/env_config.dart` | `imageBaseUrl` was never referenced. | Removed the constant. |
| 5 | Misleading config | `lib/theme/app_theme.dart` | `fontFamily: 'Inter'` was declared but the `Inter` font is **not bundled** in the project — Flutter would silently fall back to the default font. | Removed the declaration. |
| 6 | Startup flash | `android/app/src/main/res/drawable/launch_background.xml` | The launch background was white, causing a flash on app start before Flutter drew the dark theme. | Switched the launch background to dark `#0D0D0D`. |
| 7 | Startup theme | `android/app/src/main/res/values/styles.xml` | `LaunchTheme` + `NormalTheme` used `Theme.Light.NoTitleBar` (light system theme). | Changed both to `Theme.Black.NoTitleBar` with the dark launch background to eliminate the white flash. |
| 8 | Cache bug | `lib/data/movie_repository.dart` | Paginated methods (`getPopular`, `getTopRated`, `getByGenre`) used a **single** cache key per endpoint, so page 2 would overwrite page 1's disk/memory cache. | Made cache keys page-aware (`popular-page-$page`, etc.). |

### Issues Audited & Confirmed OK (no change needed)

- **Analyzer:** `flutter analyze` → `No issues found`.
- **Null safety:** All models use null-safe parsing helpers (`_asMap`, `_asList`, `_asStringMap`) and never throw on malformed data.
- **Dependency conflicts:** `flutter pub get` resolves cleanly; no version conflicts.
- **Missing permissions:** `INTERNET` permission present in `AndroidManifest.xml`.
- **Memory leaks:** All `AnimationController`s, `Timer`s, `ScrollController`s, and the YouTube player controller are disposed in `dispose()`.
- **Widget lifecycle:** `mounted` checks guard all async post-dispose state updates.
- **Navigation:** `PopScope` correctly handles the trailer screen's back gesture; routes use `pushReplacement`/`pushAndRemoveUntil` appropriately.

---

## 3. Phase 2 — Startup Stability

### Already Present & Verified ✅

- **Global exception handler:** `lib/main.dart` installs `FlutterError.onError`, overrides `ErrorWidget.builder` (release → branded fallback, never a raw red screen), and wraps the app in `runZonedGuarded` to catch uncaught async errors.
- **Error logging:** Uncaught errors are logged via `debugPrint` with a `[MovieGPT]` prefix.
- **Graceful error + retry:** Every screen (Home, Search, Details, Collection, Trailer) has explicit loading / error / retry states.
- **Safe fallback:** Network failures fall back to cached data so the UI is never blank.
- **Firebase init is non-blocking:** `Firebase.initializeApp` is wrapped in try/catch; the app continues in guest mode if Firebase isn't configured.
- **`.env` load is best-effort:** Missing `.env` does not block startup.

### Fixes Applied

- Removed the Android **white startup flash** (launch background + theme) so the app opens directly into its dark cinematic theme. This also removes the jarring "blank/white" flash the task explicitly forbids.

---

## 4. Phase 3 — Firebase

### Verified ✅

- **`firebase_options.dart`:** Present with `FirebaseOptions` for Android/iOS/macOS. Currently contains **placeholder** values (documented) — real values require `flutterfire configure` with the user's Firebase project.
- **`google-services.json`:** **Not present** (`android/app/`). The Gradle build intentionally only applies the Google Services plugin when this file exists, so the project builds/runs in guest mode without it.
- **Firebase init:** Handled gracefully in `main.dart` (try/catch, non-blocking).
- **Auth (Google + Phone):** Fully implemented in `lib/services/auth_service.dart` with:
  - Duplicate/concurrent sign-in guard (`_signInInProgress`).
  - User-friendly error mapping (`_mapFirebaseAuthException`).
  - Phone OTP auto-verification + resend support.
  - Session persistence via Firebase's built-in auth state restoration (`authStateChanges`).
  - `AuthService` exposes `authStateChanges` → used by `authStateProvider` (Riverpod) → drives splash routing.

### Action Required (Manual — requires the user's Firebase account)

```
# From the project root:
flutterfire configure --project=YOUR_PROJECT_ID
```

This regenerates `lib/firebase_options.dart` with real keys **and** downloads
`android/app/google-services.json`. Full instructions are in `FIREBASE_SETUP.md`.

> **Note:** The app **does not currently use** Firestore, Realtime Database, or
> Firebase Storage. Auth state and watchlists are stored locally (SharedPreferences).
> When those services are added, they will be gated behind the same
> `google-services.json` presence check.

---

## 5. Phase 4 — Database

### Audit Result

- **Collections:** The app does not use Firestore/Realtime DB. Data lives in:
  - **TMDB API** (remote movie data).
  - **SharedPreferences** (offline list cache + watchlist).
- **Offline persistence:** `MovieRepository` caches all list fetches to disk via
  `SharedPreferences` (`_persistToDisk` / `_loadFromDisk`) and falls back on network failure.
- **Watchlist persistence:** `WatchlistNotifier` loads/saves to SharedPreferences (`moviegpt_watchlist_v1`).
- **Data validation:** All JSON parsing is null-safe; corrupt caches are ignored silently.
- **Prevention of data loss:** Cache writes are best-effort and never throw; corrupt entries are skipped.

### Fixes Applied

- Made the disk/memory list cache keys **page-aware** so paginated data isn't overwritten
  (prevents a subtle data-loss/overwrite bug across pages).

---

## 6. Phase 5 — TMDB Backend

### Verified ✅

- **API key injection:** `ApiClient` guarantees the `api_key` is merged into *every* request via a Dio interceptor (prevents silent 401s). Key resolved from `--dart-define` or `.env`.
- **Correct endpoints:** `now_playing`, `popular`, `top_rated`, `upcoming`, `trending`, `discover`, `movie/{id}` (with `append_to_response`), `search`, `genre/movie/list`.
- **Retry logic:** `TmdbApiService._get` retries transient failures (timeouts, connection errors, 429/503/408) up to 2× with backoff.
- **Error classification:** Distinct user-friendly messages for 401/403/404/500/timeout/network.
- **Empty responses:** Handled with graceful empty-state UI in every screen.
- **Request deduplication:** `MovieRepository` caches details bundles in-memory (`_bundleCache`) and reuses `getMovieDetailsBundle` across cast/trailers/similar.
- **Local cache:** Lists cached to disk; details cached in memory.
- **Pagination:** Supported via `page` params; now with distinct cache keys per page (fix applied).

---

## 7. Phase 6 — Code Quality

### Removed
- Unused `FavoritesNotifier` + `favoritesProvider`.
- Duplicate `upcomingBlockbustersProvider`.
- Unused `TypingIndicator` public widget.
- Unused `imageBaseUrl` constant.
- Misleading un-bundled `fontFamily: 'Inter'`.

### Confirmed Clean
- `flutter analyze` → **No issues found**.
- `flutter test` → **All tests passed** (2 test files, 3 tests).
- No unused packages detected in `pubspec.yaml` (all listed deps are actually imported).

---

## 8. Verification Results

| Check | Result |
|-------|--------|
| `flutter analyze` | ✅ No issues found (21.2s) |
| `flutter test` | ✅ All tests passed |
| `flutter build apk --debug` | ✅ Built `app-debug.apk` (58.3s) |

---

## 9. Deferred / Manual Items (not code issues)

These require the end user's Firebase credentials / console access and are **not**
code defects. They are documented in `FIREBASE_SETUP.md`:

1. Run `flutterfire configure` to generate real `google-services.json` + `firebase_options.dart`.
2. Register the Android app's SHA-1/SHA-256 fingerprints in the Firebase console.
3. Enable **Google** and **Phone** sign-in providers in Firebase Authentication.
4. (For Firestore/Storage/RTDB phases) configure those services and set up security rules.

---

## 10. Final Deliverables Status

| Deliverable | Status |
|-------------|--------|
| `flutter analyze` passes | ✅ |
| Stable startup (no white flash, no red screen, no blank state) | ✅ |
| Firebase auth wired (Google + Phone) — needs user config for live keys | ✅ (code) / ⏳ (config) |
| TMDB working (retry, errors, cache, dedup) | ✅ |
| Backend/DB production-ready (offline cache, null-safe, validated) | ✅ |
| UI not redesigned | ✅ |
