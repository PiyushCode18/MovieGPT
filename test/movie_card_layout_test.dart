import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moviegpt_app/models/movie_model.dart';
import 'package:moviegpt_app/widgets/movie_card.dart';

void main() {
    final movie = Movie(
    id: 1,
    title: 'Spider-Man: Brand New Day',
    genre: 'Science Fiction / Action',
    rating: 7.9,
    year: '2026',
    aiMatchScore: 95,
    // These are offline layout tests (overflow / no-throw). Use an empty
    // poster path so MoviePoster renders its built-in placeholder instead of
    // triggering CachedNetworkImage, which can never resolve without a real
    // network and would hang pumpAndSettle under the Flutter test binding
    // (its HttpClient returns HTTP 400).
    posterPath: '',
    overview: 'A brand new day starts now.',
    duration: '2h 25m',
  );

  testWidgets('MovieCard renders in horizontal (unbounded-height) list', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 302,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                itemBuilder: (_, _) => MovieCard(movie: movie),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('MovieCard renders in bounded grid cell without overflow', (
    tester,
  ) async {
    try {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.42,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: 10,
                itemBuilder: (_, _) =>
                    MovieCard(movie: movie, width: double.infinity),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } catch (e) {
      fail('Grid MovieCard threw: $e');
    }
  });
}
