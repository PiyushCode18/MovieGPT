import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/movie_model.dart';
import '../models/discover_filters.dart';
import '../models/paginated_movies.dart';
import '../services/tmdb_api_service.dart';
import '../services/trailer_service.dart';

/// In-memory cache entry with a timestamp for TTL-based freshness.
class _CacheEntry {
  final List<Movie> movies;
  final DateTime fetchedAt;
  _CacheEntry(this.movies, this.fetchedAt);
}

/// TTL-based cache entry for a single page of a paginated response.
class _PagedCacheEntry {
  final PaginatedMovies page;
  final DateTime fetchedAt;
  _PagedCacheEntry(this.page, this.fetchedAt);
}

/// Repository that provides movie data with offline-first caching.
///
/// Caching & performance strategy:
///  - **In-memory TTL cache**: fast path for list endpoints. Entries are
///    considered fresh for [_ttl]; after that they're re-fetched from the
///    network but the stale cache is still used as an offline/error fallback.
///  - **In-flight request deduplication**: concurrent calls for the same key
///    share a single network Future, so the UI never fires duplicate requests
///    (e.g. Home screen watching multiple providers at once).
///  - **Disk cache**: persisted to SharedPreferences so previously-loaded
///    lists survive app restarts and are available offline.
///
/// On a network failure, the repository falls back to the cached copy (memory
/// first, then disk) so the UI is never blank. When no cache exists, the error
/// is rethrown so the UI can show a retry screen.
class MovieRepository {
  MovieRepository._();

  static final MovieRepository instance = MovieRepository._();
  final TmdbApiService _api = TmdbApiService.instance;

  /// How long in-memory list data is considered fresh before re-fetching.
  static const Duration _ttl = Duration(minutes: 5);

  bool get _isLive => TmdbApiService.instance.isConfigured;

  /// In-memory bundle cache for movie details (avoids repeat network calls).
  final Map<int, MovieDetailsBundle> _bundleCache = {};

  /// TTL-based in-memory cache for list endpoints (fast path).
  final Map<String, _CacheEntry> _listCache = {};

  /// In-flight request dedup for list fetches (key -> shared Future).
  final Map<String, Future<List<Movie>>> _inFlight = {};

  /// In-flight request dedup for movie details bundles (id -> shared Future).
  final Map<int, Future<MovieDetailsBundle>> _bundleInFlight = {};

  /// Paginated-response in-memory cache with TTL (fast path for page fetches).
  final Map<String, _PagedCacheEntry> _pagedListCache = {};

  /// In-flight request dedup for paginated responses (key -> shared Future).
  final Map<String, Future<PaginatedMovies>> _pagedInFlight = {};

  /// SharedPreferences-backed disk cache (offline persistence).
  static const String _cachePrefix = 'moviegpt_list_cache_';

  /// Reads a previously-cached list, or returns an empty list.
  List<Movie> _cachedOrEmpty(String key) {
    final entry = _listCache[key];
    return entry == null ? const [] : entry.movies;
  }

  /// Whether a cached entry is still fresh (within [_ttl]).
  bool _isFresh(String key) {
    final entry = _listCache[key];
    return entry != null && DateTime.now().difference(entry.fetchedAt) < _ttl;
  }

  /// Persists a list to disk (best-effort, never throws).
  Future<void> _persistToDisk(String key, List<Movie> movies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(movies.map((m) => m.toStorageJson()).toList());
      await prefs.setString('$_cachePrefix$key', raw);
    } catch (_) {
      // Disk persistence is best-effort; ignore failures.
    }
  }

  /// Loads a previously-saved disk cache into memory. No-op if absent.
  Future<void> _loadFromDisk(String key) async {
    if (_listCache.containsKey(key)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$key');
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map(
            (e) => Movie.fromStorageJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      if (list.isNotEmpty) {
        _listCache[key] = _CacheEntry(list, DateTime.now());
      }
    } catch (_) {
      // Ignore corrupt/unreadable cache.
    }
  }

  /// Wraps a list fetch with TTL + in-flight dedup + offline fallback.
  ///
  /// - If a fresh in-memory entry exists, return it immediately (no network).
  /// - If a request for the same [key] is already in flight, share its Future.
  /// - Otherwise fetch from the network; on success cache (memory + disk).
  /// - On failure, fall back to the stale/disk cache (never blank). If no
  ///   cache exists, rethrow so the UI can show a retry screen.
  Future<List<Movie>> _withFallback(
    String key,
    Future<List<Movie>> Function() fetch,
  ) async {
    // Fresh cache: return immediately, no network.
    if (_isFresh(key)) {
      return _cachedOrEmpty(key);
    }

    // If a request is already in flight for this key, share it.
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _fetch(key, fetch);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      // Clean up the in-flight entry so future calls re-fetch after it ends.
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    }
  }

  /// Performs the actual fetch (with stale-cache fallback on failure).
  Future<List<Movie>> _fetch(
    String key,
    Future<List<Movie>> Function() fetch,
  ) async {
    try {
      final data = await fetch();
      _listCache[key] = _CacheEntry(data, DateTime.now());
      // Persist to disk in the background (does not block the response).
      unawaited(_persistToDisk(key, data));
      return data;
    } catch (_) {
      // Try memory cache first, then disk.
      final cached = _cachedOrEmpty(key);
      if (cached.isNotEmpty) return cached;
      await _loadFromDisk(key);
      final diskCached = _cachedOrEmpty(key);
      if (diskCached.isNotEmpty) return diskCached;
      rethrow;
    }
  }

  /// Paginated fetch with TTL + in-flight dedup.
  ///
  /// The [key] MUST encode the full query identity (dates + page) so different
  /// ranges/pages never collide and stale rows can't leak across queries.
  Future<PaginatedMovies> _withPagedFallback(
    String key,
    Future<PaginatedMovies> Function() fetch,
  ) async {
    final cached = _pagedListCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _ttl) {
      return cached.page;
    }

    final existing = _pagedInFlight[key];
    if (existing != null) return existing;

    final future = _fetchPaged(key, fetch);
    _pagedInFlight[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_pagedInFlight[key], future)) {
        _pagedInFlight.remove(key);
      }
    }
  }

  /// Network fetch for a single page, caching it on success.
  Future<PaginatedMovies> _fetchPaged(
    String key,
    Future<PaginatedMovies> Function() fetch,
  ) async {
    final page = await fetch();
    _pagedListCache[key] = _PagedCacheEntry(page, DateTime.now());
    return page;
  }

  Future<Movie> getFeatured() async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    try {
      return await _api.getMovieDetails(969681);
    } catch (_) {
      final trending = await _api.getTrending(timeWindow: 'day');
      if (trending.isNotEmpty) return trending.first;
      throw Exception('Unable to fetch featured movie');
    }
  }

  Future<List<Movie>> getTrending() async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withFallback('trending', () => _api.getTrending(timeWindow: 'day'));
  }

  Future<List<Movie>> getRecommended() async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withFallback('recommended', () async {
      final results = await Future.wait([
        _api.getTopRated(page: 1),
        _api.getPopular(page: 1),
      ]);
      final seen = <int>{};
      final combined = <Movie>[...results[0], ...results[1]];
      return combined.where((m) => seen.add(m.id)).take(20).toList();
    });
  }

  Future<List<Movie>> getForYou() async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withFallback('forYou', () async {
      final upcoming = await _api.getUpcomingBlockbusters();
      if (upcoming.isNotEmpty) return upcoming;
      final trending = await _api.getTrending(timeWindow: 'week');
      if (trending.isNotEmpty) return trending.take(6).toList();
      throw Exception('Unable to fetch recommendations');
    });
  }

  Future<List<Movie>> getNowPlaying() async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withFallback('nowPlaying', () => _api.getNowPlaying());
  }

  Future<List<Movie>> getPopular({int page = 1}) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withFallback(
      'popular-page-$page',
      () => _api.getPopular(page: page),
    );
  }

  Future<List<Movie>> getTopRated({int page = 1}) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withFallback(
      'topRated-page-$page',
      () => _api.getTopRated(page: page),
    );
  }

  Future<List<Movie>> getUpcoming() async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withFallback('upcoming', () => _api.getUpcoming());
  }

  Future<List<Movie>> getByGenre(int genreId, {int page = 1}) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withFallback(
      'genre-$genreId-page-$page',
      () => _api.getByGenre(genreId, page: page),
    );
  }

  /// Discovers movies matching the structured [DiscoverFilters] (cached).
  ///
  /// The cache key is derived from the filters so repeated identical queries
  /// (e.g. AI "why" refreshes) are served from memory/disk.
  Future<List<Movie>> discoverMovies(DiscoverFilters filters, {int page = 1}) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withFallback(
      'discover-${_filtersKey(filters)}-page-$page',
      () => _api.discoverMovies(filters, page: page),
    );
  }

  /// Movies originally produced in [countryCode] (cached).
  Future<List<Movie>> getByCountry(
    String countryCode, {
    String? originalLanguage,
    int page = 1,
  }) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withFallback(
      'country-$countryCode-${originalLanguage ?? 'all'}-page-$page',
      () => _api.getByCountry(countryCode,
          originalLanguage: originalLanguage, page: page),
    );
  }

  /// A stable string key from the discover filters for caching.
  String _filtersKey(DiscoverFilters f) {
    return [
      'g${f.genreId ?? 0}',
      'l${f.withOriginalLanguage ?? ''}',
      'r${f.withRegion ?? ''}',
      'v${f.minRating?.toString() ?? ''}',
      'x${f.runtimeMax ?? 0}',
      'n${f.runtimeMin ?? 0}',
      'd${f.releaseDateGte ?? ''}${f.releaseDateLte ?? ''}',
      f.sortBy,
    ].join('-');
  }

  Future<Movie> getMovieDetails(int movieId) async {
    final bundle = await getMovieDetailsBundle(movieId);
    return bundle.movie;
  }

  Future<MovieDetailsBundle> getMovieDetailsBundle(int movieId) async {
    if (_bundleCache.containsKey(movieId)) {
      return _bundleCache[movieId]!;
    }
    if (!_isLive) throw Exception('TMDB API key not configured');

    // Dedup concurrent bundle requests for the same movie.
    final existing = _bundleInFlight[movieId];
    if (existing != null) return existing;

    final future = _api.getMovieDetailsBundle(movieId).then((bundle) {
      _bundleCache[movieId] = bundle;
      return bundle;
    });
    _bundleInFlight[movieId] = future;
    try {
      return await future;
    } finally {
      if (identical(_bundleInFlight[movieId], future)) {
        _bundleInFlight.remove(movieId);
      }
    }
  }

  Future<List<CastMember>> getCast(int movieId) async {
    final bundle = await getMovieDetailsBundle(movieId);
    return bundle.cast;
  }

  Future<List<Trailer>> getTrailers(int movieId) async {
    final bundle = await getMovieDetailsBundle(movieId);
    return bundle.trailers;
  }

  /// Resolves the verified official trailer for [movieId].
  ///
  /// Single source of truth: delegates to the strict [TrailerService] engine
  /// so movie-scoped validation is identical everywhere in the app. Returns
  /// `null` when no correct trailer can be verified (the UI then shows
  /// "Trailer unavailable" instead of a wrong or guessed video).
  Future<Trailer?> getPrimaryTrailer(int movieId) async {
    return TrailerService.instance.getOfficialTrailerById(movieId);
  }

  Future<List<Movie>> getSimilar(int movieId, {int page = 1}) async {
    final bundle = await getMovieDetailsBundle(movieId);
    return bundle.similar;
  }

  Future<List<Movie>> searchMovies(
    String query, {
    CancelToken? cancelToken,
  }) async {
    if (query.trim().isEmpty) return const [];
    if (!_isLive) throw Exception('TMDB API key not configured');

    final key = 'search-${query.trim().toLowerCase()}';
    return _withFallback(
      key,
      () => _api.searchMovies(query, cancelToken: cancelToken),
    );
  }

  /// Movies released in the current (runtime-generated) [year].
  ///
  /// The year is derived at call time so this keeps working for 2027, 2028,
  /// etc. Returns a paginated object so the UI can load more pages.
  Future<PaginatedMovies> getCurrentYearMovies(
    int year, {
    int page = 1,
  }) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withPagedFallback(
      'year-$year-page-$page',
      () => _api.getCurrentYearMovies(year, page: page, region: 'IN'),
    );
  }

  /// Upcoming movies with a release date in [start]..[end] (inclusive).
  ///
  /// Bounded by the 12–18 month window so the home/see-all never shows dated
  /// rows. The date range is baked into the cache key so it never serves
  /// stale upcoming data across different ranges.
  Future<PaginatedMovies> getUpcomingRange({
    required DateTime start,
    required DateTime end,
    int page = 1,
  }) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    final gte = _fmtDate(start);
    final lte = _fmtDate(end);
    return _withPagedFallback(
      'upcoming-$gte-$lte-page-$page',
      () => _api.getUpcomingRange(gte: gte, lte: lte, page: page),
    );
  }

  /// Pageable search results (for the search screen's infinite scroll).
  Future<PaginatedMovies> searchMoviesPaged(
    String query, {
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return const PaginatedMovies();
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _api.searchMoviesPaged(query, page: page);
  }

  /// Formats a [DateTime] as `YYYY-MM-DD` (no time component).
  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Pageable popular movies.
  Future<PaginatedMovies> getPopularPaged({int page = 1}) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withPagedFallback(
      'popular-page-$page',
      () => _api.getPopularPaged(page: page),
    );
  }

  /// Pageable top-rated movies.
  Future<PaginatedMovies> getTopRatedPaged({int page = 1}) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withPagedFallback(
      'topRated-page-$page',
      () => _api.getTopRatedPaged(page: page),
    );
  }

  /// Pageable trending movies.
  Future<PaginatedMovies> getTrendingPaged({int page = 1}) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withPagedFallback(
      'trending-day-page-$page',
      () => _api.getTrendingPaged(page: page),
    );
  }

  /// Paged now-playing movies.
  Future<PaginatedMovies> getNowPlayingPaged({int page = 1}) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _withPagedFallback(
      'nowPlaying-page-$page',
      () => _api.getNowPlayingPaged(page: page),
    );
  }

  Future<List<Genre>> getGenres() async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _api.getGenres();
  }

  /// Searches for a person (actor/director) by name (cached).
  Future<Map<String, dynamic>?> searchPerson(String query) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    return _api.searchPerson(query);
  }

  /// Fetches movie credits for a person ID (cached with fallback).
  Future<List<Movie>> getPersonMovieCredits(
    int personId, {
    bool asDirector = false,
  }) async {
    if (!_isLive) throw Exception('TMDB API key not configured');
    final key = 'person-$personId-dir-$asDirector';
    return _withFallback(
      key,
      () => _api.getPersonMovieCredits(personId, asDirector: asDirector),
    );
  }

  /// Clears the in-memory caches (does not clear the disk cache).
  void clearCache() {
    _bundleCache.clear();
    _bundleInFlight.clear();
    _listCache.clear();
    _inFlight.clear();
    _pagedListCache.clear();
    _pagedInFlight.clear();
  }
}



