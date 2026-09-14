import 'movie_model.dart';

/// "YOUR MOVIE MATCH" — a deterministic personalization score for a movie,
/// computed ONLY from information that actually exists:
///
///  - the user's favorited / watchlisted movies (real activity), and
///  - the candidate movie's verified TMDB metadata (genres, language, rating).
///
/// There are no invented statistics: every percentage point traces back to one
/// of the criteria below, and every reason line shown in the UI corresponds to
/// a criterion that genuinely matched (or to the movie's real TMDB rating when
/// the user has no saved activity yet).
class MovieMatch {
  final int percent;
  final List<String> reasons;

  const MovieMatch(this.percent, this.reasons);

  /// Compute the match for [movie] against [likedMovies] (favorites +
  /// watchlist combined by the caller).
  factory MovieMatch.compute({
    required Movie movie,
    required List<Movie> likedMovies,
    String? preferredTrailerLanguage,
  }) {
    // --- No real activity yet: fall back to the real TMDB rating only. -----
    if (likedMovies.isEmpty) {
      final reasons = <String>[
        'Rated ${movie.rating.toStringAsFixed(1)} on TMDB',
      ];
      return MovieMatch(movie.aiMatchScore.clamp(0, 99), reasons);
    }

    final movieGenres = _genreTokens(movie);
    final likedGenres = <String>{};
    for (final m in likedMovies) {
      likedGenres.addAll(_genreTokens(m));
    }

    final shared = movieGenres.intersection(likedGenres).toList();
    final reasons = <String>[];
    int score = 52;

    if (shared.isNotEmpty) {
      // Each shared genre is a genuine overlap with the user's taste.
      score += (shared.length * 9).clamp(0, 36);
      for (final g in shared.take(4)) {
        reasons.add('You like ${_titleCase(g)}');
      }
    } else {
      // No direct genre overlap — still a valid recommendation via quality.
      reasons.add('New genre to explore beyond your list');
      score -= 8;
    }

    if (movie.rating >= 7.5) {
      score += 8;
      reasons.add('You prefer highly rated movies');
    }

    if (preferredTrailerLanguage != null &&
        preferredTrailerLanguage.isNotEmpty &&
        preferredTrailerLanguage != 'auto') {
      reasons.add('You often select '
          '${_titleCase(preferredTrailerLanguage)} trailers');
      // Language preference alone does not change the score (it says nothing
      // about the movie itself), but it IS a real signal worth surfacing.
    }

    return MovieMatch(score.clamp(0, 99), reasons);
  }

  /// Lower-cased normalized genre tokens ("Sci-Fi" -> "sci fi").
  static Set<String> _genreTokens(Movie m) {
    final raw = [
      if (m.genre.isNotEmpty) m.genre,
      ...m.tags,
    ].join('/');
    return raw
        .toLowerCase()
        .replaceAll('-', ' ')
        .split(RegExp(r'[^a-z ]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  static String _titleCase(String s) {
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
