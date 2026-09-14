import 'package:flutter/material.dart';

import '../models/movie_dna.dart';
import '../theme/app_theme.dart';

/// A premium visual "Movie DNA" bar chart.
///
/// Scores are derived deterministically from REAL movie metadata (TMDB genres,
/// runtime, vote average). Every section is explicitly labeled "MovieGPT
/// Analysis" so it is never mistaken for an official studio rating.
class MovieDnaWidget extends StatelessWidget {
  final MovieDna dna;

  const MovieDnaWidget({super.key, required this.dna});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.glassCardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'MOVIE DNA',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(width: 8),
              SizedBox(
                width: 4,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.neonCyan,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Always visible disclaimer: MovieGPT Analysis, not an official rating.
          const Text(
            'MovieGPT Analysis · derived from real metadata, not an official '
            'studio rating',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final trait in dna.traits) ...[
            _traitRow(trait),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _traitRow(MovieDnaTrait trait) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(trait.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(
              trait.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${trait.score}%',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: trait.score / 100,
            minHeight: 8,
            backgroundColor: AppTheme.cardMid,
            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryViolet),
          ),
        ),
      ],
    );
  }
}