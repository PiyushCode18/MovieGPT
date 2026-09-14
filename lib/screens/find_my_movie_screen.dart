import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/discover_filters.dart';
import '../models/movie_model.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/skeleton_loaders.dart';
import 'movie_details_screen.dart';

/// "Find My Movie" — cinematic guided discovery.
///
/// The user picks mood/genre/language/runtime/rating/era filters; MovieGPT
/// converts them into REAL TMDb `/discover/movie` parameters and returns only
/// real movies from the configured database. No invented titles, ever.
class FindMyMovieScreen extends ConsumerStatefulWidget {
  const FindMyMovieScreen({super.key});

  @override
  ConsumerState<FindMyMovieScreen> createState() => _FindMyMovieScreenState();
}

class _FindMyMovieScreenState extends ConsumerState<FindMyMovieScreen> {
  static const Map<String, int> _genreIds = {
    'Action': 28,
    'Adventure': 12,
    'Comedy': 35,
    'Drama': 18,
    'Horror': 27,
    'Romance': 10749,
    'Sci-Fi': 878,
    'Thriller': 53,
    'Mystery': 9648,
    'Animation': 16,
    'Fantasy': 14,
    'Crime': 80,
  };

  static const Map<String, String> _moodGenres = {
    '😂 Funny': 'Comedy',
    '😭 Emotional': 'Drama',
    '❤️ Romantic': 'Romance',
    '😱 Scary': 'Horror',
    '🔥 Adrenaline': 'Action',
    '🤯 Mind-bending': 'Sci-Fi',
    '🌌 Atmospheric': 'Fantasy',
    '😊 Feel-good': 'Drama',
    '🕵️ Mystery': 'Mystery',
  };

  static const List<String> _languages = [
    'Any', 'en', 'hi', 'ta', 'te', 'ml', 'kn', 'bn', 'mr', 'gu', 'pa',
    'es', 'fr', 'de', 'ja', 'ko', 'zh', 'ar', 'pt', 'ru',
  ];

  static const Map<String, ({int? min, int? max})> _runtimeBuckets = {
    'Under 90 min': (min: null, max: 90),
    '90–120 min': (min: 90, max: 120),
    '120–150 min': (min: 120, max: 150),
    '150+ min': (min: 150, max: null),
  };

  static const List<String> _ratingLabels = ['Any rating', '7+', '8+', '9+'];

  static const Map<String, ({String? gte, String? lte})> _eras = {
    'Latest': (gte: '2025-01-01', lte: null),
    '2020s': (gte: '2020-01-01', lte: '2029-12-31'),
    '2010s': (gte: '2010-01-01', lte: '2019-12-31'),
    '2000s': (gte: '2000-01-01', lte: '2009-12-31'),
    'Classic': (gte: null, lte: '1999-12-31'),
  };

  String? _mood;
  String? _genre;
  String _language = 'Any';
  String? _runtime;
  double? _rating;
  String? _era;

  /// Set once the user taps FIND MY MOVIE; drives the results grid.
  DiscoverFilters? _query;

  /// ISO code -> display name for the language chips.
  static String _languageLabel(String code) => _langNames[code] ?? code;

  static const Map<String, String> _langNames = {
    'en': 'English',
    'hi': 'Hindi',
    'ta': 'Tamil',
    'te': 'Telugu',
    'ml': 'Malayalam',
    'kn': 'Kannada',
    'bn': 'Bengali',
    'mr': 'Marathi',
    'gu': 'Gujarati',
    'pa': 'Punjabi',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese',
    'ar': 'Arabic',
    'pt': 'Portuguese',
    'ru': 'Russian',
  };

  void _find() {
    final genreName = _mood != null ? _moodGenres[_mood] ?? _genre : _genre;
    final era = _era != null ? _eras[_era] : null;
    final rt = _runtime != null ? _runtimeBuckets[_runtime] : null;
    if (genreName == null && _language == 'Any' && era == null && rt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one mood, genre or era.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _query = DiscoverFilters(
        genreId: genreName != null ? _genreIds[genreName] : null,
        withOriginalLanguage: _language == 'Any' ? null : _language,
        minRating: _rating,
        runtimeMax: rt?.max,
        runtimeMin: rt?.min,
        releaseDateGte: era?.gte,
        releaseDateLte: era?.lte,
        sortBy: (_era == 'Classic') ? 'vote_average.desc' : 'popularity.desc',
      );
    });
  }

// __PART_B__

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text(
          'Find My Movie',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _query == null ? _filterPane() : _resultsPane(),
    );
  }

  Widget _filterPane() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        const Text(
          'Tell MovieGPT what you are in the mood for.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        const _SectionLabel('MOOD'),
        _chipWrap(_moodGenres.keys.toList(), _mood,
            (v) => setState(() => _mood = v)),
        const SizedBox(height: 18),
        const _SectionLabel('GENRE'),
        _chipWrap(
            _genreIds.keys.toList(), _genre, (v) => setState(() => _genre = v)),
        const SizedBox(height: 18),
        const _SectionLabel('LANGUAGE'),
        _chipWrap(
          _languages.map(_languageLabel).toList(),
          _language == 'Any' ? 'Any language' : _languageLabel(_language),
          (label) {
            final code = _languages.firstWhere(
              (c) => c == 'Any' || _languageLabel(c) == label,
              orElse: () => 'Any',
            );
            setState(() => _language = code);
          },
        ),
        const SizedBox(height: 18),
        const _SectionLabel('RUNTIME'),
        _chipWrap(_runtimeBuckets.keys.toList(), _runtime,
            (v) => setState(() => _runtime = v)),
        const SizedBox(height: 18),
        const _SectionLabel('RATING'),
        _chipWrap(
          _ratingLabels,
          _rating == null ? 'Any rating' : '${_rating!.toInt()}+',
          (v) => setState(() {
            _rating = v == 'Any rating'
                ? null
                : double.tryParse(v.replaceAll('+', ''));
          }),
        ),
        const SizedBox(height: 18),
        const _SectionLabel('RELEASE PERIOD'),
        _chipWrap(
            _eras.keys.toList(), _era, (v) => setState(() => _era = v)),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _find,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: AppTheme.aiGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.aiPurple.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Text(
              '🎯 FIND MY MOVIE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

// __PART_C__

  Widget _resultsPane() {
    final resultsAsync = ref.watch(discoverMoviesProvider(_query!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _query!.describe(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _query = null),
                icon: const Icon(Icons.tune_rounded,
                    size: 18, color: AppTheme.primaryRed),
                label:
                    const Text('Filters', style: TextStyle(color: AppTheme.primaryRed)),
              ),
            ],
          ),
        ),
        Expanded(
          child: resultsAsync.when(
            loading: () => const MovieCardSkeletonGrid(
              crossAxisCount: 3,
              childAspectRatio: 0.42,
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  "I couldn't find a verified movie matching your request.\n\n"
                  '$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            data: (movies) {
              if (movies.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      "I couldn't find a verified movie matching your request.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.42,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: movies.length,
                itemBuilder: (context, i) => _resultTile(movies[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _resultTile(Movie m) {
    return MovieCard(
      movie: m,
      width: double.infinity,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MovieDetailsScreen(movieId: m.id)),
      ),
    );
  }

  Widget _chipWrap(
    List<String> options,
    String? selected,
    ValueChanged<String> onTap,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSel = o == selected;
        return GestureDetector(
          onTap: () => onTap(o),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: isSel ? AppTheme.primaryGradient : null,
              color: isSel ? null : Colors.white10,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSel ? Colors.transparent : AppTheme.cardBorder,
              ),
            ),
            child: Text(
              o,
              style: TextStyle(
                color: isSel ? Colors.white : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
