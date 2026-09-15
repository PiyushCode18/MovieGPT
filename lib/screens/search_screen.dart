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
    _debounce?.cancel();
    final trimmed = value.trim();
    final timer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _query = trimmed);
    });
    _debounce = timer;
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final genresAsync = ref.watch(genresProvider);
    final searchAsync = _query.isEmpty
        ? null
        : ref.watch(searchMoviesProvider(_query));

    final selectedLang = ref.watch(languageFilterProvider);
    final hindiAvailable = ref.watch(hindiAvailableFilterProvider);

    // If a filter is active and we're NOT searching, show filtered discovery.
    final bool isDiscoveryMode = _query.isEmpty && (selectedLang != null || hindiAvailable);
    
    final discoveryAsync = isDiscoveryMode 
        ? ref.watch(discoverMoviesProvider(DiscoverFilters(
            withOriginalLanguage: selectedLang,
            watchRegion: 'IN',
            // If "Hindi Available" is checked, we don't have a direct TMDb filter,
            // so we'll treat it as "Original Hindi" for now if no other lang selected,
            // or we could use watch providers if we knew the IDs.
            // For now, let's keep it simple: Hindi filter = withOriginalLanguage: hi.
          )))
        : null;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
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
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
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
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: _clearSearch,
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppTheme.textMuted,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Language Filter Row
            SliverToBoxAdapter(
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
                            color: selectedLang == lang.$1
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: selectedLang == lang.$1
                                  ? AppTheme.primaryRed
                                  : AppTheme.cardBorder,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Hindi Dubbed Toggle
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Hindi Available / Dubbed'),
                      selected: hindiAvailable,
                      onSelected: (selected) {
                        ref.read(hindiAvailableFilterProvider.notifier).state = selected;
                        // If checking this, also ensure region is set to IN (already handled in discovery logic)
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
            ),

            // ===== SEARCH RESULTS MODE =====
            if (searchAsync != null) ...[
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
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (searchAsync.isLoading)
                const SliverToBoxAdapter(
                  child: MovieCardSkeletonGrid(
                    crossAxisCount: 3,
                    childAspectRatio: 0.42,
                  ),
                )
              else if (searchAsync.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(
                    message: 'Search failed',
                    onRetry: () => ref.invalidate(searchMoviesProvider(_query)),
                  ),
                )
              else if (searchAsync.valueOrNull?.isEmpty ?? true)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final movie = searchAsync.valueOrNull![index];
                      return MovieCard(
                        movie: movie,
                        width: double.infinity,
                        showMatch: false,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                MovieDetailsScreen(movieId: movie.id),
                          ),
                        ),
                      );
                    }, childCount: searchAsync.valueOrNull!.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.42,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                  ),
                ),
            ],

            // ===== DISCOVERY MODE (FILTERED) =====
            if (isDiscoveryMode && discoveryAsync != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: SectionHeader(
                    title: selectedLang != null 
                        ? '${_languages.firstWhere((l) => l.$1 == selectedLang).$2} Movies'
                        : 'Discover',
                  ),
                ),
              ),
              if (discoveryAsync.isLoading)
                const SliverToBoxAdapter(
                  child: MovieCardSkeletonGrid(
                    crossAxisCount: 3,
                    childAspectRatio: 0.42,
                  ),
                )
              else if (discoveryAsync.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(
                    message: 'Could not load movies',
                    onRetry: () => ref.invalidate(discoverMoviesProvider),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final movie = discoveryAsync.valueOrNull![index];
                      return MovieCard(
                        movie: movie,
                        width: double.infinity,
                        showMatch: false,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                MovieDetailsScreen(movieId: movie.id),
                          ),
                        ),
                      );
                    }, childCount: discoveryAsync.valueOrNull!.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.42,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                  ),
                ),
            ],

            // ===== DEFAULT MODE: POPULAR GENRES =====
            if (_query.isEmpty && !isDiscoveryMode) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: SectionHeader(title: 'Popular Genres'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (genresAsync.isLoading)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 320,
                    child: MovieCardSkeletonGrid(
                      crossAxisCount: 2,
                      childAspectRatio: 2.2,
                      itemCount: 8,
                    ),
                  ),
                )
              else if (genresAsync.hasError)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: _ErrorState(
                      message: 'Could not load genres',
                      onRetry: () => ref.invalidate(genresProvider),
                    ),
                  ),
                )
              else if (genresAsync.valueOrNull?.isEmpty ?? true)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'No genres available',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final genre = genresAsync.valueOrNull![index];
                      return _GenreTile(
                        genre: genre,
                        onTap: () => _openGenre(context, genre),
                      );
                    }, childCount: genresAsync.valueOrNull!.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                  ),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
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
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.primaryRed, size: 48),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

