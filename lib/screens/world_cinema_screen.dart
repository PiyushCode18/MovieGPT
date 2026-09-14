import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/skeleton_loaders.dart';
import 'movie_details_screen.dart';

/// One real-world cinema region surfaced by "Explore World Cinema".
class CinemaRegion {
  final String flag;
  final String name;
  final String countryCode; // ISO 3166-1 alpha-2 (with_origin_country)

  const CinemaRegion(this.flag, this.name, this.countryCode);
}

/// "Explore World Cinema" — real movies by country of origin.
///
/// Every tile opens a TMDb `/discover/movie` query filtered by
/// `with_origin_country`, so ONLY real movies from that country's cinema are
/// ever shown.
class WorldCinemaScreen extends ConsumerStatefulWidget {
  const WorldCinemaScreen({super.key});

  static const List<CinemaRegion> regions = [
    CinemaRegion('🇮🇳', 'India', 'IN'),
    CinemaRegion('🇺🇸', 'USA', 'US'),
    CinemaRegion('🇬🇧', 'UK', 'GB'),
    CinemaRegion('🇯🇵', 'Japan', 'JP'),
    CinemaRegion('🇰🇷', 'South Korea', 'KR'),
    CinemaRegion('🇫🇷', 'France', 'FR'),
    CinemaRegion('🇮🇹', 'Italy', 'IT'),
    CinemaRegion('🇪🇸', 'Spain', 'ES'),
    CinemaRegion('🇲🇽', 'Mexico', 'MX'),
  ];

  @override
  ConsumerState<WorldCinemaScreen> createState() => _WorldCinemaScreenState();
}

class _WorldCinemaScreenState extends ConsumerState<WorldCinemaScreen> {
  CinemaRegion? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text(
          'Explore World Cinema',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _selected == null ? _regionGrid() : _resultsPane(),
    );
  }

  Widget _regionGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.95,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: WorldCinemaScreen.regions.length,
      itemBuilder: (context, i) {
        final r = WorldCinemaScreen.regions[i];
        return GestureDetector(
          onTap: () => setState(() => _selected = r),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.glassCardGradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(r.flag, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    r.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// __RESULTS__

  Widget _resultsPane() {
    final region = _selected!;
    final moviesAsync = ref.watch(worldCinemaProvider(region.countryCode));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Text(region.flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                '${region.name} Movies',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.public_rounded,
                    size: 18, color: AppTheme.primaryRed),
                label: const Text('Regions',
                    style: TextStyle(color: AppTheme.primaryRed)),
              ),
            ],
          ),
        ),
        Expanded(
          child: moviesAsync.when(
            loading: () => const MovieCardSkeletonGrid(
              crossAxisCount: 3,
              childAspectRatio: 0.42,
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Could not load ${region.name} movies.\n\n$e',
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
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No ${region.name} movies available right now.',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.42,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: movies.length,
                itemBuilder: (context, i) => MovieCard(
                  movie: movies[i],
                  width: double.infinity,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MovieDetailsScreen(movieId: movies[i].id),
                    ),
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
