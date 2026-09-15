import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie_dna.dart';
import '../models/movie_match.dart';
import '../models/movie_model.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_dna_widget.dart';
import '../widgets/movie_match_card.dart';
import '../widgets/skeleton_loaders.dart';
import '../widgets/trailer_language_section.dart';

class MovieDetailsScreen extends ConsumerWidget {
  final int movieId;

  const MovieDetailsScreen({super.key, required this.movieId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(movieDetailsBundleProvider(movieId));

    return bundleAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: DetailsSkeleton(),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppTheme.primaryRed,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Could not load movie details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(movieDetailsBundleProvider(movieId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (bundle) {
        final movie = bundle.movie;
        final cast = bundle.cast;
        final similar = bundle.similar;
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 380,
                pinned: true,
                backgroundColor: AppTheme.bgDark,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _HeroBackdrop(movie: movie),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: AppTheme.heroOverlayGradient,
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${movie.aiMatchScore}% AI Match',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              movie.title,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (movie.tagline.isNotEmpty)
                              Text(
                                movie.tagline,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metaRow(movie),
                      const SizedBox(height: 10),
                      _hindiBadge(movie),
                      const SizedBox(height: 20),
                      TrailerLanguageSection(movie: movie),
                      const SizedBox(height: 12),
                      _collectionActions(context, ref, movie),
                      const SizedBox(height: 24),
                      _aiReasonCard(movie),
                      const SizedBox(height: 24),
                      MovieDnaWidget(dna: MovieDna.fromMovie(movie)),
                      const SizedBox(height: 24),
                      MovieMatchCard(
                        match: MovieMatch.compute(
                          movie: movie,
                          likedMovies: [
                            ...ref.watch(favoritesProvider),
                            ...ref.watch(watchlistProvider),
                          ],
                          preferredTrailerLanguage:
                              ref.watch(trailerLanguagePreferenceProvider),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (movie.director.isNotEmpty ||
                          movie.production.isNotEmpty ||
                          movie.status.isNotEmpty) ...[
                        _infoCard(movie),
                        const SizedBox(height: 24),
                      ],
                      _synopsis(movie),
                      const SizedBox(height: 28),
                      _castSection(cast),
                      const SizedBox(height: 28),
                      _similarSection(context, similar),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _hindiBadge(Movie movie) {
    final bool isOriginalHindi = movie.originalLanguage == 'hi';
    final bool hasHindiAudio = movie.spokenLanguages.contains('hi');

    if (!isOriginalHindi && !hasHindiAudio) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.aiPurple.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.aiPurple.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.translate_rounded, color: AppTheme.aiPurple, size: 14),
          const SizedBox(width: 6),
          Text(
            isOriginalHindi ? 'Original Hindi' : 'Hindi Audio Available',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static String _errorMessage(Object error) {
    final message = error.toString();
    // Strip the "Exception: " / "TmdbApiException: " prefix for readability.
    if (message.contains(':')) {
      final idx = message.indexOf(':');
      final rest = message.substring(idx + 1).trim();
      if (rest.isNotEmpty) return rest;
    }
    return message;
  }

  static Widget _metaRow(Movie movie) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              color: AppTheme.goldAccent,
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              movie.rating.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        Text(
          movie.year.isNotEmpty ? movie.year : 'N/A',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.textMuted),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            movie.maturityRating,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ),
        if (movie.duration.isNotEmpty)
          Text(
            movie.duration,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
      ],
    );
  }

  /// Favorites + Watchlist actions row.
  ///
  /// The trailer action lives in [TrailerLanguageSection] above this row so
  /// language selection and playback stay together.
  static Widget _collectionActions(
    BuildContext context,
    WidgetRef ref,
    Movie movie,
  ) {
    return Row(
      children: [
        Expanded(
          child: _collectionToggle(
            context,
            ref,
            movie,
            isFavorite: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _collectionToggle(
            context,
            ref,
            movie,
            isFavorite: false,
          ),
        ),
      ],
    );
  }

  /// A single favorites/watchlist toggle button.
  static Widget _collectionToggle(
    BuildContext context,
    WidgetRef ref,
    Movie movie, {
    required bool isFavorite,
  }) {
    final bool active;
    final IconData iconOn;
    final IconData iconOff;
    final String labelOn;
    final String labelOff;

    if (isFavorite) {
      active = ref.watch(
        favoritesProvider.select((list) => list.any((m) => m.id == movie.id)),
      );
      iconOn = Icons.favorite_rounded;
      iconOff = Icons.favorite_border_rounded;
      labelOn = 'Favorited';
      labelOff = 'Favorite';
    } else {
      active = ref.watch(
        watchlistProvider.select((list) => list.any((m) => m.id == movie.id)),
      );
      iconOn = Icons.bookmark_rounded;
      iconOff = Icons.bookmark_add_outlined;
      labelOn = 'Saved';
      labelOff = 'Watchlist';
    }

    void toggle() {
      if (isFavorite) {
        ref.read(favoritesProvider.notifier).toggle(movie);
      } else {
        ref.read(watchlistProvider.notifier).toggle(movie);
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(active ? 'Removed' : 'Added'),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    return GestureDetector(
      onTap: toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: active ? AppTheme.glassCardGradient : null,
          color: active ? null : Colors.white12,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppTheme.goldAccent : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? iconOn : iconOff,
              color: active ? AppTheme.goldAccent : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                active ? labelOn : labelOff,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _aiReasonCard(Movie movie) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.psychology_rounded,
                color: AppTheme.neonCyan,
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'WHY MOVIEGPT RECOMMENDS THIS',
                  style: TextStyle(
                    color: AppTheme.neonCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            movie.aiReasoning,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _infoCard(Movie movie) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.glassCardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (movie.director.isNotEmpty)
            _infoRow(Icons.person_outline_rounded, 'Director', movie.director),
          if (movie.production.isNotEmpty)
            _infoRow(Icons.apartment_rounded, 'Studio', movie.production),
          if (movie.status.isNotEmpty)
            _infoRow(Icons.movie_creation_outlined, 'Status', movie.status),
        ],
      ),
    );
  }

  static Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 18),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _synopsis(Movie movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Synopsis',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          movie.overview.isEmpty ? 'No synopsis available.' : movie.overview,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  static Widget _castSection(List<CastMember> cast) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Cast & Crew',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        if (cast.isEmpty)
          const SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'No cast information available',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cast.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final member = cast[index];
                return _CastCard(member: member);
              },
            ),
          ),
      ],
    );
  }

  static Widget _similarSection(BuildContext context, List<Movie> similar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Similar Movies',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        if (similar.isEmpty)
          const SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'No similar movies found',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: similar.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final m = similar[index];
                return MovieCard(
                  movie: m,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MovieDetailsScreen(movieId: m.id),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _HeroBackdrop extends StatelessWidget {
  final Movie movie;
  const _HeroBackdrop({required this.movie});

  @override
  Widget build(BuildContext context) {
    final url =
        movie.posterUrlOriginal ??
        movie.backdropUrl('w1280') ??
        movie.posterUrl('w500');
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 400),
        placeholder: (_, _) => Container(
          color: AppTheme.cardDark,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(color: AppTheme.bgDark);
  }
}

class _CastCard extends StatelessWidget {
  final CastMember member;
  const _CastCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: member.profilePath != null
                ? CachedNetworkImage(
                    imageUrl: member.profileUrl()!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => _avatarFallback(),
                    errorWidget: (_, _, _) => _avatarFallback(),
                  )
                : _avatarFallback(),
          ),
          const SizedBox(height: 8),
          Text(
            member.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            member.character,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 72,
      height: 72,
      color: AppTheme.cardDark,
      child: const Icon(Icons.person, color: Colors.white38),
    );
  }
}

