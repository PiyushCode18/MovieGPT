import 'package:flutter_test/flutter_test.dart';
import 'package:moviegpt_app/models/movie_model.dart';
import 'package:moviegpt_app/services/trailer_service.dart';

void main() {
  final service = TrailerService.instance;

  group('TrailerService Intelligent Selection', () {
    const movie = Movie(
      id: 1,
      title: 'Toxic: A Fairy Tale for Grown-ups',
      originalLanguage: 'kn',
    );

    test('prefers Official English YouTube Trailer over everything else', () {
      final videos = [
        const Trailer(id: '1', key: 't1', name: 'Teaser', site: 'YouTube', type: 'Teaser', official: true, lang: 'en'),
        const Trailer(id: '2', key: 't2', name: 'Official Trailer', site: 'YouTube', type: 'Trailer', official: true, lang: 'en'),
        const Trailer(id: '3', key: 't3', name: 'Clip', site: 'YouTube', type: 'Clip', official: true, lang: 'en'),
      ];

      final selected = service.selectBestTrailer(movie, videos);
      expect(selected?.key, 't2');
      expect(selected?.lang, 'en');
    });

    test('falls back to non-English Official Trailer if English is missing', () {
      final videos = [
        const Trailer(id: '1', key: 't1', name: 'Kannada Trailer', site: 'YouTube', type: 'Trailer', official: true, lang: 'kn'),
        const Trailer(id: '2', key: 't2', name: 'Teaser', site: 'YouTube', type: 'Teaser', official: true, lang: 'en'),
      ];

      final selected = service.selectBestTrailer(movie, videos);
      expect(selected?.key, 't1');
      expect(selected?.lang, 'kn');
    });

    test('falls back to unofficial YouTube Trailer if Official is missing', () {
      final videos = [
        const Trailer(id: '1', key: 't1', name: 'Fan Trailer', site: 'YouTube', type: 'Trailer', official: false, lang: 'en'),
        const Trailer(id: '2', key: 't2', name: 'Another Trailer', site: 'YouTube', type: 'Trailer', official: false, lang: 'en'),
      ];
      // Note: "Fan Trailer" might be rejected by fan-made indicator logic, but "Another Trailer" should pass.
      
      final selected = service.selectBestTrailer(movie, videos);
      expect(selected?.key, 't2');
    });

    test('prefers Teaser over other promotional videos if no Trailer exists', () {
      final videos = [
        const Trailer(id: '1', key: 't1', name: 'Behind the Scenes', site: 'YouTube', type: 'Behind the Scenes', official: true),
        const Trailer(id: '2', key: 't2', name: 'Official Teaser', site: 'YouTube', type: 'Teaser', official: true, lang: 'en'),
      ];

      final selected = service.selectBestTrailer(movie, videos);
      expect(selected?.key, 't2');
    });
    
    test('rejects non-YouTube videos', () {
      final videos = [
        const Trailer(id: '1', key: 't1', name: 'Vimeo Trailer', site: 'Vimeo', type: 'Trailer', official: true),
      ];

      final selected = service.selectBestTrailer(movie, videos);
      expect(selected, isNull);
    });

    test('language priority selection in selectForLanguages', () {
      final verified = [
        const Trailer(id: '1', key: 'en_t', name: 'English', site: 'YouTube', type: 'Trailer', lang: 'en'),
        const Trailer(id: '2', key: 'hi_t', name: 'Hindi', site: 'YouTube', type: 'Trailer', lang: 'hi'),
        const Trailer(id: '3', key: 'kn_t', name: 'Kannada', site: 'YouTube', type: 'Trailer', lang: 'kn'),
      ];

      // 1. Requested language (Hindi)
      var sel = TrailerService.selectForLanguages(verified, requested: 'hi', movie: movie);
      expect(sel?.key, 'hi_t');

      // 2. Movie original language (Kannada)
      sel = TrailerService.selectForLanguages(verified, requested: 'fr', movie: movie);
      expect(sel?.key, 'kn_t');

      // 3. English fallback
      const frMovie = Movie(id: 2, title: 'French Movie', originalLanguage: 'fr');
      sel = TrailerService.selectForLanguages(verified, requested: 'it', movie: frMovie);
      expect(sel?.key, 'en_t');
    });
  });
}
