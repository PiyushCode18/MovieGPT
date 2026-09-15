import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie_model.dart';
import '../screens/trailer_screen.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'movie_poster.dart';

/// A premium cinematic movie card with rating and AI match badges.
class MovieCard extends ConsumerWidget {
  final Movie movie;
  final double width;
  final double radius;
  final VoidCallback? onTap;
  final bool showMatch;
  final bool showRating;
  final bool heroEnabled;

  const MovieCard({
    super.key,
    required this.movie,
    this.width = 150,
    this.radius = 16,
    this.onTap,
    this.showMatch = true,
    this.showRating = true,
    this.heroEnabled = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if a primary trailer exists to show the "Watch Trailer" indicator.
    // We use the cached provider to avoid redundant fetches.
    final trailerAsync = ref.watch(primaryTrailerProvider(movie.id));
    final hasTrailer = trailerAsync.valueOrNull != null;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster uses standard 2:3 cinematic ratio.
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  MoviePoster(
                    posterPath: movie.posterPath,
                    radius: radius,
                    heroTag: heroEnabled ? 'poster-${movie.id}' : null,
                  ),
                  if (showRating)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _badge(
                        content: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppTheme.goldAccent,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              movie.rating.toStringAsFixed(1),
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
                  if (showMatch)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.aiGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${movie.aiMatchScore}% Match',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  
                  // "Watch Trailer" overlay button
                  if (hasTrailer)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TrailerScreen(
                                movieId: movie.id,
                                movie: movie,
                                trailer: trailerAsync.value,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${movie.genre} • ${movie.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ),
                if (!hasTrailer && !trailerAsync.isLoading)
                  const Text(
                    'No Trailer',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 9),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge({required Widget content}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: content,
    );
  }
}
