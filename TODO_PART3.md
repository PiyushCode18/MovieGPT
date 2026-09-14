# MovieGPT — Part 3: AI, Performance Optimization & Production Release — Task Tracker

## Phase 1 — AI Recommendation System
- [x] Create `lib/services/ai_recommendation_service.dart` (intent detection, context, fallback, typed errors)
- [x] Add `ChatHistoryNotifier` (persist max 50 msgs, corrupt-safe, clear wipes history, no secrets)
- [x] Persist `ChatMessage` to/from JSON (recommendations included)
- [x] Rewrite `ai_chat_screen.dart` to use history + service + retry + clear conversation
- [x] Test: analyze + test

## Phase 2 — Performance Optimization
- [x] In-flight request dedup in `MovieRepository` (Map<String,Future>, finally-cleanup, full cache keys incl. page & genre)
- [x] TTL (5 min) + stale-cache offline fallback (never blank screen)
- [x] Inspect + configure image cache (bounded ~100 MB memory ceiling, 2000 entries) in `main.dart`
- [x] Selective `RepaintBoundary` (hero, expensive anims) — featured hero isolated in Home
- [x] Reduce rebuilds (message list keyed via `ValueKey(msg.id)`, Home uses lazy slivers)
- [x] Test: analyze + test (16/16 passing)

## Phase 3 — Testing
- [x] `test/ai_recommendation_test.dart` — NEW: pure, deterministic intent-detection tests via `@visibleForTesting` helpers (genre detection, containsAny, extractTitleAfter) + public API (blank text, resetContext, exception message)
- [x] `test/chat_history_test.dart` — history restore, clear, corrupted recovery, retry, maxMessages bounding, recs serialization (already present)
- [x] `test/movie_repository_test.dart` — expanded with model serialization edge cases, `Movie.fromJson` nested credits/director parsing, duration formatting, image URL precedence (network/TTL paths not reliably mockable for singleton repository)
- [x] Run analyze + test (27/27 passing, `flutter analyze` clean)

## Phase 4 — Release Readiness
- [ ] Verify `build.gradle.kts` release signing references key.properties/keystore
- [ ] `flutter clean` + `flutter pub get` + `flutter analyze` + `flutter test`
- [ ] `flutter build apk --debug`
- [ ] `flutter build apk --release` (signed)
- [ ] Manual smoke test checklist
- [ ] Versioning: keep 1.0.0+1 (intended release)
- [ ] Create `PHASE_REPORT_PART3.md` with real results (verified / not tested / blocked separated)
