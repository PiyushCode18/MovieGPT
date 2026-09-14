import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie_model.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/skeleton_loaders.dart';
import 'movie_details_screen.dart';

class CollectionScreen extends ConsumerWidget {
  final String title;
  final int? genreId;
  final List<Movie>? movies;

  const CollectionScreen({
    super.key,
    required this.title,
    this.genreId,
    this.movies,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = genreId != null
        ? ref.watch(genreMoviesProvider(genreId!))
        : null;
    final localMovies = movies ?? const <Movie>[];

    Widget body;
    if (moviesAsync != null) {
      body = moviesAsync.when(
        loading: () => const MovieCardSkeletonGrid(
          crossAxisCount: 3,
          childAspectRatio: 0.42,
        ),
        error: (_, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Could not load movies',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(genreMoviesProvider(genreId!)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text(
                'No movies found',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          return _grid(list);
        },
      );
    } else if (localMovies.isEmpty) {
      body = const Center(
        child: Text(
          'No movies available',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    } else {
      body = _grid(localMovies);
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: body,
    );
  }

  Widget _grid(List<Movie> list) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.42,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final movie = list[index];
        return MovieCard(
          movie: movie,
          width: double.infinity,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MovieDetailsScreen(movieId: movie.id),
            ),
          ),
        );
      },
    );
  }
}

