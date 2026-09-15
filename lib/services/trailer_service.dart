import 'package:flutter/foundation.dart';

import '../models/movie_model.dart';
import 'tmdb_api_service.dart';

/// Production-grade trailer selection backed by REAL TMDb video data.
///
/// ## Guarantee
/// A trailer is ONLY ever selected from the `/movie/{id}/videos` results for
/// the EXACT TMDb movie being viewed. The flow is:
///
/// ```
/// TMDb movie
///   -> exact TMDb movie id
///   -> /movie/{movieId}/videos
///   -> filter returned videos
///   -> select official trailer
///   -> YouTube video id
///   -> embedded player
/// ```
///
/// We never search YouTube, never pick the first video, never choose a video
/// merely because its title contains a franchise name, and never fall back to
/// another movie's trailer. If the correct trailer cannot be verified we return
/// `null` so the caller shows **"Trailer unavailable"** — never a wrong video.
class TrailerService {
  TrailerService._();

  static final TrailerService instance = TrailerService._();

  final TmdbApiService _api = TmdbApiService.instance;

  /// In-memory cache keyed by TMDb movie ID (never by title — titles collide).
  /// A `null` result is cached as well so a movie with no verified trailer is
  /// not repeatedly re-fetched during one session.
  final Map<int, Trailer?> _cache = {};

  /// All VERIFIED trailers for a movie, keyed by TMDb id.
  ///
  /// Unlike [_cache] (which stores only the single best pick), this stores
  /// every trailer that passed the strict movie-scoped validation so the UI can
  /// offer a language selector containing ONLY real, verified trailers.
  final Map<int, List<Trailer>> _verifiedCache = {};

  /// Video `type` values that must NEVER be auto-selected as the trailer.
  static const Set<String> _excludedTypes = {
    'clip',
    'featurette',
    'behind the scenes',
    'interview',
    'tv spot',
    'short',
    'bloopers',
    'blooper',
    'opening credits',
    'opening sequence',
    'recap',
    'compilation',
    'reaction',
  };

  /// Fan-made / concept / unofficial / unrelated title indicators.
  static const Set<String> _fanMadeIndicators = {
    'concept',
    'fan made',
    'fan-made',
    'fan trailer',
    'mockup',
    'parody',
    'reaction',
    'review',
    'breakdown',
    'commentary',
    're-upload',
    'fan edit',
    'fake trailer',
    'compilation',
    'reaction video',
    'recreated',
  };

  /// Distinct franchise subtitles used to reject a video that clearly belongs
  /// to a DIFFERENT movie within the same franchise (e.g. a "No Way Home"
  /// trailer must never play for "Brand New Day").
  static const Set<String> _knownFranchiseSubtitles = {
    'no way home',
    'far from home',
    'homecoming',
    'brand new day',
    'into the spider-verse',
    'into the spider verse',
    'across the spider-verse',
    'across the spider verse',
    'beyond the spider-verse',
    'beyond the spider verse',
    'amazing spider-man',
    'amazing spider man',
  };

  /// Resolves the official trailer for [movie].
  ///
  /// Uses [Movie.id] as the source of truth. Returns `null` when no correct
  /// trailer can be verified (callers should show "Trailer unavailable").
  Future<Trailer?> getOfficialTrailer(Movie movie) async {
    if (movie.id <= 0) {
      _logUnavailable(movie, 'Invalid TMDb id ${movie.id}');
      return null;
    }
    if (_cache.containsKey(movie.id)) return _cache[movie.id];

    Trailer? selected;
    try {
      // 1. Try fetching without language restriction (usually returns most results).
      var videos = await _api.getMovieVideos(movie.id);
      selected = selectBestTrailer(movie, videos);

      // 2. Fallback: Try en-US specifically if no trailer found.
      if (selected == null) {
        videos = await _api.getMovieVideos(movie.id, language: 'en-US');
        selected = selectBestTrailer(movie, videos);
      }

      // 3. Fallback: Try movie's original language specifically.
      if (selected == null && movie.originalLanguage != 'en') {
        videos = await _api.getMovieVideos(movie.id,
            language: movie.originalLanguage);
        selected = selectBestTrailer(movie, videos);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[TRAILER] Error fetching videos for "${movie.title}" (id ${movie.id}): $e',
        );
      }
      selected = null;
    }

    _cache[movie.id] = selected;
    _logSelected(movie, selected);
    return selected;
  }

  /// Convenience for callers that only have a TMDb id (resolves the movie
  /// first so the exact id drives validation).
  Future<Trailer?> getOfficialTrailerById(int movieId) async {
    if (movieId <= 0) return null;
    if (_cache.containsKey(movieId)) return _cache[movieId];
    try {
      final movie = await _api.getMovieDetails(movieId);
      return getOfficialTrailer(movie);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TRAILER] Could not resolve movie $movieId: $e');
      }
      return null;
    }
  }

  /// Fetches and VALIDATES every trailer for [movie] (never searches YouTube,
  /// never guesses an id, never uses another movie's video).
  ///
  /// Returns the verified subset with `verified=true`. Cached per movie id so
  /// the language selector and language resolution share one network fetch.
  Future<List<Trailer>> getVerifiedTrailers(Movie movie) async {
    if (movie.id <= 0) return const [];
    final cached = _verifiedCache[movie.id];
    if (cached != null) return cached;
    try {
      final videos = await _api.getMovieVideos(movie.id);
      final verified = <Trailer>[];
      for (final v in videos) {
        if (isValidTrailerForMovie(movie, v)) {
          verified.add(v.copyWith(verified: true, source: 'TMDB'));
        }
      }
      _verifiedCache[movie.id] = verified;
      return verified;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[TRAILER] Error fetching verified trailers for "${movie.title}" '
          '(id ${movie.id}): $e',
        );
      }
      return const [];
    }
  }

  /// Same as [getVerifiedTrailers] but keyed by the exact TMDb id.
  Future<List<Trailer>> getVerifiedTrailersById(int movieId) async {
    if (movieId <= 0) return const [];
    final cached = _verifiedCache[movieId];
    if (cached != null) return cached;
    try {
      final movie = await _api.getMovieDetails(movieId);
      return getVerifiedTrailers(movie);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TRAILER] Could not resolve verified trailers for $movieId: $e');
      }
      return const [];
    }
  }

  /// The language codes that have a verified trailer for [movie] — ONLY the
  /// languages that actually exist. Never fabricates a language.
  Future<List<String>> getAvailableTrailerLanguages(Movie movie) async {
    final verified = await getVerifiedTrailers(movie);
    return _languageCodes(verified);
  }

  /// The available languages for a movie by its TMDb id.
  Future<List<String>> getAvailableTrailerLanguagesById(int movieId) async {
    final verified = await getVerifiedTrailersById(movieId);
    return _languageCodes(verified);
  }

  List<String> _languageCodes(List<Trailer> verified) {
    final codes = <String>{};
    for (final t in verified) {
      if (t.lang.trim().isEmpty) continue;
      codes.add(t.lang.toLowerCase());
    }
    return codes.toList();
  }

  /// Resolves the best verified trailer for [movieId], honoring [languageCode]
  /// (when provided and available) and otherwise applying the documented
  /// fallback priority: app language -> Hindi -> original language -> English
  /// -> any verified official trailer. Never returns a trailer for a different
  /// movie; `null` means no verified trailer exists (UI shows "Trailer
  /// unavailable").
  Future<Trailer?> resolveTrailer(
    int movieId, {
    String? languageCode,
  }) async {
    final verified = await getVerifiedTrailersById(movieId);
    if (verified.isEmpty) return null;
    final movie = await _movieOrNull(movieId);
    final selected = selectForLanguages(
      verified,
      requested: languageCode,
      movie: movie,
    );
    return selected?.copyWith(verified: true, source: 'TMDB');
  }

  Future<Movie?> _movieOrNull(int movieId) async {
    try {
      return await _api.getMovieDetails(movieId);
    } catch (_) {
      return null;
    }
  }

  /// Pure, deterministic language-aware selection from a verified candidate set.
  ///
  /// Priority (only when that language's trailer actually exists):
  ///   1. requested language
  ///   2. movie's original language
  ///   3. English
  ///   4. Hindi
  ///   5. any other verified trailer
  ///
  /// Exposed publicly so the UI can resolve the exact same trailer the service
  /// would play — the selector and the player can never disagree.
  static Trailer? selectForLanguages(
    List<Trailer> verified, {
    String? requested,
    Movie? movie,
  }) {
    if (verified.isEmpty) return null;
    final original = movie?.originalLanguage.trim().toLowerCase() ?? '';

    Trailer? pick(String code) {
      final candidates = verified
          .where((t) => t.lang.trim().toLowerCase() == code)
          .toList();
      return candidates.isEmpty ? null : _bestOf(candidates);
    }

    if (requested != null && requested.trim().isNotEmpty) {
      final sel = pick(requested.trim().toLowerCase());
      if (sel != null) return sel;
    }
    if (original.isNotEmpty) {
      final sel = pick(original);
      if (sel != null) return sel;
    }
    final en = pick('en');
    if (en != null) return en;
    final hi = pick('hi');
    if (hi != null) return hi;
    return _bestOf(verified);
  }

  static Trailer _bestOf(List<Trailer> candidates) {
    final sorted = [...candidates]..sort((a, b) {
      final byPriority = _priorityOf(a).compareTo(_priorityOf(b));
      if (byPriority != 0) return byPriority;
      if (a.official != b.official) return a.official ? -1 : 1;
      return 0;
    });
    return sorted.first;
  }

  static int _priorityOf(Trailer v) {
    if (v.isTrailer && v.isOfficial) return 0;
    if (v.isTrailer) return 1;
    if (v.isTeaser && v.isOfficial) return 2;
    if (v.isTeaser) return 3;
    return 4;
  }
  /// Pure and deterministic so it can be unit-tested with NO network access.
  /// Order is: verify each candidate, then rank by the documented priority.
  @visibleForTesting
  Trailer? selectBestTrailer(Movie movie, List<Trailer> videos) {
    final valid = <Trailer>[];
    for (final v in videos) {
      if (isValidTrailerForMovie(movie, v)) {
        valid.add(v);
      }
    }

    if (valid.isEmpty) {
      _logRejected('', 'No valid trailer candidates for "${movie.title}"');
      return null;
    }

    valid.sort((a, b) {
      final byPriority = _priority(a).compareTo(_priority(b));
      if (byPriority != 0) return byPriority;
      // Tie-break: prefer a name that contains "Official Trailer", then the
      // official flag, then English.
      final aOfficialName = a.name.toLowerCase().contains('official trailer');
      final bOfficialName = b.name.toLowerCase().contains('official trailer');
      if (aOfficialName != bOfficialName) {
        return aOfficialName ? -1 : 1;
      }
      if (a.official != b.official) return a.official ? -1 : 1;
      if (a.isEnglish != b.isEnglish) return a.isEnglish ? -1 : 1;
      return 0;
    });

    final selected = valid.first;
    // A trailer is only ever "verified" once it has passed the strict,
    // movie-scoped validation above (this exact TMDb movie id + all guards).
    return selected.copyWith(verified: true, source: 'TMDB');
  }

  /// Validates that [video] is a legitimate trailer candidate for [movie].
  ///
  /// The video was already fetched from `/movie/{movie.id}/videos`, so the
  /// TMDb id is the primary source of truth. This function additionally guards
  /// against videos that clearly belong to a DIFFERENT movie.
  bool isValidTrailerForMovie(Movie movie, Trailer video) {
    if (video.site.toLowerCase() != 'youtube') {
      _logRejected(video.name, 'Site is "${video.site}", not YouTube');
      return false;
    }
    if (video.key.trim().isEmpty) {
      _logRejected(video.name, 'Empty YouTube key');
      return false;
    }

    final candName = video.name.toLowerCase().trim();
    final movieTitle = movie.title.toLowerCase().trim();
    final type = video.type.toLowerCase().trim();

    // Excluded video types are never used as a trailer.
    if (_excludedTypes.contains(type)) {
      _logRejected(video.name, 'Excluded video type "$type"');
      return false;
    }

    // Fan-made / concept / reaction / compilation video indicators.
    for (final indicator in _fanMadeIndicators) {
      if (candName.contains(indicator)) {
        _logRejected(
          video.name,
          'Fan-made / non-official indicator "$indicator"',
        );
        return false;
      }
    }

    // Cross-movie conflict guard: if the candidate names a known franchise
    // subtitle that contradicts the movie's own subtitle, reject it.
    // E.g. a "No Way Home" trailer belongs to a different movie than
    // "Homecoming". We only reject if there is a CLEAR conflict.
    for (final sub in _knownFranchiseSubtitles) {
      if (candName.contains(sub)) {
        // If the trailer has a subtitle, check if the movie title has a
        // DIFFERENT subtitle from our known list.
        for (final otherSub in _knownFranchiseSubtitles) {
          if (sub != otherSub && movieTitle.contains(otherSub)) {
            _logRejected(
              video.name,
              'Subtitle conflict: trailer has "$sub", movie has "$otherSub"',
            );
            return false;
          }
        }
      }
    }

    return true;
  }

  /// Priority ranking per the documented trailer-selection rules.
  /// Priority:
  /// 1. Official YouTube Trailer (English)
  /// 2. Official YouTube Trailer (Any)
  /// 3. YouTube Trailer (English)
  /// 4. YouTube Trailer (Any)
  /// 5. Official YouTube Teaser (English)
  /// 6. Official YouTube Teaser (Any)
  /// 7. YouTube Teaser
  /// 8. Other valid YouTube promotional video
  int _priority(Trailer v) {
    final isTrailer = v.isTrailer;
    final isTeaser = v.isTeaser;
    final official = v.official;
    final en = v.isEnglish;

    if (official && isTrailer && en) return 0;
    if (official && isTrailer) return 1;
    if (isTrailer && en) return 2;
    if (isTrailer) return 3;
    if (official && isTeaser && en) return 4;
    if (official && isTeaser) return 5;
    if (isTeaser) return 6;
    return 7;
  }
  void _logUnavailable(Movie movie, String reason) {
    if (kDebugMode) {
      debugPrint(
        '[TRAILER] Trailer unavailable for "${movie.title}" '
        '(id ${movie.id}): $reason',
      );
    }
  }

  void _logRejected(String name, String reason) {
    if (kDebugMode) {
      debugPrint('[TRAILER] Rejected video: "$name"');
      debugPrint('[TRAILER] Reason: $reason');
    }
  }

  void _logSelected(Movie movie, Trailer? selected) {
    if (!kDebugMode) return;
    if (selected == null) {
      debugPrint(
        '[TRAILER] No trailer available for "${movie.title}" (id ${movie.id}).',
      );
      return;
    }
    debugPrint('[TRAILER] Movie: ${movie.title}');
    debugPrint('[TRAILER] TMDB ID: ${movie.id}');
    debugPrint('[TRAILER] Selected trailer: ${selected.name}');
    debugPrint('[TRAILER] YouTube ID: ${selected.key}');
    debugPrint('[TRAILER] Official: ${selected.official}');
    debugPrint('[TRAILER] Type: ${selected.type}');
    debugPrint('[TRAILER] Site: ${selected.site}');
  }
}
