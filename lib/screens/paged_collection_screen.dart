import 'package:flutter/material.dart';

import '../models/movie_model.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/skeleton_loaders.dart';
import 'movie_details_screen.dart';

/// A vertically scrolling grid that loads TMDB pages lazily.
///
/// Loads page 1 on open, then appends page N+1 when the user scrolls near the
/// bottom. It stops once TMDB's `total_pages` is reached (never over-fetches),
/// de-duplicates titles across page boundaries, and supports pull-to-refresh
/// back to page 1. Pagination state is kept locally and self-contained.
class PagedCollectionScreen extends StatefulWidget {
  final String title;
  final PaginatedPageLoader loader;

  const PagedCollectionScreen({
    super.key,
    required this.title,
    required this.loader,
  });

  @override
  State<PagedCollectionScreen> createState() => _PagedCollectionScreenState();
}

class _PagedCollectionScreenState extends State<PagedCollectionScreen> {
  static const double _threshold = 400;

  List<Movie> _movies = const [];
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasError = false;

  bool get _hasMore => _currentPage < _totalPages || _totalPages == 0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (mounted) {
      setState(() {
        _isLoadingInitial = true;
        _hasError = false;
      });
    }
    try {
      final result = await widget.loader(1);
      if (!mounted) return;
      setState(() {
        _movies = List.of(result.movies);
        _currentPage = result.page;
        _totalPages = result.totalPages;
        _isLoadingInitial = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingInitial = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoadingInitial || !_hasMore) return;
    final next = _currentPage + 1;
    if (_totalPages > 0 && next > _totalPages) return;

    setState(() => _isLoadingMore = true);
    try {
      final result = await widget.loader(next);
      if (!mounted) return;
      final seen = <int>{}..addAll(_movies.map((m) => m.id));
      final merged = List<Movie>.of(_movies);
      for (final m in result.movies) {
        if (seen.add(m.id)) merged.add(m);
      }
      setState(() {
        _movies = merged;
        _currentPage = result.page;
        _totalPages = result.totalPages;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _hasError = true;
      });
    }
  }

  /// Fires when the grid scrolls near the end -> load the next page.
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - _threshold) {
      _loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryRed,
        backgroundColor: AppTheme.cardDark,
        onRefresh: _loadInitial,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitial) {
      return const MovieCardSkeletonGrid(
        crossAxisCount: 3,
        childAspectRatio: 0.42,
      );
    }

    if (_movies.isEmpty) {
      if (_hasError) {
        return _ErrorState(onRetry: _loadInitial);
      }
      return const Center(
        child: Text(
          'No movies found',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.42,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _movies.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _movies.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryRed,
                  ),
                ),
              ),
            );
          }
          final movie = _movies[index];
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
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppTheme.textMuted,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load movies',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}