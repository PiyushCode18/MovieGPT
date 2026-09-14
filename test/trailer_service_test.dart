import 'package:flutter_test/flutter_test.dart';
import 'package:moviegpt_app/models/movie_model.dart';
import 'package:moviegpt_app/services/trailer_service.dart';

/// Pure, network-free tests for the trailer-selection engine
/// ([TrailerService.selectBestTrailer] / [TrailerService.isValidTrailerForMovie]).
///
/// These mirror the required live TEST cases (1, 2, 3) at the logic level.
void main() {
  final service = TrailerService.instance;

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

  final brandNewDay = Movie(
    id: 1103927,
    title: 'Spider-Man: Brand New Day',
  );

  group('TEST 1 — Spider-Man: Brand New Day', () {
    test('rejects a Spider-Man: No Way Home trailer', () {
      final nwh = t(
        key: 'nwh-key',
        name: 'SPIDER-MAN: NO WAY HOME - Official Trailer | In Cinemas',
      );
      expect(service.isValidTrailerForMovie(brandNewDay, nwh), isFalse);
    });

    test('accepts the verified official Brand New Day trailer', () {
      final official = t(
        key: 'BwntXFBNfOA',
        name:
            'SPIDER-MAN: BRAND NEW DAY - Official Trailer | '
            'Exclusively In Cinemas 31 July',
      );
      expect(service.isValidTrailerForMovie(brandNewDay, official), isTrue);
    });

    test('selects the Brand New Day trailer, NOT No Way Home', () {
      final nwh = t(
        key: 'nwh-key',
        name: 'SPIDER-MAN: NO WAY HOME - Official Trailer',
      );
      final actual = t(
        key: 'actual-key',
        name: 'SPIDER-MAN: BRAND NEW DAY - Official Trailer',
      );
      final selected = service.selectBestTrailer(brandNewDay, [nwh, actual]);
      expect(selected, isNotNull);
      expect(selected!.key, 'actual-key');
      expect(selected.name.toLowerCase(), contains('brand new day'));
      expect(selected.name.toLowerCase(), isNot(contains('no way home')));
    });

    test('returns null when ONLY a No Way Home trailer is available '
        '(never the wrong movie)', () {
      final nwh = t(
        key: 'nwh-key',
        name: 'SPIDER-MAN: NO WAY HOME - Official Trailer',
      );
      expect(service.selectBestTrailer(brandNewDay, [nwh]), isNull);
    });
  });

  group('TEST 2 — another movie with an official trailer', () {
    test('picks that movie official trailer (not Spider-Man)', () {
      final dune = Movie(id: 438631, title: 'Dune: Part Two');
      final teaser = t(
        key: 'teaser-key',
        name: 'Dune: Part Two - Teaser',
        type: 'Teaser',
      );
      final official = t(
        key: 'official-key',
        name: 'DUNE: PART TWO - Official Trailer',
      );
      final selected = service.selectBestTrailer(dune, [teaser, official]);
      expect(selected, isNotNull);
      expect(selected!.key, 'official-key');
    });
  });

  group('TEST 3 — movie with no trailer', () {
    test('returns null when only excluded video types exist', () {
      final movie = Movie(id: 999, title: 'Some Movie');
      final clip = t(
        key: 'c1',
        name: 'Some Movie - Clip',
        type: 'Clip',
      );
      final featurette = t(
        key: 'f1',
        name: 'Some Movie - Featurette',
        type: 'Featurette',
      );
      expect(service.selectBestTrailer(movie, [clip, featurette]), isNull);
    });

    test('returns null for an empty candidate list', () {
      final movie = Movie(id: 999, title: 'Some Movie');
      expect(service.selectBestTrailer(movie, const []), isNull);
    });
  });

  group('Section 4 — filtering rules', () {
    test('rejects a non-YouTube site', () {
      final v = t(key: 'x', name: 'Trailer', site: 'Vimeo');
      expect(
        service.isValidTrailerForMovie(Movie(id: 1, title: 'T'), v),
        isFalse,
      );
    });

    test('rejects a fan-made video', () {
      final v = t(key: 'x', name: 'T - Fan Made Trailer');
      expect(
        service.isValidTrailerForMovie(Movie(id: 1, title: 'T'), v),
        isFalse,
      );
    });

    test('rejects an excluded type (Interview)', () {
      final v = t(key: 'x', name: 'T - Interview', type: 'Interview');
      expect(
        service.isValidTrailerForMovie(Movie(id: 1, title: 'T'), v),
        isFalse,
      );
    });

    test('accepts an English official Trailer', () {
      final v = t(
        key: 'x',
        name: 'T - Official Trailer',
        lang: 'en',
        official: true,
        type: 'Trailer',
      );
      expect(service.isValidTrailerForMovie(Movie(id: 1, title: 'T'), v), isTrue);
    });

    test('priority: Official + Trailer + English rank above a plain Trailer',
        () {
      final plain = t(
        key: 'plain',
        name: 'T - Trailer',
        official: false,
        lang: 'de',
      );
      final best = t(
        key: 'best',
        name: 'T - Official Trailer',
        official: true,
        lang: 'en',
      );
      final selected = service.selectBestTrailer(
        Movie(id: 1, title: 'T'),
        [plain, best],
      );
      expect(selected!.key, 'best');
    });
  });
}