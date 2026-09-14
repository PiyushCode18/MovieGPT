import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'moviegpt_logo.dart';
import 'shimmer_box.dart';

/// A premium, reusable cinematic movie poster widget.
///
/// Enforces a strict 2:3 aspect ratio (standard movie poster) and handles
/// image loading with [CachedNetworkImage], shimmer placeholders, and a
/// branded MovieGPT error fallback.
class MoviePoster extends StatelessWidget {
  /// Relative TMDB poster path (e.g. "/path.jpg").
  final String? posterPath;

  /// Optional width for the poster. Height is automatically derived (width * 1.5).
  final double? width;

  /// Height for the poster. If [width] is also provided, [aspectRatio] takes precedence.
  final double? height;

  /// Border radius for the poster corners.
  final double radius;

  /// How to fit the image inside the container. Always defaults to [BoxFit.cover].
  final BoxFit fit;

  /// TMDB image size (e.g. "w500", "w780", "original").
  final String size;

  /// Optional hero tag for transitions.
  final String? heroTag;

  const MoviePoster({
    super.key,
    this.posterPath,
    this.width,
    this.height,
    this.radius = 16,
    this.fit = BoxFit.cover,
    this.size = 'w500',
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (posterPath == null || posterPath!.isEmpty) {
      content = _buildPlaceholder(context);
    } else {
      final url = 'https://image.tmdb.org/t/p/$size$posterPath';
      content = CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 400),
        placeholder: (context, _) => ShimmerBox(radius: radius),
        errorWidget: (context, _, _) => _buildPlaceholder(context, isError: true),
      );
    }

    // Enforce 2:3 aspect ratio.
    Widget wrapped = AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );

    // Apply fixed width if provided.
    if (width != null) {
      wrapped = SizedBox(width: width, child: wrapped);
    } else if (height != null) {
      wrapped = SizedBox(height: height, child: wrapped);
    }

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: wrapped);
    }

    return wrapped;
  }

  Widget _buildPlaceholder(BuildContext context, {bool isError = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background "M" logo with low opacity for cinematic feel.
          Opacity(
            opacity: 0.15,
            child: MovieGptLogo(size: (width ?? 100) * 0.6),
          ),
          if (isError)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.broken_image_rounded,
                  color: AppTheme.textMuted,
                  size: 24,
                ),
                SizedBox(height: 8),
                Text(
                  'Unavailable',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
