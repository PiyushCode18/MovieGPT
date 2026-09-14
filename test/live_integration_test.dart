// LIVE integration tests: exercise the REAL TMDB + Gemini integrations used
// by the app (ApiClient/TmdbApiService/TrailerService/AiService) with the
// real .env configuration. No fake data anywhere: failures mean the service
// integration is broken.
//
// SECURITY: these tests never print any secret value.
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moviegpt_app/config/env_config.dart';
import 'package:moviegpt_app/models/discover_filters.dart';
import 'package:moviegpt_app/services/ai_service.dart';
import 'package:moviegpt_app/services/tmdb_api_service.dart';
import 'package:moviegpt_app/services/trailer_service.dart';

void main() {
  setUpAll(() {
    // Load the REAL .env with the same parser flutter_dotenv uses in the app.
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());
  });

  test(
    'dotenv: TMDB + Gemini configured, provider=gemini',
    () {
      expect(EnvConfig.hasApiKey, isTrue,
          reason: 'TMDB_API_KEY must be configured');
      expect(EnvConfig.geminiApiKey, isNotEmpty,
          reason: 'GEMINI_API_KEY must be configured');
      expect(EnvConfig.aiProvider, 'gemini');
      expect(EnvConfig.geminiModel, startsWith('gemini-'));
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'TMDB: trending today returns REAL movies (with host fallback)',
    () async {
      final movies = await TmdbApiService.instance.getTrending();
      expect(movies, isNotEmpty, reason: 'TMDB trending must return movies');
      expect(movies.first.title, isNotEmpty);
      expect(movies.first.id, greaterThan(0));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'TMDB: posters and backdrops build real image URLs',
    () async {
      final movies = await TmdbApiService.instance.getTrending();
      final withPoster = movies.where((m) => m.posterUrl() != null).toList();
      expect(withPoster, isNotEmpty);
      expect(
          withPoster.first.posterUrl(), startsWith('https://image.tmdb.org'));
      final withBackdrop =
          movies.where((m) => m.backdropUrl() != null).toList();
      if (withBackdrop.isNotEmpty) {
        expect(
          withBackdrop.first.backdropUrl(),
          startsWith('https://image.tmdb.org'),
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'TMDB: search finds Interstellar',
    () async {
      final results =
          await TmdbApiService.instance.searchMovies('Interstellar');
      expect(results, isNotEmpty);
      expect(
        results.any((m) => m.title.toLowerCase().contains('interstellar')),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'TMDB: genre list contains the five core genres',
    () async {
      final genres = await TmdbApiService.instance.getGenres();
      final names = genres.map((g) => g.name).toSet();
      for (final expected in [
        'Adventure',
        'Action',
        'Comedy',
        'Drama',
        'Science Fiction',
      ]) {
        expect(names, contains(expected), reason: 'genre $expected missing');
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'TMDB: discover by genre returns REAL movies for the five core genres',
    () async {
      const genreIds = {
        'Adventure': 12,
        'Action': 28,
        'Comedy': 35,
        'Drama': 18,
        'Science Fiction': 878,
      };
      for (final entry in genreIds.entries) {
        final movies = await TmdbApiService.instance.getByGenre(entry.value);
        expect(movies, isNotEmpty,
            reason: '${entry.key} discover returned no movies');
      }
      // Also verify the structured discover path used by the AI tools.
      final filtered = await TmdbApiService.instance.discoverMovies(
        const DiscoverFilters(genreId: 878, minRating: 7),
      );
      expect(filtered, isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'TMDB: details + videos + official trailer selection for Interstellar',
    () async {
      final results =
          await TmdbApiService.instance.searchMovies('Interstellar');
      expect(results, isNotEmpty);
      final movie = results.firstWhere(
        (m) => m.title.toLowerCase().contains('interstellar'),
      );

      final details = await TmdbApiService.instance.getMovieDetails(movie.id);
      expect(details.title, isNotEmpty);
      expect(details.overview, isNotEmpty);
      expect(details.rating, greaterThanOrEqualTo(0));
      expect(details.releaseDate, isNotEmpty);
      expect(details.runtimeMinutes, greaterThan(0));
      expect(details.posterUrl() ?? details.backdropUrl(), isNotNull);

      final videos = await TmdbApiService.instance.getMovieVideos(movie.id);
      expect(videos, isNotEmpty, reason: 'TMDB videos endpoint returned none');

      final selected =
          TrailerService.instance.selectBestTrailer(details, videos);
      expect(selected, isNotNull,
          reason: 'an official trailer should be selectable');
      expect(selected!.site.toLowerCase(), 'youtube');
      expect(
        RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(selected.key),
        isTrue,
        reason: 'YouTube key must be a real 11-char id',
      );
      expect(selected.isTrailer || selected.isTeaser, isTrue);
      expect(selected.verified, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'Gemini: AiService streams a REAL response end-to-end',
    () async {
      final service = AiService();
      expect(service.isConfigured, isTrue);
      expect(service.providerName, contains('Gemini'));

      final buffer = StringBuffer();
      await for (final chunk in service.streamComplete(
        systemPrompt:
            'You are the MovieGPT assistant. Reply briefly and warmly.',
        history: const [AiChatTurn(role: 'user', content: 'Hey')],
      )) {
        buffer.write(chunk.delta);
        if (chunk.done) break;
      }
      expect(
        buffer.toString().trim(),
        isNotEmpty,
        reason: 'Gemini must return real generated text',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'Gemini: complete() returns real text for a movie question',
    () async {
      final service = AiService();
      final completion = await service.complete(
        systemPrompt: 'You are a concise movie assistant.',
        history: const [
          AiChatTurn(role: 'user', content: 'Say OK if you can hear me.'),
        ],
      );
      expect(completion.text.trim(), isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
