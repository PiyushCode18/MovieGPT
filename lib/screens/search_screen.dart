import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie_model.dart';
import '../models/discover_filters.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton_loaders.dart';
import 'collection_screen.dart';
import 'movie_details_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;
  bool _isDebouncing = false;

  static const _languages = [
    (null, 'All'),
    ('hi', 'Hindi'),
    ('en', 'English'),
    ('ta', 'Tamil'),
    ('te', 'Telugu'),
    ('ml', 'Malayalam'),
    ('kn', 'Kannada'),
    ('bn', 'Bengali'),
    ('mr', 'Marathi'),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Debounce search input so network calls only fire after the user pauses,
  /// and cancel any in-flight debounce when the widget is disposed.
  void _onQueryChanged(String value) {
    final trimmed = value.trim();
    if (trimmed == _query) {
      if (_isDebouncing) {
        _debounce?.cancel();
        setState(() => _isDebouncing = false);
      }
      return;
    }

    _debounce?.cancel();
    if (!_isDebouncing) {
      setState(() => _isDebouncing = true);
    }
    
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = trimmed;
        _isDebouncing = false;
      });
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final genresAsync = ref.watch(genresProvider);
    final searchAsync = _query.isEmpty ? null : ref.watch(searchMoviesProvider(_query));

    final selectedLang = ref.watch(languageFilterProvider);
    final hindiAvailable = ref.watch(hindiAvailableFilterProvider);

    // If a filter is active and we're NOT searching, show filtered discovery.
    final bool isDiscoveryMode = _query.isEmpty && (selectedLang != null || hindiAvailable);

    final discoveryAsync = isDiscoveryMode
        ? ref.watch(discoverMoviesProvider(DiscoverFilters(
            withOriginalLanguage: selectedLang,
            watchRegion: 'IN',
          )))
        : null;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildHeader(),
            _buildSearchInput(),
            _buildLanguageFilters(selectedLang),
            _buildHindiToggle(hindiAvailable),
            
            // Results section
            if (searchAsync != null)
              ..._buildSearchResults(searchAsync)
            else if (isDiscoveryMode && discoveryAsync != null)
              ..._buildDiscoveryResults(discoveryAsync, selectedLang)
            else
              ..._buildDefaultGenres(genresAsync),
            
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Search',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: AppTheme.glassCardGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  onChanged: _onQueryChanged,
                  onSubmitted: (value) {
                    _debounce?.cancel();
                    setState(() => _query = value.trim());
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search movies...',
                    hintStyle: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ),
              if (_query.isNotEmpty || _isDebouncing)
                GestureDetector(
                  onTap: _clearSearch,
                  child: _isDebouncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryRed,
                          ),
                        )
                      : const Icon(
                          Icons.close_rounded,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageFilters(String? selectedLang) {
    return SliverToBoxAdapter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            for (final lang in _languages)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(lang.$2),
                  selected: selectedLang == lang.$1,
                  onSelected: (selected) {
                    ref.read(languageFilterProvider.notifier).state =
                        selected ? lang.$1 : null;
                  },
                  backgroundColor: AppTheme.cardDark,
                  selectedColor: AppTheme.primaryRed,
                  labelStyle: TextStyle(
                    color: selectedLang == lang.$1 ? Colors.white : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selectedLang == lang.$1 ? AppTheme.primaryRed : AppTheme.cardBorder,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHindiToggle(bool hindiAvailable) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            FilterChip(
              label: const Text('Hindi Available / Dubbed'),
              selected: hindiAvailable,
              onSelected: (selected) {
                ref.read(hindiAvailableFilterProvider.notifier).state = selected;
              },
              backgroundColor: AppTheme.cardDark,
              selectedColor: AppTheme.aiPurple.withValues(alpha: 0.3),
              checkmarkColor: AppTheme.aiPurple,
              labelStyle: TextStyle(
                color: hindiAvailable ? Colors.white : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: hindiAvailable ? AppTheme.aiPurple : AppTheme.cardBorder,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSearchResults(AsyncValue<List<Movie>> searchAsync) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SectionHeader(
            title: 'Results for "$_query"',
            actionLabel: 'Clear',
            onAction: _clearSearch,
          ),
        ),
      ),
      searchAsync.when(
        loading: () => const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          sliver: SliverMovieCardSkeletonGrid(itemCount: 9),
        ),
        error: (error, _) => SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(
            message: 'Search failed',
            error: error,
            onRetry: () => ref.invalidate(searchMoviesProvider(_query)),
          ),
        ),
        data: (movies) {
          if (movies.isEmpty) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No results found',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  try {
                    final movie = movies[index];
                    return MovieCard(
                      movie: movie,
                      width: double.infinity,
                      showMatch: false,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MovieDetailsScreen(movieId: movie.id),
                        ),
                      ),
                    );
                  } catch (e) {
                    return const SizedBox.shrink();
                  }
                },
                childCount: movies.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.42,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _buildDiscoveryResults(AsyncValue<List<Movie>> discoveryAsync, String? selectedLang) {
    final title = selectedLang != null
        ? '${_languages.firstWhere((l) => l.$1 == selectedLang).$2} Movies'
        : 'Discover';

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SectionHeader(title: title),
        ),
      ),
      discoveryAsync.when(
        loading: () => const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          sliver: SliverMovieCardSkeletonGrid(itemCount: 9),
        ),
        error: (error, _) => SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(
            message: 'Could not load movies',
            error: error,
            onRetry: () => ref.invalidate(discoverMoviesProvider),
          ),
        ),
        data: (movies) {
          if (movies.isEmpty) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No movies found',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  try {
                    final movie = movies[index];
                    return MovieCard(
                      movie: movie,
                      width: double.infinity,
                      showMatch: false,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MovieDetailsScreen(movieId: movie.id),
                        ),
                      ),
                    );
                  } catch (e) {
                    return const SizedBox.shrink();
                  }
                },
                childCount: movies.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.42,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _buildDefaultGenres(AsyncValue<List<Genre>> genresAsync) {
    return [
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SectionHeader(title: 'Popular Genres'),
        ),
      ),
      genresAsync.when(
        loading: () => const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          sliver: SliverGenreSkeletonGrid(),
        ),
        error: (error, _) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: _ErrorState(
              message: 'Could not load genres',
              error: error,
              onRetry: () => ref.invalidate(genresProvider),
            ),
          ),
        ),
        data: (genres) {
          if (genres.isEmpty) {
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No genres available',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final genre = genres[index];
                  return _GenreTile(
                    genre: genre,
                    onTap: () => _openGenre(context, genre),
                  );
                },
                childCount: genres.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
            ),
          );
        },
      ),
    ];
  }

  void _openGenre(BuildContext context, Genre genre) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectionScreen(genreId: genre.id, title: genre.name),
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  final Genre genre;
  final VoidCallback onTap;

  const _GenreTile({required this.genre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          genre.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final dynamic error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    String detail = '';
    if (error != null) {
      detail = error.toString();
      // Remove common technical prefixes for cleaner UI
      detail = detail.replaceAll('Exception: ', '');
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.primaryRed, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

