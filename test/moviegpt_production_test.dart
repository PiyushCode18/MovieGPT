import 'package:flutter_test/flutter_test.dart';
import 'package:moviegpt_app/models/discover_filters.dart';
import 'package:moviegpt_app/models/movie_dna.dart';
import 'package:moviegpt_app/models/movie_match.dart';
import 'package:moviegpt_app/models/movie_model.dart';
import 'package:moviegpt_app/services/trailer_service.dart';

/// Pure, network-free tests for the multilingual trailer system,
/// structured AI discovery, Movie DNA, and Movie Match engines.
void main() {
  group('TEST 1-3 · verified trailer languages', () {
    Trailer t({
      String id = 'v',
      required String key,
      String name = '',
      String site = 'YouTube',
      String type = 'Trailer',
      String lang = 'en',
      bool official = true,
    }) =>
        Trailer(
          id: id,
          key: key,
          name: name,
          site: site,
          type: type,
          lang: lang,
          official: official,
        );

    final enOfficial = t(key: 'en-key', name: 'Official Trailer', lang: 'en');
    final hiDubbed = t(
      key: 'hi-key',
      name: 'Hindi Dubbed Trailer',
      lang: 'hi',
    );
    final taDubbed = t(key: 'ta-key', name: 'Tamil Dubbed Trailer', lang: 'ta');

    test('requested Hindi plays the verified Hindi trailer', () {
      final sel = TrailerService.selectForLanguages(
        [enOfficial, hiDubbed],
        requested: 'hi',
        movie: const Movie(id: 1, title: 'X'),
      );
      expect(sel!.key, 'hi-key');
    });

    test('unavailable language falls back to English (never another movie)',
        () {
      final sel = TrailerService.selectForLanguages(
        [enOfficial, taDubbed],
        requested: 'de',
        movie: const Movie(id: 1, title: 'X'),
      );
      expect(sel!.key, 'en-key');
    });

    test('original-language trailer wins over Hindi for foreign films', () {
      final koOriginal = t(key: 'ko-key', name: 'Korean Trailer', lang: 'ko');
      final sel = TrailerService.selectForLanguages(
        [koOriginal, hiDubbed, enOfficial],
        movie: const Movie(id: 1, title: 'X', originalLanguage: 'ko'),
      );
      expect(sel!.key, 'ko-key');
    });

    test('empty verified set selects nothing (no wrong fallback)', () {
      expect(
        TrailerService.selectForLanguages(const [], requested: 'hi'),
        isNull,
      );
    });

    test('teaser is never labeled a full trailer', () {
      final teaser = t(key: 't1', name: 'Teaser', type: 'Teaser', lang: 'en');
      expect(teaser.trailerTypeLabel, 'Official Teaser');
      expect(teaser.isTeaser, isTrue);
      expect(teaser.isTrailer, isFalse);
    });

    test('dubbed languages are labelled "<Language> Dubbed Trailer"', () {
      expect(hiDubbed.trailerTypeLabel, 'Hindi Dubbed Trailer');
      expect(hiDubbed.isDubbed, isTrue);
      expect(hiDubbed.isOriginal, isFalse);
      expect(taDubbed.trailerTypeLabel, 'Tamil Dubbed Trailer');
      expect(enOfficial.trailerTypeLabel, 'Official Trailer');
    });
  });
// __PART2__

  group('TEST 8-9 · structured discovery filters map 1:1 to TMDb', () {
    test('discover params map 1:1 to real TMDb parameters', () {
      const filters = DiscoverFilters(
        genreId: 27,
        withOriginalLanguage: 'hi',
        minRating: 7,
        runtimeMax: 120,
      );
      final q = filters.toQueryParams();
      expect(q['with_genres'], 27);
      expect(q['with_original_language'], 'hi');
      expect(q['vote_average.gte'], 7);
      expect(q['with_runtime.lte'], 120);
      expect(q['sort_by'], 'popularity.desc');
    });
  });
// __PART3__

  group('TEST 10 · Movie DNA is deterministic MovieGPT analysis', () {
    test('horror scores higher on Horror than Comedy', () {
      final dna = MovieDna.fromMovie(const Movie(
        id: 1,
        title: 'Scary Film',
        genre: 'Horror / Thriller',
        rating: 7.0,
        runtimeMinutes: 110,
      ));
      final horror = dna.trait('Horror')!;
      final comedy = dna.trait('Comedy')!;
      expect(horror.score, greaterThan(comedy.score));
      for (final t in dna.traits) {
        expect(t.score, inInclusiveRange(0, 100));
      }
    });

    test('same metadata always yields identical scores (no randomness)', () {
      const m = Movie(
        id: 2,
        title: 'Action Flick',
        genre: 'Action / Adventure',
        rating: 8.1,
        runtimeMinutes: 140,
      );
      final a = MovieDna.fromMovie(m);
      final b = MovieDna.fromMovie(m);
      expect(a.traits.map((t) => t.score), b.traits.map((t) => t.score));
    });
  });

  group('Phase 10 · Movie Match uses only real activity', () {
    test('shared genres raise the score and produce real reasons', () {
      const candidate = Movie(
        id: 10,
        title: 'New Sci-Fi',
        genre: 'Science Fiction',
        rating: 8.2,
      );
      final liked = [
        const Movie(id: 11, title: 'Blade Runner', genre: 'Science Fiction'),
        const Movie(id: 12, title: 'Arrival', genre: 'Sci-Fi / Drama'),
      ];
      final match = MovieMatch.compute(movie: candidate, likedMovies: liked);
      expect(match.percent, greaterThan(52));
      expect(
        match.reasons.any((r) => r.toLowerCase().contains('science fiction')),
        isTrue,
      );
    });

    test('no saved activity falls back to the real TMDB rating only', () {
      const m =
          Movie(id: 20, title: 'Solo Pick', rating: 7.9, aiMatchScore: 92);
      final match = MovieMatch.compute(movie: m, likedMovies: const []);
      expect(match.reasons.first, contains('TMDB'));
    });
  });
}
