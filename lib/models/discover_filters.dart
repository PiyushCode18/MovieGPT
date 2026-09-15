/// Structured, strongly-typed filters for the TMDb `/discover/movie` endpoint.
///
/// Every field maps 1:1 to a real TMDb discover parameter so the UI/AI
/// can never ask for an invented filter.
class DiscoverFilters {
  final int? genreId; // with_genres (TMDB genre id)
  final String? withOriginalLanguage; // ISO 639-1
  final String? withRegion; // ISO 3166-1 (with_origin_country)
  final double? minRating; // vote_average.gte
  final int? runtimeMax; // with_runtime.lte
  final int? runtimeMin; // with_runtime.gte
  final String? releaseDateGte; // primary_release_date.gte
  final String? releaseDateLte; // primary_release_date.lte
  final String sortBy; // e.g. popularity.desc
  final List<int>? withWatchProviders; // with_watch_providers (TMDb provider ids)
  final String? watchRegion; // watch_region (ISO 3166-1)

  const DiscoverFilters({
    this.genreId,
    this.withOriginalLanguage,
    this.withRegion,
    this.minRating,
    this.runtimeMax,
    this.runtimeMin,
    this.releaseDateGte,
    this.releaseDateLte,
    this.sortBy = 'popularity.desc',
    this.withWatchProviders,
    this.watchRegion,
  });

  /// Converts to the TMDb discover query parameter map.
  Map<String, dynamic> toQueryParams() {
    return {
      if (genreId != null) 'with_genres': genreId,
      if (withOriginalLanguage != null)
        'with_original_language': withOriginalLanguage,
      if (withRegion != null) 'with_origin_country': withRegion,
      if (minRating != null) 'vote_average.gte': minRating,
      if (runtimeMax != null) 'with_runtime.lte': runtimeMax,
      if (runtimeMin != null) 'with_runtime.gte': runtimeMin,
      if (releaseDateGte != null)
        'primary_release_date.gte': releaseDateGte,
      if (releaseDateLte != null)
        'primary_release_date.lte': releaseDateLte,
      if (withWatchProviders != null && withWatchProviders!.isNotEmpty)
        'with_watch_providers': withWatchProviders!.join('|'),
      if (watchRegion != null) 'watch_region': watchRegion,
      'sort_by': sortBy,
    };
  }

  /// A human-readable label for the filters (for AI "why" cards).
  String describe() {
    final String? lang = withOriginalLanguage;
    final String? region = withRegion;
    final double? min = minRating;
    final int? rMax = runtimeMax;
    final int? rMin = runtimeMin;
    final String? gte = releaseDateGte;
    final String? lte = releaseDateLte;

    final parts = <String>[];
    if (genreId != null) parts.add('Genre');
    if (lang != null) parts.add('Language: ${_languageName(lang)}');
    if (region != null) parts.add('Region: ${region.toUpperCase()}');
    if (min != null) parts.add('$min+ rating');
    if (rMax != null) parts.add('Under $rMax min');
    if (rMin != null) parts.add('$rMin+ min');
    if (gte != null) parts.add(gte);
    if (lte != null) parts.add('By $lte');
    parts.add('Sorted by ${sortBy.split('.')[0]}');
    return parts.isNotEmpty ? parts.join(' · ') : 'Any';
  }

  static String _languageName(String code) {
    switch (code.toLowerCase()) {
      case 'en': return 'English';
      case 'hi': return 'Hindi';
      case 'ta': return 'Tamil';
      case 'te': return 'Telugu';
      case 'ml': return 'Malayalam';
      case 'kn': return 'Kannada';
      case 'bn': return 'Bengali';
      case 'mr': return 'Marathi';
      case 'gu': return 'Gujarati';
      case 'pa': return 'Punjabi';
      case 'es': return 'Spanish';
      case 'fr': return 'French';
      case 'de': return 'German';
      case 'ja': return 'Japanese';
      case 'ko': return 'Korean';
      case 'zh': return 'Chinese';
      case 'ar': return 'Arabic';
      case 'pt': return 'Portuguese';
      case 'ru': return 'Russian';
      default: return code.toUpperCase();
    }
  }
}