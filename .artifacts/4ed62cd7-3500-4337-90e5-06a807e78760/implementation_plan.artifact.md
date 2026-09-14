# Implementation Plan - Movie Poster System Update

Completely update the movie poster system to use TMDB as the single source of truth, removing all obsolete local movie poster assets and ensuring a consistent, high-quality cinematic UI across the entire application.

## User Review Required

> [!IMPORTANT]
> This change will remove all local movie poster assets from `assets/images/`. After the update, the app will require an internet connection or previously cached images to display movie posters. Branding assets (logos, splash sounds) will be preserved.

## Proposed Changes

### Data Layer & Models

#### [MODIFY] [movie_model.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/models/movie_model.dart)
- Remove `posterAsset` and `backdropAsset` fields from `Movie` and `CastMember` classes.
- Update `fromJson`, `toStorageJson`, and `fromStorageJson` to exclude these fields.
- Enhance `posterUrl` and `backdropUrl` methods to handle size prefixes and provide fallback logic.

### UI Components

#### [NEW] [movie_poster.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/widgets/movie_poster.dart)
- Create a reusable `MoviePoster` widget.
- Support `posterPath`, `width`, `height`, `radius`, and `BoxFit`.
- Use `CachedNetworkImage` with cinematic placeholders and error widgets.
- Implement consistent 2:3 aspect ratio handling.
- Use a dark cinematic placeholder with the MovieGPT "M" logo for loading/error states.

#### [MODIFY] [movie_card.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/widgets/movie_card.dart)
- Replace internal poster loading logic with the new `MoviePoster` widget.
- Remove `_PosterImageAsset` and `_PosterImageNetwork`.
- Ensure consistent 2:3 aspect ratio and responsive dimensions.

### Screens Integration

#### [MODIFY] [home_screen.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/screens/home_screen.dart)
- Update `_HeroImage` to use `MoviePoster` or consistent TMDB URL logic.
- Ensure all movie carousels use the updated `MovieCard`.

#### [MODIFY] [movie_details_screen.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/screens/movie_details_screen.dart)
- Update `_HeroBackdrop` to strictly use TMDB backdrop/poster URLs.
- Remove `_assetFallback` which used local assets.
- Update `_CastCard` to only use TMDB profile URLs.

#### [MODIFY] [ai_chat_screen.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/screens/ai_chat_screen.dart)
- Update `_MiniMovieCard` to use the new `MoviePoster` widget for consistency.

#### [MODIFY] [search_screen.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/screens/search_screen.dart) and [watchlist_screen.dart](file:///C:/FLUTTER/FLUTTER PROJECTS/MovieGPT/lib/screens/watchlist_screen.dart)
- Verify `MovieCard` usage and ensure no hardcoded local assets are used.

### Asset Cleanup

#### [DELETE] Obsolete movie poster assets in `assets/images/`
- Identify and remove all movie-content PNGs/JPGs.
- **PRESERVE**: `moviegpt_logo.png`, `moviegpt_logo_foreground.png`, `moviegpt_logo_transparent.png`, and `assets/sounds/splash_sound.wav`.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no broken references.
- Run `flutter test` (if applicable) to check for regression in movie models.

### Manual Verification
- Verify Home Screen: Featured movie, Trending, Recommended, AI Top Picks, Popular, Top Rated, Upcoming sections all show TMDB posters.
- Verify Search: Search results show correct TMDB posters.
- Verify Movie Details: Poster and Backdrop are loaded from TMDB.
- Verify AI Chat: Recommended movie cards show TMDB posters.
- Verify Watchlist: Saved movies show TMDB posters.
- Verify Error States: Disconnect internet and verify the "dark cinematic placeholder" appears.
