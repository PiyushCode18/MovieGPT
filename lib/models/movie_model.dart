/// Core domain model for a movie.
///
/// Strictly uses TMDB remote data (via `posterPath`/`backdropPath`).
/// Local fallback assets are no longer supported to ensure live content.
class Movie {
  final int id;
  final String title;
  final String tagline;
  final String overview;
  final String genre;
  final double rating;
  final int voteCount;
  final int aiMatchScore; // e.g. 98 -> 98%
  final String releaseDate;
  final String year;
  final int runtimeMinutes;
  final String duration;
  final String maturityRating;
  final String? posterPath; // TMDB relative path
  final String? backdropPath; // TMDB relative path
  final String aiReasoning;
  final List<CastMember> cast;
  final List<String> tags;
  final String director;
  final String production;
  final String status; // e.g. "Released", "In Production", "Upcoming"

  /// ISO 639-1 original language code from TMDb (e.g. "en", "hi", "ko").
  final String originalLanguage;

  /// List of ISO 639-1 language codes available for this movie (audio).
  final List<String> spokenLanguages;

  const Movie({
    this.id = 0,
    required this.title,
    this.tagline = '',
    this.overview = '',
    this.genre = 'Movie',
    this.rating = 0,
    this.voteCount = 0,
    this.aiMatchScore = 90,
    this.releaseDate = '',
    this.year = '',
    this.runtimeMinutes = 0,
    this.duration = '',
    this.maturityRating = '',
    this.posterPath,
    this.backdropPath,
    this.aiReasoning = '',
    this.cast = const [],
    this.tags = const [],
    this.director = '',
    this.production = '',
    this.status = 'Released',
    this.originalLanguage = '',
    this.spokenLanguages = const [],
  });

  /// Build a URL for a TMDB image with the given [size] width prefix.
  String? imageUrl(String size) {
    if (posterPath == null && backdropPath == null) return null;
    final path = backdropPath ?? posterPath!;
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  String? posterUrl([String size = 'w500']) {
    if (posterPath == null) return null;
    return 'https://image.tmdb.org/t/p/$size$posterPath';
  }

  /// Build a high-resolution poster URL (original size from TMDB).
  String? get posterUrlOriginal {
    if (posterPath == null) return null;
    return 'https://image.tmdb.org/t/p/original$posterPath';
  }

  String? backdropUrl([String size = 'w780']) {
    if (backdropPath == null) return null;
    return 'https://image.tmdb.org/t/p/$size$backdropPath';
  }

  Movie copyWith({
    String? aiReasoning,
    List<CastMember>? cast,
    String? genre,
    String? overview,
    String? director,
    String? production,
    String? status,
  }) {
    return Movie(
      id: id,
      title: title,
      tagline: tagline,
      overview: overview ?? this.overview,
      genre: genre ?? this.genre,
      rating: rating,
      voteCount: voteCount,
      aiMatchScore: aiMatchScore,
      releaseDate: releaseDate,
      year: year,
      runtimeMinutes: runtimeMinutes,
      duration: duration,
      maturityRating: maturityRating,
      posterPath: posterPath,
      backdropPath: backdropPath,
      aiReasoning: aiReasoning ?? this.aiReasoning,
      cast: cast ?? this.cast,
      tags: tags,
      director: director ?? this.director,
      production: production ?? this.production,
      status: status ?? this.status,
      originalLanguage: originalLanguage,
      spokenLanguages: spokenLanguages,
    );
  }

  factory Movie.fromJson(Map<String, dynamic> json) {
    final genres =
        (json['genres'] as List?)
            ?.map((g) => _asStringMap(g)['name'].toString())
            .where((n) => n.isNotEmpty)
            .toList() ??
        [];

    // Null-safe helper: extract a list of string maps without throwing.
    List<Map<String, dynamic>> crewList() {
      final credits = _asStringMap(json['credits']);
      final crew = credits['crew'];
      if (crew is List) {
        return crew
            .map((e) => _asStringMap(e))
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    final directorList = crewList()
        .where((c) => c['job'] == 'Director')
        .map((c) => c['name'].toString())
        .where((n) => n.isNotEmpty)
        .toList();
    final director = directorList.isNotEmpty ? directorList.first : '';

    final productionCompanies = json['production_companies'];
    final production = productionCompanies is List
        ? productionCompanies
              .map((c) => _asStringMap(c)['name'].toString())
              .where((n) => n.isNotEmpty)
              .take(2)
              .join(', ')
        : '';

    final spoken = (json['spoken_languages'] as List?)
            ?.map((l) => _asStringMap(l)['iso_639_1'].toString())
            .where((c) => c.isNotEmpty)
            .toList() ??
        [];

    final voteAverage = ((json['vote_average'] as num?) ?? 0).toDouble();
    final matchScore = (voteAverage * 10 + 18).round().clamp(0, 99);

    return Movie(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] ?? json['name'] ?? 'Untitled',
      tagline: json['tagline'] ?? '',
      overview: json['overview'] ?? '',
      genre: genres.isNotEmpty ? genres.join(' / ') : 'Movie',
      rating: voteAverage,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      aiMatchScore: matchScore,
      releaseDate: json['release_date'] ?? '',
      year: _yearFromDate(json['release_date'] ?? ''),
      runtimeMinutes: (json['runtime'] as num?)?.toInt() ?? 0,
      duration: _durationFromMinutes((json['runtime'] as num?)?.toInt() ?? 0),
      maturityRating: json['adult'] == true ? 'R' : 'PG-13',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      // Honest, metadata-derived reasoning only: real TMDb rating and real
      // genres. Never a fabricated "taste profile" claim.
      aiReasoning: _buildReasoning(voteAverage, json['vote_count'], genres),
      cast: const [],
      tags: genres,
      director: director,
      production: production,
      status: json['status'] ?? 'Released',
      originalLanguage: json['original_language'] ?? '',
      spokenLanguages: spoken,
    );
  }

  /// Safely coerce an arbitrary decoded value into a `Map<String, dynamic>`.
  /// Never throws — returns an empty map for non-map inputs.
  static Map<String, dynamic> _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  /// Serialize to a compact JSON map for local storage (SharedPreferences).
  Map<String, dynamic> toStorageJson() => {
    'id': id,
    'title': title,
    'tagline': tagline,
    'overview': overview,
    'genre': genre,
    'rating': rating,
    'vote_count': voteCount,
    'ai_match_score': aiMatchScore,
    'release_date': releaseDate,
    'year': year,
    'runtime': runtimeMinutes,
    'duration': duration,
    'maturity_rating': maturityRating,
    'poster_path': posterPath,
    'backdrop_path': backdropPath,
    'director': director,
    'production': production,
    'status': status,
    'original_language': originalLanguage,
    'spoken_languages': spokenLanguages,
  };

  /// Rebuild a [Movie] from a locally-stored JSON map.
  factory Movie.fromStorageJson(Map<String, dynamic> json) => Movie(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] ?? 'Untitled',
    tagline: json['tagline'] ?? '',
    overview: json['overview'] ?? '',
    genre: json['genre'] ?? 'Movie',
    rating: ((json['rating'] as num?) ?? 0).toDouble(),
    voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
    aiMatchScore: (json['ai_match_score'] as num?)?.toInt() ?? 90,
    releaseDate: json['release_date'] ?? '',
    year: json['year'] ?? '',
    runtimeMinutes: (json['runtime'] as num?)?.toInt() ?? 0,
    duration: json['duration'] ?? '',
    maturityRating: json['maturity_rating'] ?? '',
    posterPath: json['poster_path'],
    backdropPath: json['backdrop_path'],
    director: json['director'] ?? '',
    production: json['production'] ?? '',
    status: json['status'] ?? 'Released',
    originalLanguage: json['original_language'] ?? '',
    spokenLanguages: (json['spoken_languages'] as List?)?.cast<String>() ?? const [],
  );

  /// Builds honest, metadata-derived reasoning text for the details screen.
  ///
  /// Uses ONLY real TMDb data (vote average, vote count, genre names) — never
  /// a fabricated "taste profile" or invented statistic.
  static String _buildReasoning(
    double voteAverage,
    Object? voteCount,
    List<String> genres,
  ) {
    final buffer = StringBuffer('MovieGPT analysis: ');
    buffer.write('rated ${voteAverage.toStringAsFixed(1)}/10 on TMDb');
    final votes = (voteCount as num?)?.toInt();
    if (votes != null && votes > 0) {
      buffer.write(' by $votes viewers');
    }
    if (genres.isNotEmpty) {
      buffer.write(' · Genres: ${genres.take(3).join(', ')}');
    }
    buffer.write('.');
    return buffer.toString();
  }

  static String _yearFromDate(String date) {
    if (date.length >= 4) return date.substring(0, 4);
    return '';
  }

  static String _durationFromMinutes(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

class CastMember {
  final int id;
  final String name;
  final String character;
  final String? profilePath; // TMDB relative path

  const CastMember({
    this.id = 0,
    required this.name,
    required this.character,
    this.profilePath,
  });

  String? profileUrl([String size = 'w185']) {
    if (profilePath == null) return null;
    return 'https://image.tmdb.org/t/p/$size$profilePath';
  }

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? json['original_name'] ?? 'Unknown',
      character: json['character'] ?? json['job'] ?? '',
      profilePath: json['profile_path'],
    );
  }
}

class Trailer {
  final String id;
  final String key;
  final String name;
  final String site;
  final String type;

  /// ISO 639-1 language code (e.g. "en", "hi").
  final String lang;

  /// ISO 3166-1 country/region code from TMDb (e.g. "US", "IN").
  final String region;

  /// ISO 8601 publish date from TMDb (e.g. "2025-05-01T12:00:00.000Z").
  final String publishedAt;

  /// Whether TMDb marks this video as an official release.
  final bool official;

  /// The provider this trailer data originated from.
  final String source;

  /// True only after strict movie-scoped validation.
  final bool verified;

  const Trailer({
    required this.id,
    required this.key,
    required this.name,
    required this.site,
    required this.type,
    this.lang = '',
    this.region = '',
    this.publishedAt = '',
    this.official = false,
    this.source = 'TMDB',
    this.verified = false,
  });

  String get youtubeUrl =>
      'https://www.youtube.com/watch?v=$key';

  /// Alias used by TrailerService.
  bool get isOfficial => official;

  /// Human-readable language name.
  String get languageName => _languageName(lang);

  /// True when this trailer is considered dubbed.
  bool get isDubbed => _isDubbedLanguage(lang);

  /// True when this trailer is in the original language.
  bool get isOriginal => _isOriginalLanguage(lang);

  /// Trailer label based on language.
  String get trailerType => _trailerType(lang);

  /// True when this is an official main trailer.
  bool get isTrailer =>
      site.toLowerCase() == 'youtube' &&
      type.toLowerCase() == 'trailer';

  /// True when this is a teaser.
  bool get isTeaser =>
      site.toLowerCase() == 'youtube' &&
      type.toLowerCase() == 'teaser';

  /// True when the trailer is in English.
  bool get isEnglish => lang.toLowerCase() == 'en';

  /// True when the trailer is in Hindi.
  bool get isHindi => lang.toLowerCase() == 'hi';

  /// Alias for the YouTube video id.
  String get videoId => key;

  /// True only when this trailer can be safely played.
  bool get isVerifiedPlayable =>
      verified && key.trim().isNotEmpty;

  Trailer copyWith({
    bool? verified,
    bool? official,
    String? source,
    String? lang,
    String? region,
    String? publishedAt,
    String? name,
  }) {
    return Trailer(
      id: id,
      key: key,
      name: name ?? this.name,
      site: site,
      type: type,
      lang: lang ?? this.lang,
      region: region ?? this.region,
      publishedAt: publishedAt ?? this.publishedAt,
      official: official ?? this.official,
      source: source ?? this.source,
      verified: verified ?? this.verified,
    );
  }

  factory Trailer.fromJson(Map<String, dynamic> json) {
    final officialFlag = json['official'];

    return Trailer(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      site: json['site']?.toString() ?? 'YouTube',
      type: json['type']?.toString() ?? 'Trailer',
      lang: json['iso_639_1']?.toString() ?? '',
      region: json['iso_3166_1']?.toString() ?? '',
      publishedAt: json['published_at']?.toString() ?? '',
      official: officialFlag == true,
      source: 'TMDB',
      verified: false,
    );
  }

  /// Canonical type label using BOTH the TMDb video `type` and the language.
  ///
  /// Returns labels such as:
  ///   - "Official Trailer" / "Official Teaser"
  ///   - "Hindi Dubbed Trailer"
  ///   - "Tamil Dubbed Teaser"
  ///   - "International Trailer" (non-English, non-dubbed)
  /// It never mistakes a teaser for a full trailer and never labels a dubbed
  /// language as the original.
  String get trailerTypeLabel {
    final isTeas = isTeaser;
    final langLabel = languageName.isEmpty ? 'Unknown' : languageName;
    final kind = isTeas ? 'Teaser' : 'Trailer';

    if (isOriginal) {
      return official ? 'Official $kind' : '$langLabel $kind';
    }
    if (isDubbed) {
      return '$langLabel Dubbed $kind';
    }
    // Non-English, non-dubbed: an international/other-language release.
    return 'International $kind';
  }

  /// ISO 639-1 language code (alias to `lang`).
  String get languageCode => lang;

  /// Whether this trailer has passed the strict movie-scoped verification.
  bool get isVerified => verified;

  /// True when this is an "International Trailer" (non-English, non-dubbed).
  bool get isInternational =>
      !isEnglish && !isOriginal && !isDubbed && languageName.isNotEmpty;

  /// Return the human-readable language name.
  static String _languageName(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return 'English';
      case 'hi':
        return 'Hindi';
      case 'ta':
        return 'Tamil';
      case 'te':
        return 'Telugu';
      case 'ml':
        return 'Malayalam';
      case 'kn':
        return 'Kannada';
      case 'bn':
        return 'Bengali';
      case 'mr':
        return 'Marathi';
      case 'gu':
        return 'Gujarati';
      case 'pa':
        return 'Punjabi';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'zh':
        return 'Chinese';
      case 'ar':
        return 'Arabic';
      case 'pt':
        return 'Portuguese';
      case 'ru':
        return 'Russian';
      default:
        return code.isEmpty ? 'Unknown' : code.toUpperCase();
    }
  }

  /// Return whether the language is treated as original.
  static bool _isOriginalLanguage(String code) {
    final lower = code.toLowerCase();

    // Current MovieGPT behavior:
    // English is treated as the default original language.
    return lower == 'en';
  }

  /// Return whether the language indicates a dubbed version.
  static bool _isDubbedLanguage(String code) {
    final lower = code.toLowerCase();

    const dubbedLanguages = {
      'hi',
      'ta',
      'te',
      'ml',
      'kn',
      'bn',
      'mr',
      'gu',
      'pa',
    };

    return dubbedLanguages.contains(lower);
  }

  /// Determine the trailer type label.
  static String _trailerType(String code) {
    final isOrig = _isOriginalLanguage(code);
    final isDb = _isDubbedLanguage(code);

    if (isOrig && !isDb) {
      return 'Official Trailer';
    }

    if (!isOrig && isDb) {
      return '${code.toUpperCase()} Dubbed Trailer';
    }

    if (!isOrig && !isDb) {
      return '${code.toUpperCase()} Trailer';
    }

    return 'Official Trailer';
  }

  }

class Genre {
  final int id;
  final String name;

  const Genre({required this.id, required this.name});

  factory Genre.fromJson(Map<String, dynamic> json) =>
      Genre(id: (json['id'] as num?)?.toInt() ?? 0, name: json['name'] ?? '');
}

/// Aggregated payload for the movie details screen.
///
/// Combines the movie, its cast, trailers, and similar movies into a single
/// object so the details screen can be rendered from ONE TMDB request
/// (using `append_to_response`) instead of four separate network calls.
class MovieDetailsBundle {
  final Movie movie;
  final List<CastMember> cast;
  final List<Trailer> trailers;
  final List<Movie> similar;

  const MovieDetailsBundle({
    required this.movie,
    this.cast = const [],
    this.trailers = const [],
    this.similar = const [],
  });
}

/// A single chat message in the AI concierge conversation.
///
/// Supports JSON serialization so the conversation history (last 50 messages)
/// can be persisted locally via SharedPreferences. **Never** stores secrets,
/// API keys, or tokens — only the user's text, the AI text, and the
/// recommended movie (id + title + poster refs) for offline re-render.
class ChatMessage {
  final String id;
  final String sender; // 'user' or 'ai'
  final String text;
  final DateTime timestamp;
  final List<Movie>? recommended;

  /// Which assistant mode generated this message ('female' | 'male' |
  /// 'assistant'). Null on user messages and legacy entries.
  final String? assistantMode;

  /// True when this bubble is an honest delivery/error notice, not AI
  /// conversation content. Error bubbles are excluded from the AI history
  /// payload and can be retried.
  final bool isError;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.recommended,
    this.assistantMode,
    this.isError = false,
  });

  /// Serialize to a compact JSON map for local persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'recommended': recommended?.map((m) => m.toStorageJson()).toList(),
        if (assistantMode != null) 'assistantMode': assistantMode,
        if (isError) 'isError': true,
      };

  /// Rebuild a [ChatMessage] from a persisted JSON map (null-safe).
  /// Returns a message with the id `<invalid>` for malformed entries so the
  /// caller can skip them.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final sender = json['sender']?.toString();
    final text = json['text']?.toString();
    final ts = json['timestamp']?.toString();
    if (id == null || sender == null || text == null || ts == null) {
      return ChatMessage(
        id: '<invalid>',
        sender: 'ai',
        text: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
    DateTime timestamp;
    try {
      timestamp = DateTime.parse(ts);
    } catch (_) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(0);
    }
    final rawMovies = json['recommended'];
    List<Movie>? recommended;
    if (rawMovies is List) {
      final movies = <Movie>[];
      for (final e in rawMovies) {
        if (e is Map) {
          try {
            movies.add(
              Movie.fromStorageJson(e.map((k, v) => MapEntry(k.toString(), v))),
            );
          } catch (_) {
            // Skip malformed movie entries.
          }
        }
      }
      if (movies.isNotEmpty) recommended = movies;
    }
    final mode = json['assistantMode']?.toString();
    return ChatMessage(
      id: id,
      sender: sender,
      text: text,
      timestamp: timestamp,
      recommended: recommended,
      assistantMode: (mode == 'female' || mode == 'male' || mode == 'assistant')
          ? mode
          : null,
      isError: json['isError'] == true,
    );
  }
}

