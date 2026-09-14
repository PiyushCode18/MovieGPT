import 'package:flutter_test/flutter_test.dart';
import 'package:moviegpt_app/ai/ai_mode.dart';
import 'package:moviegpt_app/ai/system_prompts.dart';
import 'package:moviegpt_app/models/movie_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovieGPT three persona modes', () {
    test('Exactly three modes with generic display names', () {
      expect(AiPersonalities.all.length, 3);

      expect(
        AiPersonalities.byMode(AiMode.female).displayName,
        'Female Friend',
      );
      expect(AiPersonalities.byMode(AiMode.male).displayName, 'Male Assistant');
      expect(
        AiPersonalities.byMode(AiMode.assistant).displayName,
        'AI Assistant',
      );

      expect(AiPersonalities.modeToName(AiMode.female), 'female');
      expect(AiPersonalities.modeToName(AiMode.male), 'male');
      expect(AiPersonalities.modeToName(AiMode.assistant), 'assistant');

      expect(AiPersonalities.modeFromName('male'), AiMode.male);
      expect(AiPersonalities.modeFromName('assistant'), AiMode.assistant);
      expect(AiPersonalities.modeFromName(null), AiMode.female);
      expect(AiPersonalities.defaultMode, AiMode.female);
    });

    test('No hidden fake-human identities remain', () {
      // The assistant must be transparent about being an AI.
      for (final personality in AiPersonalities.all) {
        if (personality.mode == AiMode.female) {
          // Female Friend uses a companion label but is still transparent about
          // being an AI (enforced via the system prompt identity rules).
          expect(personality.displayName, 'Female Friend');
        } else {
          expect(personality.displayName.contains('Assistant'), isTrue);
        }
      }
    });
  });

  group('SystemPrompts — real LLM instructions', () {
    test('Female prompt carries the Female Assistant persona', () {
      final prompt = SystemPrompts.build(
        mode: AiMode.female,
        now: DateTime(2026, 1, 15, 10, 30),
      );
      expect(prompt, contains('Female Assistant'));
      expect(prompt, contains('emotionally aware'));
    });

    test('Male prompt carries the Male Assistant persona and differs', () {
      final prompt = SystemPrompts.build(
        mode: AiMode.male,
        now: DateTime(2026, 1, 15, 10, 30),
      );
      expect(prompt, contains('Male Assistant'));
      expect(prompt, contains('humor'));

      final female = SystemPrompts.build(
        mode: AiMode.female,
        now: DateTime(2026, 1, 15, 10, 30),
      );
      expect(prompt, isNot(equals(female)));
    });

    test('Prompts forbid canned responses and demand context use', () {
      for (final mode in AiMode.values) {
        final prompt = SystemPrompts.build(
          mode: mode,
          now: DateTime(2026, 1, 15),
        );
        expect(prompt.toLowerCase(), contains('canned'));
        expect(prompt.toLowerCase(), contains('conversation history'));
        expect(prompt.toLowerCase(), contains('never claim to be a human'));
      }
    });

    test('Prompts include the real TMDb tool guidance', () {
      final prompt = SystemPrompts.build(
        mode: AiMode.female,
        now: DateTime(2026, 1, 15),
      );
      expect(prompt, contains('movie tools'));
      expect(prompt, contains('TMDb'));
    });

    test('Creator facts use the allowlist only', () {
      final prompt = SystemPrompts.build(
        mode: AiMode.assistant,
        now: DateTime(2026, 1, 15),
      );
      expect(prompt, contains('PIYUSH RAUT'));
      expect(prompt, isNot(contains('Pillai HOC College')));
      expect(prompt, isNot(contains('software engineer')));
      expect(prompt.toLowerCase(), contains('never invent additional'));
    });

    test('Profile context is included when signed in', () {
      final prompt = SystemPrompts.build(
        mode: AiMode.female,
        now: DateTime(2026, 1, 15),
        userName: 'Piyush',
        userEmail: 'piyush@example.com',
      );
      expect(prompt, contains('Piyush'));
      expect(prompt, contains('piyush@example.com'));
    });

    test('Missing profile explicitly instructs honesty', () {
      final prompt = SystemPrompts.build(
        mode: AiMode.female,
        now: DateTime(2026, 1, 15),
      );
      expect(prompt, contains('Signed-in profile: none'));
      expect(prompt, contains("honestly say you don't have their profile"));
    });

    test('Watchlist context lists real saved movies', () {
      const movie = Movie(
        id: 42,
        title: 'Interstellar',
        genre: 'Sci-fi',
        rating: 8.6,
        year: '2014',
      );
      final prompt = SystemPrompts.build(
        mode: AiMode.female,
        now: DateTime(2026, 1, 15),
        watchlist: const [movie],
      );
      expect(prompt, contains('Interstellar'));
      expect(prompt, contains('8.6'));
    });

    test('Current date/time is provided so relative questions work', () {
      final prompt = SystemPrompts.build(
        mode: AiMode.male,
        now: DateTime(2026, 8, 27, 21, 5),
      );
      expect(prompt, contains('2026-08-27'));
      expect(prompt, contains('21:05'));
    });
  });
}
