# MovieGPT Production-Ready Repair Plan

This plan addresses the critical failures in AI assistant connectivity, movie data loading, trailer selection, and the Windows build configuration, while strictly preserving the existing architecture and visual identity.

## User Review Required

> [!IMPORTANT]
> The Gemini model will be updated to `gemini-2.5-flash` as requested, which is assumed to be the latest stable model in the current context (August 2026).
> The `.env` file will be cleaned of spaces to ensure reliable parsing by `flutter_dotenv`.

## Proposed Changes

### Configuration & Environment

#### [MODIFY] [.env](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/.env)
- Remove spaces around `=` for all keys.
- Update `GEMINI_MODEL` to `gemini-2.5-flash`.
- Ensure `AI_PROVIDER=gemini`.

#### [MODIFY] [env_config.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/config/env_config.dart)
- Update default `geminiModel` fallback to `gemini-2.5-flash`.
- Update comments regarding model availability.

---

### TMDB Service

#### [MODIFY] [tmdb_api_service.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/services/tmdb_api_service.dart)
- Fix syntax error in `getByCountry` (remove `?` from `originalLanguage`).
- Ensure `originalLanguage` parameter is handled correctly as an optional query parameter.

---

### AI Assistant

#### [MODIFY] [ai_service.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/services/ai_service.dart)
- Add more granular logging for configuration status to aid debugging without exposing keys.
- Ensure the `_resolvedProvider` correctly handles the case where `AI_PROVIDER` might have extra whitespace (defensive check).

---

### Trailer System

#### [MODIFY] [trailer_service.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/services/trailer_service.dart)
- Relax `_knownFranchiseSubtitles` check: only reject if there is a *conflict*, but be more inclusive of subtitles that might be part of the official trailer title even if slightly different from the TMDB title.
- Prioritize "Official Trailer" more strongly but fall back to any verified trailer if no official one exists.

---

### Windows Build

#### [MODIFY] [CMakeLists.txt](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/windows/CMakeLists.txt)
- Move `set(CMAKE_POLICY_VERSION_MINIMUM 3.5)` to the absolute top of the file, before `cmake_minimum_required`, to ensure it affects all plugin subdirectories that are added later.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure all syntax errors and linting issues are resolved.
- Run existing tests to ensure no regressions.

### Manual Verification
- **Windows Build**: Execute `flutter run -d windows` and verify it compiles without CMake errors.
- **Home Screen**: Verify "Trending Today" and "Recommended For You" load real TMDB movies.
- **Genre Screen**: Navigate to "Adventure" and verify movies load.
- **AI Chat**: Test Female Assistant with "Hey", "How are you?", and "What is your name?".
- **Trailers**: Open a movie details page and play a trailer.
- **Security**: Verify `.env` is still ignored and no keys are printed in logs.
