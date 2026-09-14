import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie_model.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_poster.dart';
import 'movie_details_screen.dart';

/// A curated pool of REAL, well-known TMDb movie ids for the Mystery Movie
/// game. Clues are generated from each movie's REAL metadata at runtime, so
/// the mystery can never describe a fake or AI-invented movie.
const List<int> kMysteryMovieIds = [
  27205, // Inception
  603, // The Matrix
  157336, // Interstellar
  155, // The Dark Knight
  496243, // Parasite
  475557, // Joker
  693134, // Dune: Part Two
  872585, // Oppenheimer
  324857, // Spider-Man: Into the Spider-Verse
  545611, // Everything Everywhere All at Once
  680, // Pulp Fiction
  13, // Forrest Gump
  129, // Spirited Away
  550, // Fight Club
  1124, // The Prestige
];

/// "Mystery Movie" — a fun discovery game using ONLY real movies.
///
/// Progressive clues are derived from the movie's real overview/genres/year.
/// The title is revealed on demand and links to the real details screen where
/// the verified trailer lives. Failures restart the round — never fabricate.
class MysteryMovieScreen extends ConsumerStatefulWidget {
  const MysteryMovieScreen({super.key});

  @override
  ConsumerState<MysteryMovieScreen> createState() =>
      _MysteryMovieScreenState();
}

class _MysteryMovieScreenState extends ConsumerState<MysteryMovieScreen> {
  List<int> _pool = [...kMysteryMovieIds]..shuffle();
  int _poolIndex = 0;
  int? _movieId;
  int _cluesShown = 0;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    if (_poolIndex >= _pool.length) {
      setState(() {
        _pool = [...kMysteryMovieIds]..shuffle();
        _poolIndex = 0;
      });
    }
    setState(() {
      _movieId = _pool[_poolIndex++];
      _cluesShown = 0;
      _revealed = false;
    });
  }

  /// Deterministic clues from REAL metadata (overview -> genres -> facts).
  static List<String> _cluesFor(Movie m) {
    final clues = <String>[];
    final overview = m.overview.trim();
    if (overview.isNotEmpty) {
      final match = RegExp(r'^.{20,}?[.!?]').firstMatch(overview);
      final firstSentence =
          match != null ? overview.substring(0, match.end) : null;
      clues.add(
        firstSentence ??
            overview.substring(0, overview.length.clamp(0, 140)).trim(),
      );
    }
    if (m.genre.isNotEmpty) {
      clues.add('Its genres include: ${m.genre.split('/').take(2).join(' & ')}.');
    }
    final bits = <String>[
      if (m.year.isNotEmpty) 'Released in ${m.year}',
      if (m.duration.isNotEmpty) 'Runs ${m.duration}',
      if (m.rating > 0) 'Holds a ${m.rating.toStringAsFixed(1)} TMDB rating',
    ];
    if (bits.isNotEmpty) clues.add(bits.join(' · '));
    return clues;
  }

  @override
  Widget build(BuildContext context) {
    final movieAsync =
        _movieId == null ? null : ref.watch(movieDetailsProvider(_movieId!));

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text(
          'Guess the Movie',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Another mystery',
            icon: const Icon(Icons.shuffle_rounded, color: Colors.white70),
            onPressed: _next,
          ),
        ],
      ),
      body: movieAsync == null
          ? const SizedBox.shrink()
          : movieAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not load this mystery.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: _next, child: const Text('Try another')),
                  ],
                ),
              ),
              data: _gameBody,
            ),
    );
  }

  Widget _gameBody(Movie movie) {
    final clues = _cluesFor(movie);
    final shown = clues.take(_cluesShown).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        const Center(
          child: Text(
            '🎬 GUESS THE MOVIE',
            style: TextStyle(
              color: AppTheme.goldAccent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < shown.length; i++) ...[
          _clueCard(i + 1, shown[i]),
          const SizedBox(height: 16),
        ],
        if (!_revealed) ..._guessActions(clues.length) else ..._reveal(movie),
      ],
    );
  }

  List<Widget> _guessActions(int totalClues) {
    return [
      if (_cluesShown < totalClues)
        _bigButton(
          label: 'NEXT CLUE',
          icon: Icons.help_outline_rounded,
          gradient: AppTheme.aiGradient,
          onTap: () => setState(() => _cluesShown += 1),
        ),
      const SizedBox(height: 12),
      _bigButton(
        label: 'GUESS',
        icon: Icons.emoji_events_rounded,
        gradient: AppTheme.primaryGradient,
        onTap: () => setState(() => _revealed = true),
      ),
    ];
  }

  List<Widget> _reveal(Movie movie) {
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.glassCardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            Center(
              child:
                  SizedBox(width: 140, child: MoviePoster(posterPath: movie.posterPath)),
            ),
            const SizedBox(height: 14),
            Text(
              '🎉 ${movie.title}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                movie.genre,
                movie.year,
                if (movie.rating > 0) '★ ${movie.rating.toStringAsFixed(1)}',
              ].where((s) => s.isNotEmpty).join(' • '),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MovieDetailsScreen(movieId: movie.id),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_circle_fill_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Watch Trailer',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _bigButton(
        label: 'ANOTHER MYSTERY',
        icon: Icons.shuffle_rounded,
        gradient: AppTheme.aiGradient,
        onTap: _next,
      ),
    ];
  }

  Widget _clueCard(int number, String clue) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.glassCardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLUE #$number',
            style: const TextStyle(
              color: AppTheme.neonCyan,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            clue,
            style:
                const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _bigButton({
    required String label,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
