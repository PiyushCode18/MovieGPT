import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/movie_model.dart';
import '../models/discover_filters.dart';
import '../models/paginated_movies.dart';
import '../config/env_config.dart';
import 'api_client.dart';

/// Thrown when the TMDB API key is not configured.
class TmdbApiNotConfiguredException implements Exception {
  final String message;
  TmdbApiNotConfiguredException(this.message);
  @override
  String toString() => message;
}

/// Classifies a TMDB request failure so the UI can show a specific message.
class TmdbApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;
  final bool isTimeout;

  const TmdbApiException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
    this.isTimeout = false,
  });

  @override
  String toString() => message;
}

/// Service providing raw data access to TMDB endpoints.
class TmdbApiService {
  TmdbApiService._();

  static final TmdbApiService instance = TmdbApiService._();

  Dio get _dio => ApiClient.instance.dio;

  bool get isConfigured => EnvConfig.hasApiKey;

  /// Maximum automatic retries for transient failures.
  static const int _maxRetries = 2;

  Future<Response> _get(
    String path, {
    Map<String, dynamic>? query,
    int attempt = 0,
  }) async {
    if (!isConfigured) {
      throw const TmdbApiException(
        'TMDB API key not configured. Add TMDB_API_KEY to your .env file.',
      );
    }
    try {
      final response = await _dio.get(path, queryParameters: query);
      return response;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final isTransient = _isTransientFailure(e, status);

      if (isTransient && attempt < _maxRetries) {
        if (kDebugMode) {
          debugPrint(
            'TMDB GET $path failed (attempt ${attempt + 1}), retrying...',
          );
        }
        // Small backoff before retrying a transient failure.
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        return _get(path, query: query, attempt: attempt + 1);
      }

      String message;
      bool isNetwork = false;
      bool isTimeout = false;

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          isTimeout = true;
          message = 'Request timed out. Please check your connection.';
          break;
        case DioExceptionType.connectionError:
        case DioExceptionType.unknown:
          isNetwork = true;
          message = 'Network error. Please check your internet connection.';
          break;
        default:
          message =
              e.response?.data?['status_message'] ??
              e.message ??
              'TMDB request failed';
      }

      if (status == 401) {
        message = 'Invalid TMDB API key. Check your configuration.';
      } else if (status == 403) {
        message = 'Access denied by TMDB. Check your API access level.';
      } else if (status == 404) {
        message = 'Movie not found on TMDB.';
      } else if (status == 429) {
        message = 'TMDB rate limit reached. Please try again shortly.';
      } else if (status == 500) {
        message = 'TMDB server error. Please try again later.';
      } else if (status != null && status >= 500) {
        message = 'TMDB server error ($status). Please try again later.';
      }

      if (kDebugMode) {
        // Log the endpoint + status + error type for diagnostics WITHOUT
        // printing the API key (it is sent as a query param, not included here).
        final statusMessage = e.response?.data?['status_message'];
        debugPrint(
          '[MovieGPT] TMDB GET $path failed\n'
          '  status: ${status ?? 'n/a'}\n'
          '  dioType: ${e.type.name}\n'
          '  isNetwork: $isNetwork\n'
          '  isTimeout: $isTimeout\n'
          '  statusMessage: ${statusMessage ?? 'n/a'}\n'
          '  userMessage: $message',
        );
      }
      throw TmdbApiException(
        message,
        statusCode: status,
        isNetworkError: isNetwork,
        isTimeout: isTimeout,
      );
    }
  }

  /// Whether a failure is transient and worth retrying (timeout, connection,
  /// TLS handshake reset, or HTTP 429/503). Permanent failures (401/403/404)
  /// are NOT retried.
  bool _isTransientFailure(DioException e, int? status) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    // Transport-level failures with no HTTP response (dio wraps TLS
    // handshake resets as DioExceptionType.unknown) are transient.
    if (e.type == DioExceptionType.unknown &&
        e.response == null &&
        e.error != null) {
      return true;
    }
    return status == 429 || status == 503 || status == 408;
  }

  Future<List<Movie>> getNowPlaying({int page = 1}) async {
    final res = await _get(
      '/movie/now_playing',
      query: {'page': page, 'language': 'en-US'},
    );
    return (res.data['results'] as List)
        .map((e) => Movie.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Movie>> getPopular({int page = 1}) async {
    final res = await _get(
      '/movie/popular',
      query: {'page': page, 'language': 'en-US'},
    );
    return (res.data['results'] as List)
        .map((e) => Movie.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Movie>> getTopRated({int page = 1}) async {
    final res = await _get(
      '/movie/top_rated',
      query: {'page': page, 'language': 'en-US'},
    );
    return (res.data['results'] as List)
        .map((e) => Movie.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Movie>> getUpcoming({int page = 1}) async {
    final res = await _get(
      '/movie/upcoming',
      query: {'page': page, 'language': 'en-US'},
    );
    return (res.data['results'] as List)
        .map((e) => Movie.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Movie>> getTrending({
    String timeWindow = 'day',
    int page = 1,
  }) async {
    final res = await _get(
      '/trending/movie/$timeWindow',
      query: {'page': page, 'language': 'en-US'},
    );
    return (res.data['results'] as List)
        .map((e) => Movie.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Pageable variant of [getTrending].
  Future<PaginatedMovies> getTrendingPaged({
    String timeWindow = 'day',
    int page = 1,
  }) async {
    final res = await _get(
      '/trending/movie/$timeWindow',
      query: {'page': page, 'language': 'en-US'},
    );
    return _parsePaginated(res.data);
  }

  /// Pageable variant of [getPopular].
  Future<PaginatedMovies> getPopularPaged({int page = 1}) async {
    final res = await _get(
      '/movie/popular',
      query: {'page': page, 'language': 'en-US'},
    );
    return _parsePaginated(res.data);
  }

  /// Pageable variant of [getTopRated].
  Future<PaginatedMovies> getTopRatedPaged({int page = 1}) async {
    final res = await _get(
      '/movie/top_rated',
      query: {'page': page, 'language': 'en-US'},
    );
    return _parsePaginated(res.data);
  }

  /// Pageable variant of [getNowPlaying].
  Future<PaginatedMovies> getNowPlayingPaged({int page = 1}) async {
    final res = await _get(
      '/movie/now_playing',
      query: {'page': page, 'language': 'en-US'},
    );
    return _parsePaginated(res.data);
  }

  Future<List<Movie>> getByGenre(int genreId, {int page = 1}) async {
    final res = await _get(
      '/discover/movie',
      query: {
        'with_genres': genreId,
        'page': page,
        'language': 'en-US',
        'sort_by': 'popularity.desc',
      },
    );
    return (res.data['results'] as List)
        .map((e) => Movie.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Discovers movies matching the structured [DiscoverFilters].
  ///
  /// Every filter maps to a REAL TMDb discover parameter — MovieGPT never
  /// synthesizes filters that TMDb does not support, so the results are always
  /// real movies from the configured data source.
  Future<List<Movie>> discoverMovies(
    DiscoverFilters filters, {
    int page = 1,
  }) async {
    final res = await _get(
      '/discover/movie',
      query: {
        ...filters.toQueryParams(),
        'page': page,
        'language': 'en-US',
        'include_adult': false,
      },
    );
    return (res.data['results'] as List)
        .map((e) => Movie.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Discovers movies originally produced in [countryCode] (ISO 3166-1).
  ///
  /// Used by the "World Cinema" screen to surface real cinema from a region.
  /// Optionally restricts to a primary original language (e.g. `ko` for Korea).
  Future<List<Movie>> getByCountry(
    String countryCode, {
    String? originalLanguage,
    int page = 1,
  }) async {
    final res = await _get(
      '/discover/movie',
      query: {
        'with_origin_country': countryCode,
        // ignore: use_null_aware_elements
        if (originalLanguage != null) 'with_original_language': originalLanguage,
        'page': page,
        'language': 'en-US',
        'sort_by': 'popularity.desc',
      },
    );
    return (res.data['results'] as List)
        .map((e) => Movie.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Fetch upcoming blockbusters from the TMDB Upcoming endpoint.
  /// Only movies with both an official poster and backdrop are returned.
  Future<List<Movie>> getUpcomingBlockbusters({int page = 1}) async {
    final upcoming = await getUpcoming(page: page);
    return upcoming
        .where((m) => m.posterPath != null && m.backdropPath != null)
        .toList();
  }

  /// Fetch a movie's full details plus cast, trailers, and similar movies in a
  /// SINGLE request via TMDB's `append_to_response` — eliminating 3 redundant
  /// network calls on the details screen.
  Future<MovieDetailsBundle> getMovieDetailsBundle(int movieId) async {
    final res = await _get(
      '/movie/$movieId',
      query: {
        'language': 'en-US',
        'append_to_response': 'credits,videos,similar,recommendations',
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final movie = Movie.fromJson(data);

    // Parse cast from the bundled `credits` payload (null-safe).
    final credits = _asMap(data['credits']);
    final cast = _asList(
      credits['cast'],
    ).take(12).map((e) => CastMember.fromJson(_asMap(e))).toList();

    // Parse trailers/teasers from the bundled `videos` payload (null-safe).
    // We keep BOTH official trailers AND teasers so the UI can fall back to a
    // teaser when a full trailer does not exist. TMDB response order is
    // preserved so the most relevant official video is selected first.
    final videos = _asMap(data['videos']);
    final trailers = _asList(videos['results'])
        .map((e) => Trailer.fromJson(_asMap(e)))
        .where((t) => t.site.toLowerCase() == 'youtube')
        .toList();

    // `similar` is the official TMDB "Similar Movies" feed; fold in
    // `recommendations` only when `similar` is empty to guarantee a populated
    // row with real TMDB data.
    final similar = _moviesFromResults(data['similar']).take(20).toList();
    final recommendations = similar.isNotEmpty
        ? similar
        : _moviesFromResults(data['recommendations']).take(20).toList();

    return MovieDetailsBundle(
      movie: movie.copyWith(cast: cast, overview: movie.overview),
      cast: cast,
      trailers: trailers,
      similar: recommendations,
    );
  }

  /// Safely coerce a decoded value into a `Map<String, dynamic>` map.
  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  /// Safely coerce a decoded value into a `List` (empty when not a list).
  static List<dynamic> _asList(Object? value) {
    return value is List ? value : const [];
  }

  /// Convenience wrapper for callers that only need the core movie object.
  Future<Movie> getMovieDetails(int movieId) async {
    final bundle = await getMovieDetailsBundle(movieId);
    return bundle.movie;
  }

  Future<List<CastMember>> getCast(int movieId) async {
    final bundle = await getMovieDetailsBundle(movieId);
    return bundle.cast;
  }

  Future<List<Trailer>> getTrailers(int movieId) async {
    final bundle = await getMovieDetailsBundle(movieId);
    return bundle.trailers;
  }

  Future<List<Movie>> getSimilar(int movieId, {int page = 1}) async {
    final bundle = await getMovieDetailsBundle(movieId);
    return bundle.similar;
  }

  /// Fetches every video that TMDb has associated with the EXACT [movieId].
  ///
  /// This is the single source of truth for trailer selection. The results are
  /// always scoped to this one movie id — never a YouTube search and never a
  /// different movie's data.
  ///
  /// NOTE: We deliberately do NOT pass a `language` filter here. TMDb returns
  /// all available videos for the movie, and the [TrailerService] prioritizes
  /// English while still accepting other-language official trailers when that
  /// is all that exists.
  Future<List<Trailer>> getMovieVideos(int movieId) async {
    final res = await _get('/movie/$movieId/videos');
    return _asList(res.data['results'])
        .map((e) => Trailer.fromJson(_asMap(e)))
        .toList();
  }

  /// Helper to parse a TMDB `results` list into [Movie]s (null-safe).
  List<Movie> _moviesFromResults(Object? results) {
    return _asList(results).map((e) => Movie.fromJson(_asMap(e))).toList();
  }

  /// Parses a pageable TMDB response into [PaginatedMovies] (null-safe).
  ///
  /// Missing pagination metadata never throws — it degrades to a single,
  /// non-paginated page so an unexpected payload still renders instead of
  /// crashing the UI.
  PaginatedMovies _parsePaginated(Object? data) {
    final map = _asMap(data);
    final page = (map['page'] as num?)?.toInt() ?? 1;
    final total = (map['total_pages'] as num?)?.toInt() ?? page;
    final results = _asList(map['results']);
    final movies = _moviesFromResults(results);
    return PaginatedMovies(
      movies: movies,
      page: page,
      totalPages: total < page ? page : total,
    );
  }

  /// Movies released during the given [year] via `/discover/movie`.
  ///
  /// [year] is generated at runtime (e.g. `DateTime.now().year`) so the
  /// feature automatically follows the current calendar year (2026 → 2027 →
  /// 2028 ...) instead of being hardcoded. Uses the release-date range:
  ///   `primary_release_date.gte = {year}-01-01`
  ///   `primary_release_date.lte = {year}-12-31`
  Future<PaginatedMovies> getCurrentYearMovies(
    int year, {
    int page = 1,
    String? region,
  }) async {
    final start = '$year-01-01';
    final end = '$year-12-31';
    final res = await _get(
      '/discover/movie',
      query: {
        'sort_by': 'popularity.desc',
        'primary_release_date.gte': start,
        'primary_release_date.lte': end,
        'with_release_type': '2|3',
        'page': page,
        'language': 'en-US',
        'include_adult': false,
        if (region != null && region.isNotEmpty) 'region': region,
      },
    );
    return _parsePaginated(res.data);
  }

  /// Upcoming movies (release date within [gte]..[lte]) via `/discover/movie`.
  ///
  /// Unlike the short-window `/movie/upcoming` endpoint, this returns movies
  /// across the full requested range (default: today → ~15 months out).
  /// Sorted by ascending release date so the soonest premieres appear first,
  /// then falls through to popularity from TMDB's tie-break.
  Future<PaginatedMovies> getUpcomingRange({
    required String gte,
    required String lte,
    int page = 1,
    String region = 'IN',
  }) async {
    final res = await _get(
      '/discover/movie',
      query: {
        'sort_by': 'primary_release_date.asc',
        'primary_release_date.gte': gte,
        'primary_release_date.lte': lte,
        'with_release_type': '2|3',
        'with_original_language': '', // do not restrict to a single language
        'page': page,
        'language': 'en-US',
        'include_adult': false,
        'region': region,
      },
    );
    return _parsePaginated(res.data);
  }

  Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return const [];
    final res = await _get(
      '/search/movie',
      query: {
        'query': query,
        'page': page,
        'language': 'en-US',
        'include_adult': false,
      },
    );
    return (res.data['results'] as List)
        .map((e) => Movie.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Pageable search (used for the search screen's infinite scroll).
  ///
  /// Search is never restricted to a release year — any query (e.g. `Avatar`,
  /// `Spider-Man`, `2026 movie`) queries the full TMDB catalog.
  Future<PaginatedMovies> searchMoviesPaged(
    String query, {
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return const PaginatedMovies();
    final res = await _get(
      '/search/movie',
      query: {
        'query': query,
        'page': page,
        'language': 'en-US',
        'include_adult': false,
      },
    );
    return _parsePaginated(res.data);
  }

  Future<List<Genre>> getGenres() async {
    final res = await _get('/genre/movie/list', query: {'language': 'en-US'});
    return (res.data['genres'] as List)
        .map((e) => Genre.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Searches TMDB for a person (actor, director, writer) by name.
  ///
  /// Returns the top matching person data map or `null` if no person found.
  Future<Map<String, dynamic>?> searchPerson(String query) async {
    if (query.trim().isEmpty) return null;
    final res = await _get(
      '/search/person',
      query: {
        'query': query,
        'page': 1,
        'language': 'en-US',
        'include_adult': false,
      },
    );
    final results = _asList(res.data['results']);
    if (results.isEmpty) return null;
    return _asMap(results.first);
  }

  /// Fetches movie credits for a specific person ID.
  ///
  /// If [asDirector] is true, filters crew entries for Director role; otherwise
  /// returns acting cast entries. Duplicate movie IDs are removed and results
  /// are returned as a deduplicated list of [Movie]s.
  Future<List<Movie>> getPersonMovieCredits(
    int personId, {
    bool asDirector = false,
  }) async {
    final res = await _get(
      '/person/$personId/movie_credits',
      query: {'language': 'en-US'},
    );
    final data = _asMap(res.data);
    final rawList = asDirector
        ? _asList(data['crew']).where((e) {
            final map = _asMap(e);
            final job = (map['job'] as String?)?.toLowerCase() ?? '';
            return job == 'director';
          }).toList()
        : _asList(data['cast']);

    final seen = <int>{};
    final movies = <Movie>[];

    for (final item in rawList) {
      final map = _asMap(item);
      final movie = Movie.fromJson(map);
      if (movie.id > 0 && seen.add(movie.id)) {
        movies.add(movie);
      }
    }

    return movies;
  }
}


