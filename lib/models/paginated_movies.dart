import 'movie_model.dart';

/// A single page of results from a pageable TMDB endpoint
/// (e.g. `/discover/movie`, `/search/movie`).
///
/// Carries the pagination metadata TMDB returns in every list response so the
/// UI can implement "load more when scrolling near the end" without guessing:
///  - [movies]      : the movies on this page
///  - [page]        : which TMDB page this response is
///  - [totalPages]  : how many pages exist for this query (never exceeded)
///  - [hasMore]     : convenience flag = `page < totalPages`
class PaginatedMovies {
  final List<Movie> movies;
  final int page;
  final int totalPages;

  const PaginatedMovies({
    this.movies = const [],
    this.page = 1,
    this.totalPages = 1,
  });

  bool get hasMore => page < totalPages && movies.isNotEmpty;
  bool get isEmpty => movies.isEmpty;
}