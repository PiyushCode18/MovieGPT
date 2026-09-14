import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie_model.dart';
import '../state/providers.dart';
import '../data/movie_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton_loaders.dart';
import 'collection_screen.dart';
import 'movie_details_screen.dart';
import 'paged_collection_screen.dart';
import 'find_my_movie_screen.dart';
import 'mystery_movie_screen.dart';
import 'search_screen.dart';
import 'world_cinema_screen.dart';
import 'trailer_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const double rowHeight = 302;

  @override
  Widget build(BuildContext context) {
    final featuredAsync = ref.watch(featuredMovieProvider);
    final trendingAsync = ref.watch(trendingMoviesProvider);
    final recommendedAsync = ref.watch(recommendedMoviesProvider);
    final forYouAsync = ref.watch(forYouMoviesProvider);
    final popularAsync = ref.watch(popularMoviesProvider);
    final thisYearAsync = ref.watch(currentYearMoviesProvider);
    final topRatedAsync = ref.watch(topRatedMoviesProvider);
    final upcomingAsync = ref.watch(upcomingRangeMoviesProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryRed,
          backgroundColor: AppTheme.cardDark,
          onRefresh: () async {
            ref.invalidate(featuredMovieProvider);
            ref.invalidate(trendingMoviesProvider);
            ref.invalidate(recommendedMoviesProvider);
            ref.invalidate(forYouMoviesProvider);
            ref.invalidate(popularMoviesProvider);
            ref.invalidate(topRatedMoviesProvider);
            ref.invalidate(currentYearMoviesProvider);
            ref.invalidate(upcomingRangeMoviesProvider);
            ref.invalidate(genresProvider);
            // Also clear the in-memory paged cache so pull-to-refresh surfaces
            // updated upcoming/this-year data instead of a TTL cache hit.
            MovieRepository.instance.clearCache();
            // Wait for the providers to settle.
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _header(context),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              _searchBar(context),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              const SliverToBoxAdapter(child: _DiscoveryActions()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              _genreChips(),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Featured hero (isolated in a RepaintBoundary so its image
              // fade-in / shimmer repaints don't propagate to sibling rows).
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: featuredAsync.when(
                    loading: () => HeroSkeleton(height: _heroHeight(context)),
                    error: (_, _) => _HeroError(
                      onRetry: () => ref.invalidate(featuredMovieProvider),
                    ),
                    data: (movie) => _HeroCard(movie: movie),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              _pagedSectionHeader(
                context,
                'Trending Today',
                trendingAsync.valueOrNull ?? const [],
                (page) =>
                    ref.read(movieRepositoryProvider).getTrendingPaged(page: page),
              ),
              _movieRow(
                trendingAsync,
                emptyMessage: 'No trending movies',
                retry: () => ref.invalidate(trendingMoviesProvider),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              _sectionHeader(
                context,
                'Recommended For You',
                'See All',
                recommendedAsync.valueOrNull ?? const [],
              ),
              _movieRow(
                recommendedAsync,
                emptyMessage: 'No recommendations',
                retry: () => ref.invalidate(recommendedMoviesProvider),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              _sectionHeader(
                context,
                'AI Top Picks for You',
                'See All',
                forYouAsync.valueOrNull ?? const [],
              ),
              _movieRow(
                forYouAsync,
                emptyMessage: 'No picks available',
                retry: () => ref.invalidate(forYouMoviesProvider),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              _pagedSectionHeader(
                context,
                'Popular',
                popularAsync.valueOrNull ?? const [],
                (page) =>
                    ref.read(movieRepositoryProvider).getPopularPaged(page: page),
              ),
              _movieRow(
                popularAsync,
                emptyMessage: 'No popular movies',
                retry: () => ref.invalidate(popularMoviesProvider),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              _pagedSectionHeader(
                context,
                'Top Rated',
                topRatedAsync.valueOrNull ?? const [],
                (page) =>
                    ref.read(movieRepositoryProvider).getTopRatedPaged(page: page),
              ),
              _movieRow(
                topRatedAsync,
                emptyMessage: 'No top rated movies',
                retry: () => ref.invalidate(topRatedMoviesProvider),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              _pagedSectionHeader(
                context,
                '${DateTime.now().year} Releases',
                thisYearAsync.valueOrNull ?? const [],
                (page) => ref
                    .read(movieRepositoryProvider)
                    .getCurrentYearMovies(DateTime.now().year, page: page),
              ),
              _movieRow(
                thisYearAsync,
                emptyMessage: 'No releases this year',
                retry: () => ref.invalidate(currentYearMoviesProvider),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              _pagedSectionHeader(
                context,
                'Upcoming',
                upcomingAsync.valueOrNull ?? const [],
                (page) {
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, now.day);
                  final end = DateTime(now.year, now.month + 15, now.day);
                  return ref
                      .read(movieRepositoryProvider)
                      .getUpcomingRange(start: start, end: end, page: page);
                },
              ),
              _movieRow(
                upcomingAsync,
                emptyMessage: 'No upcoming movies',
                retry: () => ref.invalidate(upcomingRangeMoviesProvider),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  double _heroHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return (width * 0.95).clamp(320.0, 420.0).toDouble();
  }

  SliverToBoxAdapter _header(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.movie_filter_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: const Text(
                    'MovieGPT',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () {},
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryRed,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _searchBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Good Evening 👋',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'What are you in the mood to watch today?',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
              },
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: AppTheme.glassCardGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.smart_toy_rounded, color: AppTheme.primaryRed),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ask MovieGPT...',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Icon(Icons.mic_none_rounded, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _genreChips() {
    final genresAsync = ref.watch(genresProvider);
    return SliverToBoxAdapter(
      child: genresAsync.when(
        loading: () => const SizedBox(
          height: 52,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryRed,
            ),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (genres) {
          // Combine a few curated highlights with the full dynamic TMDB list.
          final chips = <String>['All', ...genres.take(8).map((g) => g.name)];
          return SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _GenreChip(label: chips[index]);
              },
            ),
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _sectionHeader(
    BuildContext context,
    String title,
    String action,
    List<Movie> movies,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SectionHeader(
          title: title,
          actionLabel: action,
          onAction: () => _openCollection(context, title, movies),
        ),
      ),
    );
  }

  SliverToBoxAdapter _movieRow(
    AsyncValue<List<Movie>> asyncValue, {
    required String emptyMessage,
    required VoidCallback retry,
  }) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: rowHeight,
        child: asyncValue.when(
          loading: () => const MovieRowSkeleton(),
          // Errors get a dedicated, honest error state with retry — they are
          // never disguised as an empty result ("No ... movies").
          error: (_, _) => _SectionError(onRetry: retry),
          data: (movies) {
            if (movies.isEmpty) {
              return _EmptySection(emptyMessage);
            }
            return _movieList(movies);
          },
        ),
      ),
    );
  }

  Widget _movieList(List<Movie> movies) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      scrollDirection: Axis.horizontal,
      itemCount: movies.length,
      separatorBuilder: (_, _) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MovieCard(
          movie: movie,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MovieDetailsScreen(movieId: movie.id),
            ),
          ),
        );
      },
    );
  }

  void _openCollection(BuildContext context, String title, List<Movie> movies) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectionScreen(title: title, movies: movies),
      ),
    );
  }

  /// Header for a row whose "See All" opens the paginated grid screen.
  SliverToBoxAdapter _pagedSectionHeader(
    BuildContext context,
    String title,
    List<Movie> movies,
    PaginatedPageLoader loader,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SectionHeader(
          title: title,
          actionLabel: 'See All',
          onAction: () => _openPagedCollection(context, title, loader),
        ),
      ),
    );
  }

  void _openPagedCollection(
    BuildContext context,
    String title,
    PaginatedPageLoader loader,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PagedCollectionScreen(title: title, loader: loader),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Movie movie;
  const _HeroCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Compute a single stable height (no conflicting constraints).
    final heroHeight = (width * 0.95).clamp(320.0, 420.0).toDouble();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MovieDetailsScreen(movieId: movie.id),
        ),
      ),
      child: Container(
        height: heroHeight,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryRed.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _HeroImage(movie: movie),
              Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.heroOverlayGradient,
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${movie.aiMatchScore}% Match',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (movie.genre.isNotEmpty) movie.genre,
                        if (movie.year.isNotEmpty) movie.year,
                        if (movie.duration.isNotEmpty) movie.duration,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TrailerScreen(
                                  movieId: movie.id,
                                  movie: movie,
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  SizedBox(width: 6),
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
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final Movie movie;
  const _HeroImage({required this.movie});

  @override
  Widget build(BuildContext context) {
    final url = movie.backdropUrl('w780') ?? movie.posterUrl('w500');
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 400),
        placeholder: (_, _) => Container(color: AppTheme.cardDark),
        errorWidget: (_, _, _) => Container(
          color: AppTheme.cardDark,
          child: const Icon(Icons.movie, color: Colors.white54),
        ),
      );
    }
    return Container(
      color: AppTheme.cardDark,
      child: const Icon(Icons.movie, color: Colors.white54),
    );
  }
}

/// Quick discovery actions row: Find My Movie · World Cinema · Mystery Movie.
///
/// Each card opens a real-data discovery surface — no fake content anywhere.
class _DiscoveryActions extends StatelessWidget {
  const _DiscoveryActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _DiscoveryCard(
              icon: Icons.travel_explore_rounded,
              title: 'Find My Movie',
              subtitle: 'Mood + filters',
              gradient: AppTheme.primaryGradient,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FindMyMovieScreen()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DiscoveryCard(
              icon: Icons.public_rounded,
              title: 'World Cinema',
              subtitle: 'Movies by country',
              gradient: AppTheme.aiGradient,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WorldCinemaScreen()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DiscoveryCard(
              icon: Icons.casino_rounded,
              title: 'Mystery Movie',
              subtitle: 'Guess from clues',
              gradient: const LinearGradient(
                colors: [AppTheme.goldAccent, AppTheme.primaryRed],
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MysteryMovieScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _DiscoveryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  const _GenreChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppTheme.glassCardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection(this.message);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 302,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// A retryable error placeholder for a movie row.
///
/// Data-loading failures are NEVER disguised as an empty result: a TMDB
/// outage / configuration problem shows this honest error state with a Retry
/// action, while genuinely empty results keep using [_EmptySection].
class _SectionError extends StatelessWidget {
  final VoidCallback onRetry;
  const _SectionError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 302,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppTheme.textMuted,
              size: 32,
            ),
            const SizedBox(height: 8),
            const Text(
              'Could not load movies.\n'
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryRed,
                side: const BorderSide(color: AppTheme.primaryRed),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A retryable error placeholder for the featured hero.
class _HeroError extends StatelessWidget {
  final VoidCallback onRetry;
  const _HeroError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final heroHeight = (width * 0.95).clamp(320.0, 420.0).toDouble();
    return Container(
      height: heroHeight,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: AppTheme.glassCardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppTheme.textMuted,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could not load featured movie',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

