# MovieGPT — Part 2: Premium UI, Splash Animation & User Experience — Task Tracker

## Phase 1 — Premium Splash Animation
- [x] Rewrite `splash_screen.dart` with original superhero-inspired cinematic intro
- [x] Moving light rays + cinematic smoke
- [x] Metallic silver "M" + gold highlights + lens flare
- [x] Blue + red energy particles + floating sparks + energy fragments
- [x] Metallic "MovieGPT" text + light streak + camera zoom + smooth fade
- [x] ~4.5s duration, GPU-accelerated, no leaks, preserves auth navigation

## Phase 2 — Home Screen Polish
- [x] Add Top Rated + Upcoming sections (providers exist)
- [x] Replace spinner loaders with skeleton loaders (reuse ShimmerBox)
- [x] Hero skeleton shimmer
- [x] Pull-to-refresh includes new sections

## Phase 3 — UI Review Across Pages
- [x] movie_details_screen: skeleton loaders + overflow audit
- [x] search_screen: skeleton + polish
- [x] collection_screen: skeleton + polish
- [x] watchlist_screen: polish empty/loading states
- [x] profile_screen: polish

## Phase 4 — Trailer System
- [x] Review youtube_player_iframe config (quality, adaptive, fallback)
- [x] Verify no browser opens; portrait/landscape smooth

## Verification
- [x] flutter analyze
- [x] flutter test
- [x] flutter build apk --debug
