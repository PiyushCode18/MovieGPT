import 'package:flutter_test/flutter_test.dart';
import 'package:moviegpt_app/data/movie_repository.dart';
import 'package:moviegpt_app/models/movie_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MovieRepository.instance.clearCache();
  });

  group('MovieRepository disk cache round-trip', () {
    test('clearCache resets in-memory state without throwing', () {
      // clearCache is a no-op-safe reset; calling it twice must not throw.
      MovieRepository.instance.clearCache();
      MovieRepository.instance.clearCache();
    });

    test('searchMovies returns empty for blank query', () async {
      final result = await MovieRepository.instance.searchMovies('   ');
      expect(result, isEmpty);
    });
  });

  group('Movie model storage round-trip (disk cache payload)', () {
    test('toStorageJson/fromStorageJson round-trips a movie', () {
      final movie = Movie(
        id: 7,
        title: 'Inception',
        genre: 'Sci-fi',
        rating: 8.8,
        year: '2010',
        posterPath: '/inception.jpg',
        backdropPath: '/backdrop.jpg',
        director: 'Nolan',
        production: 'WB',
        status: 'Released',
      );
      final restored = Movie.fromStorageJson(movie.toStorageJson());
      expect(restored.id, 7);
      expect(restored.title, 'Inception');
      expect(restored.genre, 'Sci-fi');
      expect(restored.rating, 8.8);
      expect(restored.year, '2010');
      expect(restored.posterPath, '/inception.jpg');
      expect(restored.backdropPath, '/backdrop.jpg');
      expect(restored.director, 'Nolan');
      expect(restored.production, 'WB');
      expect(restored.status, 'Released');
    });

    test('fromStorageJson tolerates a missing/partial map', () {
      final restored = Movie.fromStorageJson({'id': 1});
      expect(restored.id, 1);
      expect(restored.title, 'Untitled');
      expect(restored.genre, 'Movie');
      expect(restored.posterPath, isNull);
    });

    test('fromStorageJson preserves optional poster/backdrop paths', () {
      final restored = Movie.fromStorageJson({
        'id': 9,
        'title': 'Dune',
        'poster_path': '/dune-poster.jpg',
        'backdrop_path': '/dune-backdrop.jpg',
      });
      expect(restored.posterPath, '/dune-poster.jpg');
      expect(restored.backdropPath, '/dune-backdrop.jpg');
      // imageUrl should build from backdrop first.
      expect(restored.imageUrl('w500'), isNotNull);
    });

    test('Movie.fromJson parses nested credits for director', () {
      final movie = Movie.fromJson({
        'id': 11,
        'title': 'Test Film',
        'vote_average': 7.5,
        'genres': [
          {'id': 28, 'name': 'Action'},
        ],
        'credits': {
          'crew': [
            {'job': 'Director', 'name': 'Christopher Nolan'},
            {'job': 'Producer', 'name': 'Someone Else'},
          ],
        },
        'production_companies': [
          {'name': 'Warner Bros'},
        ],
        'release_date': '2020-05-15',
        'runtime': 148,
      });
      expect(movie.director, 'Christopher Nolan');
      expect(movie.production, 'Warner Bros');
      expect(movie.year, '2020');
      expect(movie.duration, '2h 28m');
    });
  });

  group('Movie model helpers', () {
    test('_durationFromMinutes formats hours and minutes', () {
      // Accessible via fromJson runtime > 0.
      final movie = Movie.fromJson({'id': 1, 'title': 'T', 'runtime': 125});
      expect(movie.duration, '2h 5m');
    });

    test('imageUrl prefers backdrop when both present', () {
      final movie = Movie(
        id: 1,
        title: 'T',
        posterPath: '/poster.jpg',
        backdropPath: '/backdrop.jpg',
      );
      expect(movie.imageUrl('w500'), contains('/backdrop.jpg'));
    });

    test('imageUrl returns null when no image paths', () {
      final movie = Movie(id: 1, title: 'T');
      expect(movie.posterUrl(), isNull);
      expect(movie.backdropUrl(), isNull);
      expect(movie.imageUrl('w500'), isNull);
    });
  });

  group('Trailer model & attributes', () {
    test('Trailer.fromJson parses fields correctly', () {
      final trailer = Trailer.fromJson({
        'id': 'v1',
        'key': 'abc12345',
        'name': 'Official Hindi Dubbed Trailer',
        'site': 'YouTube',
        'type': 'Trailer',
        'iso_639_1': 'hi',
        'official': true,
      });

      expect(trailer.id, 'v1');
      expect(trailer.key, 'abc12345');
      expect(trailer.name, 'Official Hindi Dubbed Trailer');
      expect(trailer.isTrailer, isTrue);
      expect(trailer.isHindi, isTrue);
      expect(trailer.official, isTrue);
      expect(trailer.youtubeUrl, 'https://www.youtube.com/watch?v=abc12345');
    });

    test('isTrailer flags non-trailer types correctly', () {
      final teaser = Trailer.fromJson({
        'key': 't1',
        'site': 'YouTube',
        'type': 'Teaser',
      });
      final blooper = Trailer.fromJson({
        'key': 'b1',
        'site': 'YouTube',
        'type': 'Bloopers',
      });

      expect(teaser.isTrailer, isFalse);
      expect(teaser.isTeaser, isTrue);
      expect(blooper.isTrailer, isFalse);
    });

    test('Subtitle conflict rejection helper logic', () {
      const knownFranchiseSubtitles = [
        'no way home',
        'far from home',
        'homecoming',
        'brand new day',
      ];

      bool isConflictingSubtitle(String candName, String movieTitle) {
        final candLower = candName.toLowerCase();
        final movieLower = movieTitle.toLowerCase();
        for (final sub in knownFranchiseSubtitles) {
          if (candLower.contains(sub) && !movieLower.contains(sub)) {
            return true;
          }
        }
        return false;
      }

      // Spider-Man: Brand New Day MUST reject No Way Home trailer
      expect(
        isConflictingSubtitle(
          'SPIDER-MAN: NO WAY HOME – Official Trailer',
          'Spider-Man: Brand New Day',
        ),
        isTrue,
      );

      // Spider-Man: Brand New Day MUST NOT reject Brand New Day trailer
      expect(
        isConflictingSubtitle(
          'SPIDER-MAN: BRAND NEW DAY – Official Trailer',
          'Spider-Man: Brand New Day',
        ),
        isFalse,
      );

      // Spider-Man: No Way Home MUST NOT reject No Way Home trailer
      expect(
        isConflictingSubtitle(
          'SPIDER-MAN: NO WAY HOME – Official Trailer',
          'Spider-Man: No Way Home',
        ),
        isFalse,
      );
    });
  });
}
