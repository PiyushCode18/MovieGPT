// Basic smoke test for the MovieGPT app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moviegpt_app/main.dart';
import 'package:moviegpt_app/state/auth_providers.dart';

void main() {
  testWidgets('MovieGPT app smoke test', (WidgetTester tester) async {
    // Override the auth provider with a signed-out stream so the test does
    // not require Firebase to be initialized. The splash resolves to the
    // signed-out route (LoginScreen) after its cinematic animation.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MovieGptApp(),
      ),
    );

    // The splash shows the bundled MovieGPT PNG logo and the "MovieGPT"
    // wordmark rendered beneath it (a RichText of "Movie" + "GPT").
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/images/moviegpt_logo.png',
      ),
      findsOneWidget,
    );
    expect(find.text('MovieGPT', findRichText: true), findsOneWidget);

    // Drive the full cinematic splash to completion and let it settle into
    // the signed-out flow (LoginScreen) so no timers remain pending.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
