import 'package:flutter/material.dart';

import '../models/movie_model.dart';
import '../theme/app_theme.dart';
import 'movie_poster.dart';

/// A premium cinematic movie card with rating and AI match badges.
///
/// Strictly uses [MoviePoster] for TMDB-backed image discovery.
class MovieCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            Text(
              '${movie.genre} • ${movie.year}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
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
