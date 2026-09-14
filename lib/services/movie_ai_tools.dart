import '../data/movie_repository.dart';
import '../models/discover_filters.dart';
import '../models/movie_model.dart';
import 'ai_service.dart';

/// Callbacks that let the AI tools read and modify the user's watchlist
/// without depending on Riverpod directly.
class MovieToolContext {
  final List<Movie> Function() watchlist;
  final void Function(Movie movie) addToWatchlist;
  final void Function(Movie movie) removeFromWatchlist;

  const MovieToolContext({
    required this.watchlist,
    required this.addToWatchlist,
    required this.removeFromWatchlist,
  });
}

/// REAL movie intelligence tools for the AI chat, backed by [MovieRepository]
/// (live TMDb). The model calls these via function calling so movie facts
/// always come from actual TMDb data â€” never from the model's memory.
class MovieAiTools {
  MovieAiTools({MovieRepository? repository, required this.context})
      : _repo = repository ?? MovieRepository.instance;

  final MovieRepository _repo;
  final MovieToolContext context;

  static const int _defaultLimit = 6;
  static const int _maxLimit = 10;

  /// Cached TMDb genre list (id -> name) for genre-name resolution.
  static Map<int, String>? _genreCache;

  // -- Tool declarations -----------------------------------------------------

  /// Tool schemas the AI model may call (OpenAI-style JSON schema subset).
  static const List<AiToolSpec> specs = [
    AiToolSpec(
      name: 'search_movies',
      description:
          'Search TMDb for movies by title or keyword. Use for "find/show me '
          '<title>", "is there a movie called X" and watchlist additions.',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Movie title or keyword to search for.',
          },
          'limit': {
            'type': 'integer',
            'description': 'How many results to return (1-10, default 6).',
          },
        },
        'required': ['query'],
      },
    ),
    AiToolSpec(
      name: 'discover_movies',
      description:
          'Discover movies with filters (genre, year range, minimum rating, '
          'language, runtime). Use for recommendations like "good sci-fi '
          'movies", "action movies from the 90s", "Korean thrillers above 8", '
          '"something under 100 minutes".',
      parameters: {
        'type': 'object',
        'properties': {
          'genre': {
            'type': 'string',
            'description':
                'Genre name, e.g. action, comedy, sci-fi, horror, romance, '
                'thriller, drama, animation, fantasy, crime, war, western.',
          },
          'year_from': {
            'type': 'integer',
            'description': 'Earliest release year (inclusive).',
          },
          'year_to': {
            'type': 'integer',
            'description': 'Latest release year (inclusive).',
          },
          'min_rating': {
            'type': 'number',
            'description': 'Minimum TMDb vote average (0-10), e.g. 7 or 8.',
          },
          'language': {
            'type': 'string',
            'description':
                'ISO 639-1 original language code, e.g. en, hi, ko, ta, es, ja.',
          },
          'max_runtime_minutes': {
            'type': 'integer',
            'description': 'Maximum runtime in minutes.',
          },
          'sort': {
            'type': 'string',
            'enum': ['popularity', 'rating', 'newest'],
            'description': 'Sort order (default popularity).',
          },
          'limit': {
            'type': 'integer',
            'description': 'How many results to return (1-10, default 6).',
          },
        },
      },
    ),
    AiToolSpec(
      name: 'movie_details',
      description:
          'Get full details for one movie by TMDb id: plot, cast, director, '
          'runtime, release, rating. Use when the user asks what a movie is '
          'about, who acted/directed it, or for a deep-dive. Resolve the id '
          'with search_movies first if you only have a title.',
      parameters: {
        'type': 'object',
        'properties': {
          'movie_id': {
            'type': 'integer',
            'description': 'TMDb movie id.',
          },
        },
        'required': ['movie_id'],
      },
    ),
    AiToolSpec(
      name: 'similar_movies',
      description:
          'Find movies similar to a given movie. Use for "movies like '
          'Interstellar" and "something similar".',
      parameters: {
        'type': 'object',
        'properties': {
          'movie_id': {
            'type': 'integer',
            'description': 'TMDb movie id (from search_movies).',
          },
          'title': {
            'type': 'string',
            'description': 'Movie title to resolve when you do not know the id.',
          },
          'limit': {
            'type': 'integer',
            'description': 'How many results to return (1-10, default 6).',
          },
        },
      },
    ),
    AiToolSpec(
      name: 'person_movies',
      description:
          "Get a person's filmography (as actor or director). Use for 'Tom "
          "Cruise movies', 'movies directed by Christopher Nolan'.",
      parameters: {
        'type': 'object',
        'properties': {
          'person_name': {
            'type': 'string',
            'description': 'Actor or director name.',
          },
          'as_director': {
            'type': 'boolean',
            'description':
                'true for movies they DIRECTED (default false: acted).',
          },
          'limit': {
            'type': 'integer',
            'description': 'How many results to return (1-10, default 6).',
          },
        },
        'required': ['person_name'],
      },
    ),
    AiToolSpec(
      name: 'trending_movies',
      description:
          "Get movies trending today on TMDb. Use for 'what's trending', "
          "'popular right now'.",
      parameters: {
        'type': 'object',
        'properties': {
          'limit': {
            'type': 'integer',
            'description': 'How many results to return (1-10, default 6).',
          },
        },
      },
    ),
    AiToolSpec(
      name: 'upcoming_movies',
      description:
          'Get movies coming soon (next ~15 months). Use for "coming soon", '
          '"upcoming movies", "releases this month".',
      parameters: {
        'type': 'object',
        'properties': {
          'limit': {
            'type': 'integer',
            'description': 'How many results to return (1-10, default 6).',
          },
        },
      },
    ),
    AiToolSpec(
      name: 'get_watchlist',
      description: "Get the user's saved watchlist movies.",
      parameters: {'type': 'object', 'properties': <String, dynamic>{}},
    ),
    AiToolSpec(
      name: 'add_to_watchlist',
      description:
          "Add a movie to the user's watchlist. Resolve the TMDb id with "
          'search_movies first when you only have a title.',
      parameters: {
        'type': 'object',
        'properties': {
          'movie_id': {
            'type': 'integer',
            'description': 'TMDb movie id to add.',
          },
        },
        'required': ['movie_id'],
      },
    ),
    AiToolSpec(
      name: 'remove_from_watchlist',
      description: "Remove a movie from the user's watchlist by TMDb id.",
      parameters: {
        'type': 'object',
        'properties': {
          'movie_id': {
            'type': 'integer',
            'description': 'TMDb movie id to remove.',
          },
        },
        'required': ['movie_id'],
      },
    ),
  ];

  // -- Tool execution --------------------------------------------------------

  /// Executes a tool call requested by the AI model. Never throws â€” failures
  /// are returned as an `error` payload so the model can tell the user what
  /// happened instead of the app crashing.
  Future<AiToolResult> handle(String name, Map<String, dynamic> args) async {
    try {
      switch (name) {
        case 'search_movies':
          return await _searchMovies(args);
        case 'discover_movies':
          return await _discoverMovies(args);
        case 'movie_details':
          return await _movieDetails(args);
        case 'similar_movies':
          return await _similarMovies(args);
        case 'person_movies':
          return await _personMovies(args);
        case 'trending_movies':
          return await _trendingMovies(args);
        case 'upcoming_movies':
          return await _upcomingMovies(args);
        case 'get_watchlist':
          return _watchlist();
        case 'add_to_watchlist':
          return await _addToWatchlist(args);
        case 'remove_from_watchlist':
          return _removeFromWatchlist(args);
        default:
          return const AiToolResult({
            'error': 'Unknown tool. Available tools: search_movies, '
                'discover_movies, movie_details, similar_movies, '
                'person_movies, trending_movies, upcoming_movies, '
                'get_watchlist, add_to_watchlist, remove_from_watchlist.',
          });
      }
    } catch (e) {
      return AiToolResult({
        'error': 'Movie data is unavailable right now '
            '(offline or TMDb key missing). Tell the user politely.',
        'detail': e.toString(),
      });
    }
  }

  int _limit(Map<String, dynamic> args) {
    final raw = args['limit'];
    if (raw is num) return raw.toInt().clamp(1, _maxLimit);
    return _defaultLimit;
  }

  int? _intArg(Map<String, dynamic> args, String key) {
    final raw = args[key];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  double? _doubleArg(Map<String, dynamic> args, String key) {
    final raw = args[key];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  String? _stringArg(Map<String, dynamic> args, String key) {
    final raw = args[key]?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  List<Movie> _cap(List<Movie> movies, int limit) =>
      movies.take(limit).toList(growable: false);

  AiToolResult _listResult(String label, List<Movie> movies, int limit) {
    final capped = _cap(movies, limit);
    return AiToolResult(
      {
        'query': label,
        'count': capped.length,
        'results': [for (final m in capped) _movieJson(m)],
      },
      movies: capped,
    );
  }

  Map<String, dynamic> _movieJson(Movie m) => {
        'id': m.id,
        'title': m.title,
        'year': m.year,
        'rating': m.rating,
        'genres': m.genre,
        'overview': m.overview.length > 240
            ? '${m.overview.substring(0, 240)}...'
            : m.overview,
      };

  // -- Tool implementations --------------------------------------------------

  Future<AiToolResult> _searchMovies(Map<String, dynamic> args) async {
    final query = _stringArg(args, 'query');
    if (query == null) {
      return const AiToolResult({'error': 'Missing "query" argument.'});
    }
    final results = await _repo.searchMovies(query);
    return _listResult(query, results, _limit(args));
  }

  Future<AiToolResult> _discoverMovies(Map<String, dynamic> args) async {
    final genreName = _stringArg(args, 'genre');
    final genreId = genreName == null ? null : await _resolveGenreId(genreName);
    if (genreName != null && genreId == null) {
      return AiToolResult({
        'error': 'Unknown genre "$genreName". Try action, comedy, drama, '
            'horror, thriller, sci-fi, romance, animation, crime, fantasy...',
      });
    }

    final sort = switch (_stringArg(args, 'sort')) {
      'rating' => 'vote_average.desc',
      'newest' => 'primary_release_date.desc',
      _ => 'popularity.desc',
    };

    final yearFrom = _intArg(args, 'year_from');
    final yearTo = _intArg(args, 'year_to');
    final filters = DiscoverFilters(
      genreId: genreId,
      withOriginalLanguage: _stringArg(args, 'language'),
      minRating: _doubleArg(args, 'min_rating'),
      runtimeMax: _intArg(args, 'max_runtime_minutes'),
      releaseDateGte: yearFrom == null ? null : '$yearFrom-01-01',
      releaseDateLte: yearTo == null ? null : '$yearTo-12-31',
      sortBy: sort,
    );

    final results = await _repo.discoverMovies(filters);
    return _listResult(filters.describe(), results, _limit(args));
  }

  Future<AiToolResult> _movieDetails(Map<String, dynamic> args) async {
    final id = _intArg(args, 'movie_id');
    if (id == null) {
      return const AiToolResult({'error': 'Missing "movie_id" argument.'});
    }
    final bundle = await _repo.getMovieDetailsBundle(id);
    final m = bundle.movie;
    return AiToolResult(
      {
        'id': m.id,
        'title': m.title,
        'year': m.year,
        'release_date': m.releaseDate,
        'rating': m.rating,
        'vote_count': m.voteCount,
        'genres': m.genre,
        'runtime_minutes': m.runtimeMinutes,
        'status': m.status,
        'tagline': m.tagline,
        'overview': m.overview,
        'director': m.director,
        'cast': [
          for (final c in bundle.cast.take(8))
            {'name': c.name, 'character': c.character},
        ],
      },
      movies: [m],
    );
  }

  Future<AiToolResult> _similarMovies(Map<String, dynamic> args) async {
    final limit = _limit(args);
    final id = _intArg(args, 'movie_id');
    var movieId = id;
    var label = id?.toString() ?? '';

    if (movieId == null) {
      final title = _stringArg(args, 'title');
      if (title == null) {
        return const AiToolResult({
          'error': 'Provide either "movie_id" or "title".',
        });
      }
      final found = await _repo.searchMovies(title);
      if (found.isEmpty) {
        return AiToolResult({'error': 'No TMDb match found for "$title".'});
      }
      movieId = found.first.id;
      label = found.first.title;
    }

    final similar = await _repo.getSimilar(movieId);
    return _listResult(label, similar, limit);
  }

  Future<AiToolResult> _personMovies(Map<String, dynamic> args) async {
    final personName = _stringArg(args, 'person_name');
    if (personName == null) {
      return const AiToolResult({'error': 'Missing "person_name" argument.'});
    }
    final asDirector = args['as_director'] == true;
    final person = await _repo.searchPerson(personName);
    if (person == null || person['id'] == null) {
      return AiToolResult({'error': 'No person found for "$personName".'});
    }
    final personId = (person['id'] as num).toInt();
    final realName = (person['name'] as String?) ?? personName;
    final credits = await _repo.getPersonMovieCredits(
      personId,
      asDirector: asDirector,
    );
    credits.sort((a, b) => b.rating.compareTo(a.rating));
    return _listResult(realName, credits, _limit(args));
  }

  Future<AiToolResult> _trendingMovies(Map<String, dynamic> args) async {
    final results = await _repo.getTrending();
    return _listResult('Trending today', results, _limit(args));
  }

  Future<AiToolResult> _upcomingMovies(Map<String, dynamic> args) async {
    final now = DateTime.now();
    final page = await _repo.getUpcomingRange(
      start: now,
      end: DateTime(now.year, now.month + 15, now.day),
    );
    return _listResult('Upcoming', page.movies, _limit(args));
  }

  AiToolResult _watchlist() {
    final list = context.watchlist();
    return AiToolResult(
      {
        'count': list.length,
        'results': [for (final m in list) _movieJson(m)],
      },
      movies: list,
    );
  }

  Future<AiToolResult> _addToWatchlist(Map<String, dynamic> args) async {
    final id = _intArg(args, 'movie_id');
    if (id == null) {
      return const AiToolResult({'error': 'Missing "movie_id" argument.'});
    }
    final existing = context.watchlist();
    if (existing.any((m) => m.id == id)) {
      return const AiToolResult({
        'status': 'already_in_watchlist',
        'note': 'That movie is already on the watchlist.',
      });
    }
    final movie = await _repo.getMovieDetails(id);
    context.addToWatchlist(movie);
    return AiToolResult(
      {
        'status': 'added',
        'movie': _movieJson(movie),
      },
      movies: [movie],
    );
  }

  AiToolResult _removeFromWatchlist(Map<String, dynamic> args) {
    final id = _intArg(args, 'movie_id');
    if (id == null) {
      return const AiToolResult({'error': 'Missing "movie_id" argument.'});
    }
    final existing = context.watchlist();
    final match = existing.where((m) => m.id == id).toList();
    if (match.isEmpty) {
      return const AiToolResult({
        'status': 'not_found',
        'note': 'That movie is not on the watchlist.',
      });
    }
    context.removeFromWatchlist(match.first);
    return AiToolResult(
      {
        'status': 'removed',
        'movie': _movieJson(match.first),
      },
      movies: [match.first],
    );
  }

  /// Resolves a genre name to its TMDb genre id (cached).
  Future<int?> _resolveGenreId(String name) async {
    final normalized = name.toLowerCase().trim();
    const known = <String, int>{
      'action': 28,
      'adventure': 12,
      'animation': 16,
      'anime': 16,
      'comedy': 35,
      'crime': 80,
      'documentary': 99,
      'drama': 18,
      'family': 10751,
      'fantasy': 14,
      'history': 36,
      'horror': 27,
      'music': 10402,
      'mystery': 9648,
      'romance': 10749,
      'romantic': 10749,
      'sci-fi': 878,
      'science fiction': 878,
      'science-fiction': 878,
      'scifi': 878,
      'thriller': 53,
      'war': 10752,
      'western': 37,
    };
    final direct = known[normalized];
    if (direct != null) return direct;

    // Fall back to the live genre list from TMDb.
    if (_genreCache == null) {
      try {
        final genres = await _repo.getGenres();
        _genreCache = {for (final g in genres) g.id: g.name.toLowerCase()};
      } catch (_) {
        _genreCache = const {};
      }
    }
    for (final entry in _genreCache!.entries) {
      final g = entry.value;
      if (g == normalized || g.contains(normalized) || normalized.contains(g)) {
        return entry.key;
      }
    }
    return null;
  }
}
