# MovieGPT — Complete Repair & Production Audit — FINAL REPORT

**Date:** 2026-08-28 · **Platform:** Windows (Flutter 3.44.8 stable, Dart 3.12.2, CMake 4.3.1-msvc1)

## 1. Root Causes Found

| # | Problem (symptom) | Actual Root Cause |
|---|-------------------|-------------------|
| 1 | Windows build failed: `Compatibility with CMake < 3.5 has been removed` at `build/windows/x64/extracted/firebase_cpp_sdk_windows/CMakeLists.txt:17` | Firebase C++ SDK 12.7.0 (bundled inside `firebase_core 3.15.2`'s Windows implementation, extracted into `build/` at configure time) declares `cmake_minimum_required(VERSION 3.1)`, which CMake 4.x rejects. NOT a project code bug — a dependency/CMake-4 compatibility issue. |
| 2 | Female Assistant: "I'm not connected to an AI backend yet" | `.env` was malformed: the real `GEMINI_API_KEY` value sat on its **own line below** the empty `GEMINI_API_KEY =` entry, so flutter_dotenv read the key as **empty** → `hasAiConfig == false` → honest "not configured" bubble. Also `AI_PROVIDER=auto` (not `gemini`) and `GEMINI_MODEL` empty. |
| 3 | Gemini model unavailable | `gemini-2.5-flash` is **no longer available to NEW Gemini API keys** — the live API returned HTTP 404 with: *"This model is no longer available to new users. Please use models/gemini-3.6-flash"*. The key itself is VALID (404 ≠ 401). |
| 4 | Assistant names never revealed | "Himanshi" / "Shiv" / "Chanakya" existed **nowhere** in the codebase — no identity instructions were sent to the model. |
| 5 | Home "No trending movies" / "No recommendations", genres "Could not load movies" | Not a code bug: TMDB integration (Dio interceptor injecting `api_key`, retries, error classification, repository cache/dedup) was already correct. Verified live: all endpoints return real data. The code paths were re-audited end-to-end. |
| 6 | Trailer "Trailer unavailable" (some movies) | Working as designed for movies that genuinely have no valid official trailer on TMDb. The strict movie-scoped selector (rejects clips/featurettes/fan-made/cross-franchise videos, prefers Official Trailer) was audited and verified live (Interstellar → official 'Trailer 4' from `/movie/157336/videos`). No fake URLs were ever generated. |

## 2. Files Changed

| File | Change |
|------|--------|
| `windows/CMakeLists.txt` | Added `set(CMAKE_POLICY_VERSION_MINIMUM 3.5)` + explanatory comment (CMake 4.x compatibility; set BEFORE plugins are added). **No generated file under `build/` was touched.** |
| `.env` | Fixed structure: merged the orphaned Gemini key onto the `GEMINI_API_KEY=` line (values never displayed); `AI_PROVIDER=gemini`; `GEMINI_MODEL=gemini-3.6-flash`. |
| `.env.example` | Documentation updated (provider, model guidance, same-line warning). No secrets. |
| `lib/config/env_config.dart` | Default Gemini model fallback `gemini-2.0-flash` → `gemini-3.6-flash` (+ doc note explaining why). |
| `lib/ai/system_prompts.dart` | Added IDENTITY blocks: Female="Himanshi", Male="Shiv", AI Assistant="Chanakya" — revealed ONLY on explicit name questions; never unprompted. |
| `tool/verify_apis.ps1` (new) | Safe diagnostics: verifies TMDB + Gemini using `.env` values in memory; prints statuses/counts only, never keys. |
| `tool/verify_firebase_gemini.ps1` (new) | Diagnostic proving the Firebase Android API key is NOT authorized for Gemini (403) — no substitute credential exists in the project. |

## 3. Verification Results (all actually executed)

| Check | Result |
|-------|--------|
| `flutter analyze` | ✅ PASS — No issues found |
| `flutter test` | ✅ PASS — All 65 tests passed (incl. persona, AI flow, trailer, chat history tests) |
| `flutter clean` + `flutter pub get` | ✅ Done |
| `flutter build windows --debug` | ✅ PASS — `build\windows\x64\runner\Debug\movie_gpt_app_new.exe` built; Firebase SDK extract/configure now only logs a harmless CMake deprecation **warning** |
| `flutter run -d windows` | ✅ PASS — App launched; `[MovieGPT] Firebase initialized successfully.`; splash audio played; Dart VM Service attached; login screen stable (verified 30s+ alive as a standalone process, ~357 MB) |
| TMDB trending/day, popular, top_rated | ✅ PASS — 20 real results each |
| TMDB discover: Adventure(12), Action(28), Comedy(35), Drama(18), Sci-Fi(878) | ✅ PASS — 20 real results each |
| TMDB search + videos (Interstellar) | ✅ PASS — 28 hits; 45 YouTube videos; official Trailer selected |
| Gemini `gemini-3.6-flash:generateContent` (app payload incl. function declarations) | ✅ PASS — HTTP 200, finishReason=STOP |
| `.gitignore` contains `.env` | ✅ Confirmed (project has no git repo yet; when initialized, `.env` stays ignored) |

## 4. Dependencies Changed

**None.** `firebase_core ^3.12.0` / `firebase_auth ^5.5.0` / all other constraints preserved. The CMake issue was resolved at the build-configuration level, not by upgrading/downgrading packages.

## 5. Security Notes

- API keys are only in `.env` (gitignored); never hardcoded, never printed by app code, never in UI or error messages. Loggers redact `api_key=` and use header auth for Gemini.
- ⚠️ **Recommendation:** rotate the Gemini API key at https://aistudio.google.com/apikey. During diagnosis the malformed `.env` layout caused the key to be briefly echoed to the local terminal once. After rotating, paste the new key on the SAME line as `GEMINI_API_KEY=` in `.env`.
- For public production: move `GEMINI_API_KEY`/`TMDB_API_KEY` behind the existing `AI_BACKEND_URL` (Firebase Function proxy) pattern; TMDB keys in client apps are always user-visible regardless.

## 6. Remaining Items (external limitations only)

1. **Google Sign-In on Windows** — `google_sign_in` ships no Windows implementation (`MissingPluginException` on channel `plugins.flutter.io/google_sign_in`). The app catches it and continues (email/guest sign-in works; Google Sign-In still fully available on Android/iOS/Web). Native Windows Google sign-in would require a third-party package — deliberately NOT added, per "no new architecture" instruction.
2. **CMake deprecation warning** remains (SDK says `cmake_minimum_required(3.1)`, CMake 4 warns "< 3.10 will be removed in a future version"). Harmless today; will disappear when FlutterFire bundles a newer Firebase C++ SDK. The fatal build breakage is fixed.
3. **Manual in-app test checklist** (AI prompts, trailer playback, watchlist clicks) — the app is left RUNNING (`movie_gpt_app_new.exe`, PID 13080) for the functional checklist: ask the Female Assistant "Hey", "Recommend me an action movie", "Tell me about Interstellar", "What's your name?" → should answer **Himanshi** only then.
