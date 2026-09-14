# MovieGPT — Ultimate Production Build & Complete Project Rebuild — Task Tracker

## Phase 1 — Full Project Audit
- [x] Baseline: `flutter analyze` clean, `flutter test` 27/27 passing, debug APK builds
- [x] Document all findings in final report

## Phase 2 — Startup & Stability
- [x] Global exception handler + ErrorWidget.builder already in `main.dart`
- [x] `runZonedGuarded` for async errors already present
- [x] Verify no debug-only code leaks into release (ErrorWidget fallback only in release, debugPrint gated by kDebugMode)

## Phase 3 — Premium MovieGPT Intro Animation
- [x] Splash screen already rewritten with cinematic superhero-inspired animation (4.5s)
- [x] Verify it meets all requirements (metallic M, gold highlights, blue/red particles, sparks, lens flare, camera zoom, fade)

## Phase 4 — Firebase
- [x] Verify google-services.json presence/config (NOT present — app handles gracefully via guest mode; build.gradle.kts applies plugin only when file exists)
- [x] Verify Firebase init in main.dart (best-effort try/catch, non-blocking)
- [x] Verify auth state restoration + session persistence (Firebase Auth persists sessions natively; authStateProvider stream restores state)

## Phase 5 — Database
- [x] Local caching (SharedPreferences) + offline persistence already present
- [x] Verify watchlist + chat history persistence (SharedPreferences-backed, validated)

## Phase 6 — TMDB Integration
- [x] Retry logic, timeout handling, error handling in `tmdb_api_service.dart`
- [x] Local cache + request dedup + TTL in `movie_repository.dart`
- [x] Verify all endpoints + image loading (all endpoints correct TMDB paths)

## Phase 7 — Trailer System
- [x] youtube_player_iframe in-app playback, fullscreen, portrait/landscape verified

## Phase 8 — Home Screen
- [x] Hero, trending, popular, top rated, upcoming, AI picks, search, categories all present

## Phase 9 — AI Recommendation System
- [x] AI chat interface, typing indicator, suggested prompts, history, context-aware, fallback

## Phase 10 — UI & UX
- [x] Skeleton loaders, empty/error states, dark theme across screens

## Phase 11 — Performance Optimization
- [x] Image cache config, RepaintBoundary, request dedup, TTL cache

## Phase 12 — Code Quality
- [x] Verify no unused packages/assets (all deps used: dio, riverpod, cached_network_image, shared_preferences, dotenv, firebase, google_sign_in, youtube_player_iframe)
- [x] Verify folder structure (clean lib/ organization: config, data, models, screens, services, state, theme, widgets)

## Phase 13 — Testing
- [x] Verify flutter analyze + all widget tests pass (27/27)
- [x] Verify startup flow test (widget_test.dart smoke test)
- [x] Added `test/ai_recommendation_test.dart` (pure intent detection tests)

## Phase 14 — Release Readiness
- [x] Verify release signing config (key.properties + upload-keystore.jks present)
- [x] Build release APK (app-release.apk built successfully)
- [x] Enhance proguard-rules.pro with explicit keep rules for Firebase/Google/Dio/OkHttp (prevents release-only reflection crashes)
- [x] Verify app icons
- [x] Final report
