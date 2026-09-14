import 'movie_model.dart';

/// A single trait in the visual "Movie DNA" radar.
///
/// Every score is derived deterministically from REAL movie metadata
/// (TMDB genres, runtime, vote average) — never from arbitrary AI numbers.
/// The UI always labels this section **"MovieGPT Analysis"** so it can never
/// be mistaken for an official studio rating.
class MovieDnaTrait {
  final String label;
  final String icon;
  final int score; // 0-100

  const MovieDnaTrait({
    required this.label,
    required this.icon,
    required this.score,
  });

  /// Clamp helper used by the deterministic scoring.
  static int clamp01(num v) => v.round().clamp(0, 100);
}

/// Deterministic "Movie DNA" fingerprint for a movie.
///
/// ## How the scores are computed (fully transparent, no fake stats)
///  1. **Genre affinity** — the movie's TMDB genre/tag string is tokenized and
///     each trait checks for its known genre keywords. A hit raises the score.
///  2. **Rating influence** — a real TMDB vote average of ~9 is worth a small
///     quality bonus (max +8 per trait) because genuinely acclaimed films in a
///     genre are scored a little higher.
///  3. **Runtime influence** — runtime only modulates "Complexity" (longer films
///     are more likely to be narratively dense) and is capped so it never
///     dominates.
///
/// Every trait therefore originates from the movie's verified metadata.
class MovieDna {
  final List<MovieDnaTrait> traits;

  const MovieDna(this.traits);

  /// Build the DNA fingerprint for [movie] using only real metadata.
  factory MovieDna.fromMovie(Movie movie) {
    final tags = _tagsOf(movie);
    final rating = movie.rating; // TMDB vote average (0-10)
    final runtime = movie.runtimeMinutes;
    final quality = (rating * 8 / 10).round(); // max +8

    int emotion = 18;
    int action = 10;
    int comedy = 8;
    int horror = 8;
    int complexity = 14;
    int visuals = 16;
    int romance = 10;

    void bump(String keyword, int amount, void Function(int) setter) {
      if (_has(tags, keyword)) setter(amount);
    }


    // --- Emotion -----------------------------------------------------
    bump('drama', 34, (v) => emotion += v);
    bump('family', 26, (v) => emotion += v);
    bump('romance', 12, (v) => emotion += v);
    bump('war', 12, (v) => emotion += v);
    bump('history', 10, (v) => emotion += v);

    // --- Action ------------------------------------------------------
    bump('action', 46, (v) => action += v);
    bump('adventure', 22, (v) => action += v);
    bump('thriller', 14, (v) => action += v);
    bump('crime', 12, (v) => action += v);
    bump('war', 12, (v) => action += v);

    // --- Comedy ------------------------------------------------------
    bump('comedy', 52, (v) => comedy += v);
    bump('family', 12, (v) => comedy += v);
    bump('fantasy', 6, (v) => comedy += v);

    // --- Horror ------------------------------------------------------
    bump('horror', 58, (v) => horror += v);
    bump('thriller', 20, (v) => horror += v);
    bump('mystery', 10, (v) => horror += v);

    // --- Complexity --------------------------------------------------
    bump('science fiction', 30, (v) => complexity += v);
    bump('sci-fi', 30, (v) => complexity += v);
    bump('mystery', 26, (v) => complexity += v);
    bump('thriller', 16, (v) => complexity += v);
    bump('fantasy', 12, (v) => complexity += v);
    bump('drama', 6, (v) => complexity += v);
    // Longer, denser films score higher on complexity (capped contribution).
    if (runtime >= 130) complexity += 12;
    if (runtime >= 100) complexity += 8;

    // --- Visuals -----------------------------------------------------
    bump('science fiction', 26, (v) => visuals += v);
    bump('sci-fi', 26, (v) => visuals += v);
    bump('fantasy', 26, (v) => visuals += v);
    bump('animation', 32, (v) => visuals += v);
    bump('adventure', 16, (v) => visuals += v);
    bump('action', 10, (v) => visuals += v);

    // --- Romance -----------------------------------------------------
    bump('romance', 52, (v) => romance += v);
    bump('comedy', 10, (v) => romance += v);
    bump('drama', 12, (v) => romance += v);

    // Real TMDB vote-average quality bonus (never dominates; max +8).
    emotion += quality;
    action += quality;
    comedy += quality;
    horror += quality;
    complexity += quality;
    visuals += quality;
    romance += quality;

    return MovieDna([
      MovieDnaTrait(
        label: 'Emotion',
        icon: '❤️',
        score: MovieDnaTrait.clamp01(emotion),
      ),
      MovieDnaTrait(
        label: 'Action',
        icon: '🔥',
        score: MovieDnaTrait.clamp01(action),
      ),
      MovieDnaTrait(
        label: 'Comedy',
        icon: '😂',
        score: MovieDnaTrait.clamp01(comedy),
      ),
      MovieDnaTrait(
        label: 'Horror',
        icon: '😱',
        score: MovieDnaTrait.clamp01(horror),
      ),
      MovieDnaTrait(
        label: 'Complexity',
        icon: '🧠',
        score: MovieDnaTrait.clamp01(complexity),
      ),
      MovieDnaTrait(
        label: 'Visuals',
        icon: '🌌',
        score: MovieDnaTrait.clamp01(visuals),
      ),
      MovieDnaTrait(
        label: 'Romance',
        icon: '💔',
        score: MovieDnaTrait.clamp01(romance),
      ),
    ]);
  }

  /// Returns the trait with [label], or `null` when absent.
  MovieDnaTrait? trait(String label) {
    for (final t in traits) {
      if (t.label == label) return t;
    }
    return null;
  }

  /// Lower-cased, tokenized genre tags. Hyphens are normalized to spaces so
  /// both "Sci-Fi" and "Science Fiction" style tags match their keywords.
  static List<String> _tagsOf(Movie movie) {
    final raw = <String>[
      if (movie.genre.isNotEmpty) movie.genre,
      ...movie.tags,
    ].join('/');
    return raw
        .toLowerCase()
        .replaceAll('-', ' ')
        .split(RegExp(r'[^a-z ]+'))
        .where((t) => t.trim().isNotEmpty)
        .map((t) => t.trim())
        .toList();
  }

  static bool _has(List<String> tags, String keyword) {
    if (tags.isEmpty) return false;
    final normalKeyword = keyword.toLowerCase().replaceAll('-', ' ');
    // Match a full keyword against the normalized token stream.
    final joined = ' ${tags.join(' ')} ';
    return joined.contains(' $normalKeyword ');
  }
}
