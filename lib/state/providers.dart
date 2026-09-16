import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/ai_mode.dart';
import '../data/movie_repository.dart';
import '../models/movie_model.dart';
import '../models/paginated_movies.dart';
import '../services/trailer_service.dart';
import '../models/discover_filters.dart';


final movieRepositoryProvider = Provider<MovieRepository>((ref) {
  return MovieRepository.instance;
});

/// Provides the production trailer service that resolves official trailers
/// from REAL TMDb video data, keyed by the exact TMDb movie id.
final trailerServiceProvider = Provider<TrailerService>((ref) {
  return TrailerService.instance;
});

final featuredMovieProvider = FutureProvider<Movie>((ref) {
  return ref.watch(movieRepositoryProvider).getFeatured();
});

final trendingMoviesProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(movieRepositoryProvider).getTrending();
});

final recommendedMoviesProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(movieRepositoryProvider).getRecommended();
});

final forYouMoviesProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(movieRepositoryProvider).getForYou();
});

final nowPlayingProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(movieRepositoryProvider).getNowPlaying();
});

final popularMoviesProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(movieRepositoryProvider).getPopular();
});

final topRatedMoviesProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(movieRepositoryProvider).getTopRated();
});

final upcomingMoviesProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(movieRepositoryProvider).getUpcoming();
});

/// A convenience/provider for the home "See All -> This Year" row.
///
/// The year is resolved at runtime (`DateTime.now().year`) and the query uses
/// TMDB's `/discover/movie` with `primary_release_date` set to Jan 1 → Dec 31
/// of that year, so it automatically follows 2026 → 2027 → 2028 ...
final currentYearMoviesProvider = FutureProvider<List<Movie>>((ref) {
  final year = DateTime.now().year;
  return ref
      .watch(movieRepositoryProvider)
      .getCurrentYearMovies(year)
      .then((p) => p.movies);
});

/// Upcoming movies via Discover with a dynamic range: today → ~15 months.
///
/// Dates are recalculated at runtime, so this never goes stale or hardcodes a
/// fixed year. Sorted by release date ascending (soonest first).
final upcomingRangeMoviesProvider = FutureProvider<List<Movie>>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month + 15, now.day);
  return ref
      .watch(movieRepositoryProvider)
      .getUpcomingRange(start: start, end: end)
      .then((p) => p.movies);
});

/// State of an in-progress paginated list (used by [PaginatedMoviesNotifier]).
class PaginatedMoviesState {
  final List<Movie> movies;
  final int currentPage;
  final int totalPages;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final bool hasError;
  final String? errorMessage;

  const PaginatedMoviesState({
    this.movies = const [],
    this.currentPage = 0,
    this.totalPages = 0,
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.hasError = false,
    this.errorMessage,
  });

  bool get hasMore => currentPage < totalPages || totalPages == 0;

  PaginatedMoviesState copyWith({
    List<Movie>? movies,
    int? currentPage,
    int? totalPages,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    bool? hasError,
    String? errorMessage,
  }) {
    return PaginatedMoviesState(
      movies: movies ?? this.movies,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Signature for a function that loads a single page of a paginated endpoint.
typedef PaginatedPageLoader = Future<PaginatedMovies> Function(int page);

/// StateNotifier that drives "load page 1, then append page N+1 on scroll".
///
/// Tracks page/totalPages/hasMore/loading/error and de-duplicates movies when
/// appending so the same title never appears twice across page boundaries.
class PaginatedMoviesNotifier extends StateNotifier<PaginatedMoviesState> {
  final PaginatedPageLoader _loader;
  final bool _startOnInit;

  PaginatedMoviesNotifier(this._loader, {this._startOnInit = true})
      : super(const PaginatedMoviesState()) {
    if (_startOnInit) {
      Future<void>.microtask(loadInitial);
    }
  }

  /// Clears the current list and reloads page 1 (used for pull-to-refresh).
  Future<void> refresh() async {
    if (state.isLoadingInitial) return;
    state = const PaginatedMoviesState(isLoadingInitial: true);
    await _loadPage(1, replace: true);
  }

  Future<void> loadInitial() async {
    if (state.isLoadingInitial || state.movies.isNotEmpty) return;
    state = const PaginatedMoviesState(isLoadingInitial: true);
    await _loadPage(1, replace: true);
  }

  /// Load the next page if one exists and nothing is already in flight.
  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoadingInitial || !state.hasMore) {
      return;
    }
    final next = state.currentPage + 1;
    if (state.totalPages > 0 && next > state.totalPages) return;
    state = state.copyWith(isLoadingMore: true);
    await _loadPage(next, replace: false);
  }

  Future<void> _loadPage(int page, {required bool replace}) async {
    try {
      final result = await _loader(page);
      if (replace) {
        state = PaginatedMoviesState(
          movies: List.of(result.movies),
          currentPage: result.page,
          totalPages: result.totalPages,
        );
      } else {
        final seen = <int>{};
        final merged = <Movie>[];
        for (final m in state.movies) {
          if (seen.add(m.id)) merged.add(m);
        }
        for (final m in result.movies) {
          if (seen.add(m.id)) merged.add(m);
        }
        state = PaginatedMoviesState(
          movies: merged,
          currentPage: result.page,
          totalPages: result.totalPages,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingInitial: false,
        isLoadingMore: false,
        hasError: true,
        errorMessage: '$e',
      );
    }
  }
}

final genresProvider = FutureProvider<List<Genre>>((ref) {
  return ref.watch(movieRepositoryProvider).getGenres();
});

final genreMoviesProvider = FutureProvider.family<List<Movie>, int>((
  ref,
  genreId,
) {
  return ref.watch(movieRepositoryProvider).getByGenre(genreId);
});

final movieDetailsProvider = FutureProvider.family<Movie, int>((ref, movieId) {
  return ref.watch(movieRepositoryProvider).getMovieDetails(movieId);
});

final movieDetailsBundleProvider =
    FutureProvider.family<MovieDetailsBundle, int>((ref, movieId) {
      return ref.watch(movieRepositoryProvider).getMovieDetailsBundle(movieId);
    });

final movieCastProvider = FutureProvider.family<List<CastMember>, int>((
  ref,
  movieId,
) {
  return ref.watch(movieRepositoryProvider).getCast(movieId);
});

final movieTrailersProvider = FutureProvider.family<List<Trailer>, int>((
  ref,
  movieId,
) {
  return ref.watch(movieRepositoryProvider).getTrailers(movieId);
});

/// Every VERIFIED trailer for a movie (movie-scoped, strict validation).
/// Empty means no verified trailer exists — the UI shows "Trailer unavailable".
final verifiedTrailersProvider = FutureProvider.family<List<Trailer>, int>((
  ref,
  movieId,
) {
  return ref.watch(trailerServiceProvider).getVerifiedTrailersById(movieId);
});

/// The verified trailer resolved for [movieId] honoring an optional language.
///
/// When [languageCode] is null/auto, the documented priority applies
/// (original language -> English -> Hindi -> any verified trailer). Returns
/// `null` when no verified trailer exists.
final resolvedTrailerProvider = FutureProvider.family<Trailer?, ({int movieId, String? languageCode})>(
  (ref, args) {
    return ref
        .watch(trailerServiceProvider)
        .resolveTrailer(args.movieId, languageCode: args.languageCode);
  },
);

/// Best verified playable trailer for a movie, or `null` when none exists.
///
/// Single source of truth: the strict [TrailerService] engine resolves the
/// trailer from `/movie/{id}/videos` for the EXACT TMDb movie id, applies all
/// validation guards and marks the result `verified`. A `null` result means
/// the UI must show "Trailer unavailable" — never a wrong or guessed video.
final primaryTrailerProvider = FutureProvider.family<Trailer?, int>((
  ref,
  movieId,
) {
  return ref.watch(trailerServiceProvider).getOfficialTrailerById(movieId);
});

final similarMoviesProvider = FutureProvider.family<List<Movie>, int>((
  ref,
  movieId,
) {
  return ref.watch(movieRepositoryProvider).getSimilar(movieId);
});

final searchMoviesProvider = FutureProvider.family<List<Movie>, String>((
  ref,
  query,
) {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  return ref
      .watch(movieRepositoryProvider)
      .searchMovies(query, cancelToken: cancelToken);
});

/// The currently selected language filter for movie discovery.
/// `null` means "All Languages".
final languageFilterProvider = StateProvider<String?>((ref) => null);

/// Whether to filter for movies available in Hindi (Original or Dubbed).
final hindiAvailableFilterProvider = StateProvider<bool>((ref) => false);

final watchlistProvider = StateNotifierProvider<WatchlistNotifier, List<Movie>>(
  (ref) => WatchlistNotifier(),
);

class WatchlistNotifier extends StateNotifier<List<Movie>> {
  WatchlistNotifier() : super(const []) {
    _load();
  }

  static const String _storageKey = 'moviegpt_watchlist_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map(
            (e) => Movie.fromStorageJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      if (mounted) state = list;
    } catch (_) {
      // Keep empty state on load failure.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(state.map((m) => m.toStorageJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (_) {
      // Ignore persistence failures.
    }
  }

  void toggle(Movie movie) {
    final exists = state.any((m) => m.id == movie.id);
    if (exists) {
      state = state.where((m) => m.id != movie.id).toList();
    } else {
      state = [...state, movie];
    }
    _persist();
  }

  void add(Movie movie) {
    final exists = state.any((m) => m.id == movie.id);
    if (exists) return;
    state = [...state, movie];
    _persist();
  }

  void remove(Movie movie) {
    state = state.where((m) => m.id != movie.id).toList();
    _persist();
  }

bool isInWatchlist(int movieId) => state.any((m) => m.id == movieId);
}

/// The user's favorited movies (❤️), persisted via SharedPreferences.
///
/// Used by the details-screen favorite toggle and by the "Movie Match"
/// personalization engine (only real user activity feeds the match score).
final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<Movie>>(
  (ref) => FavoritesNotifier(),
);

class FavoritesNotifier extends StateNotifier<List<Movie>> {
  FavoritesNotifier() : super(const []) {
    _load();
  }

  static const String _storageKey = 'moviegpt_favorites_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map(
            (e) => Movie.fromStorageJson(
              (e as Map).map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList();
      state = list;
    } catch (_) {
      // Corrupt cache -> start empty.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(state.map((m) => m.toStorageJson()).toList()),
      );
    } catch (_) {}
  }

  void toggle(Movie movie) {
    final exists = state.any((m) => m.id == movie.id);
    if (exists) {
      state = state.where((m) => m.id != movie.id).toList();
    } else {
      state = [...state, movie];
    }
    _persist();
  }

  bool isFavorite(int movieId) => state.any((m) => m.id == movieId);
}

/// The active AI Personality Mode (Friend, Girlfriend, Smart Assistant).
///
/// Persisted via SharedPreferences (`moviegpt_selected_ai_mode_v2`) so the
/// user's choice survives app restarts. Defaults to Friend mode.
final selectedAiModeProvider =
    StateNotifierProvider<SelectedAiModeNotifier, AiMode>(
  (ref) => SelectedAiModeNotifier(),
);

class SelectedAiModeNotifier extends StateNotifier<AiMode> {
  SelectedAiModeNotifier() : super(AiPersonalities.defaultMode) {
    _load();
  }

  static const String _storageKey = 'moviegpt_selected_ai_mode_v3';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null) {
        state = AiPersonalities.modeFromName(saved);
      }
    } catch (_) {
      // Keep default on failure.
    }
  }

  Future<void> setMode(AiMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, AiPersonalities.modeToName(mode));
    } catch (_) {
      // Best effort persistence.
    }
  }
}


/// The user's preferred trailer language (ISO 639-1 code, or `auto`).
///
/// Persisted with SharedPreferences (`moviegpt_trailer_language_v1`) so the choice
/// survives restarts. `null` means the user has not chosen yet — the UI shows
/// "Auto" and the original-language trailer is selected.
final trailerLanguagePreferenceProvider =
    StateNotifierProvider<TrailerLanguagePreferenceNotifier, String?>(
      (ref) => TrailerLanguagePreferenceNotifier(),
    );

class TrailerLanguagePreferenceNotifier extends StateNotifier<String?> {
  TrailerLanguagePreferenceNotifier() : super(null) {
    _load();
  }

  static const String _storageKey = 'moviegpt_trailer_language_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null) state = saved;
    } catch (_) {
      // Keep unset on failure.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state == null) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, state!);
      }
    } catch (_) {
      // Best-effort persistence.
    }
  }

  /// Set the preference ([code] or `null` for auto).
  Future<void> setLanguage(String? code) async {
    state = code;
    await _persist();
  }
}

/// Real movies matching the structured [DiscoverFilters], backed by the
/// cached repository.
final discoverMoviesProvider = FutureProvider.family<List<Movie>, DiscoverFilters>((
  ref,
  filters,
) {
  return ref.watch(movieRepositoryProvider).discoverMovies(filters);
});

/// World cinema: real movies originally produced in a country/region
/// (ISO 3166-1 alpha-2), optionally restricted to a primary original
/// language (e.g. `ko` for Korea).
final worldCinemaProvider = FutureProvider.family<List<Movie>, String>((
  ref,
  countryCode,
) {
  return ref.watch(movieRepositoryProvider)
      .getByCountry(countryCode);
});
final chatHistoryProvider =
    StateNotifierProvider<ChatHistoryNotifier, List<ChatMessage>>(
      (ref) => ChatHistoryNotifier(
        storageKey: 'moviegpt_chat_history_v1_'
            '${AiPersonalities.modeToName(ref.watch(selectedAiModeProvider))}',
        loadFromPrefs: false,
      ),
    );

class ChatHistoryNotifier extends StateNotifier<List<ChatMessage>> {
  ChatHistoryNotifier({
    String? storageKey,
    this.loadFromPrefs = true,
  })  : _storageKey = storageKey ?? 'moviegpt_chat_history_v1',
        super(const []) {
    if (loadFromPrefs) _load();
  }

  /// When false, this notifier starts empty and never reads persisted
  /// history. Per-assistant sessions use this so switching modes always
  /// starts a completely fresh chat (zero context from any other mode).
  final bool loadFromPrefs;

  /// Maximum number of messages persisted (bounded to avoid unbounded growth).
  static const int maxMessages = 50;

  final String _storageKey;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final messages = <ChatMessage>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        final msg = ChatMessage.fromJson(
          e.map((k, v) => MapEntry(k.toString(), v)),
        );
        // Skip malformed entries (id marker used by fromJson for bad input).
        if (msg.id == '<invalid>' || msg.text.isEmpty) continue;
        messages.add(msg);
      }
      // Bound to the last N messages.
      if (messages.length > maxMessages) {
        messages.removeRange(0, messages.length - maxMessages);
      }
      if (messages.isNotEmpty) state = messages;
    } catch (_) {
      // Corrupted history is handled gracefully: reset to empty.
      state = const [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(state.map((m) => m.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (_) {
      // Persistence is best-effort; ignore failures.
    }
  }

  /// Append a message and persist (bounded to the last [maxMessages]).
  void add(ChatMessage message) {
    final next = [...state, message];
    state = next.length > maxMessages
        ? next.sublist(next.length - maxMessages)
        : next;
    _persist();
  }

  /// Replace the whole history (used to batch-restore after a load).
  void replaceAll(List<ChatMessage> messages) {
    final bounded = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;
    state = List.unmodifiable(bounded);
    _persist();
  }

  /// Removes the most recent message (used when clearing a failed/error
  /// bubble before a retry). No-op when history is empty.
  void removeLast() {
    if (state.isEmpty) return;
    state = state.sublist(0, state.length - 1);
    _persist();
  }

/// Replaces the most recent message in place (used to stream an assistant
  /// reply's text as chunks arrive). Does NOT persist on every chunk — call
  /// [persistNow] once the stream completes to avoid heavy disk writes.
  void updateLast(ChatMessage Function(ChatMessage current) transform) {
    if (state.isEmpty) return;
    final last = state.last;
    state = [...state.sublist(0, state.length - 1), transform(last)];
  }

  /// Persists the current history immediately (used after streaming ends).
  void persistNow() => _persist();

  /// Clear the conversation AND persisted history.
  /// Clear the conversation AND persisted history.
  Future<void> clear() async {
    state = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Best-effort.
    }
  }
}

