import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviegpt_app/models/app_user.dart';
import 'package:moviegpt_app/models/movie_model.dart';
import 'package:moviegpt_app/services/ai_service.dart';
import 'package:moviegpt_app/state/auth_providers.dart';
import 'package:moviegpt_app/state/chat_providers.dart';
import 'package:moviegpt_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A controllable [AiClient] double: records the conversation payload and
/// returns a preset completion (or throws a preset error).
class FakeAiClient implements AiClient {
  FakeAiClient({this.isConfigured = true});

  @override
  bool isConfigured;

  /// When non-null, [complete] throws this (simulating API failures).
  Object? thrown;

  /// Preset completion returned by [complete].
  AiCompletion? completion;

  /// The full conversation payload captured for each request.
  final List<List<AiChatTurn>> capturedHistory = [];

  @override
  String get providerName => 'Fake';

  @override
  Future<AiCompletion> complete({
    required String systemPrompt,
    required List<AiChatTurn> history,
    List<AiToolSpec> tools = const [],
    Future<AiToolResult> Function(String toolName, Map<String, dynamic> args)?
        onToolCall,
    int maxToolRounds = 3,
  }) async {
    capturedHistory.add(history);
    final error = thrown;
    if (error != null) throw error;
    return completion ?? const AiCompletion('Fake reply');
  }

  @override
  Stream<AiStreamChunk> streamComplete({
    required String systemPrompt,
    required List<AiChatTurn> history,
    List<AiToolSpec> tools = const [],
    Future<AiToolResult> Function(String toolName, Map<String, dynamic> args)?
        onToolCall,
    int maxToolRounds = 3,
    CancelToken? cancelToken,
  }) async* {
    capturedHistory.add(history);
    final error = thrown;
    if (error != null) throw error;
    final c = completion ?? const AiCompletion('Fake reply');
    yield AiStreamChunk(c.text, done: true, movies: c.movies);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAiClient fake;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeAiClient();
    container = ProviderContainer(
      overrides: [
        aiClientProvider.overrideWithValue(fake),
        authStateProvider.overrideWith(
          (ref) => Stream<AppUser?>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  ChatMessage messageAt(int index) => container.read(chatHistoryProvider)[index];

  group('AiChatSendNotifier — real conversation flow', () {
    test('delivers the real AI reply with movie cards and resets typing',
        () async {
      const movie = Movie(
        id: 1,
        title: 'Interstellar',
        genre: 'Sci-fi',
        rating: 8.6,
        year: '2014',
      );
      fake.completion = const AiCompletion('Great choice 🚀', movies: [movie]);

      await container
          .read(aiChatSendProvider.notifier)
          .send('I love Interstellar');

      final history = container.read(chatHistoryProvider);
      expect(history.length, 2);
      expect(history.first.sender, 'user');
      expect(history.first.text, 'I love Interstellar');
      expect(history.last.sender, 'ai');
      expect(history.last.text, 'Great choice 🚀');
      expect(history.last.assistantMode, 'female');
      expect(history.last.isError, isFalse);
      expect(history.last.recommended, isNotNull);
      expect(history.last.recommended!.single.title, 'Interstellar');

      final sendState = container.read(aiChatSendProvider);
      expect(sendState.isTyping, isFalse);
      expect(sendState.pendingUserText, isNull);
    });

    test('sends bounded real history so follow-ups have context', () async {
      // A static welcome bubble exists (like the real screen adds) and must
      // never be sent to the model.
      container.read(chatHistoryProvider.notifier).add(
            ChatMessage(
              id: 'welcome',
              sender: 'ai',
              text: 'Welcome bubble',
              timestamp: DateTime(2024, 1, 1),
            ),
          );

      fake.completion = const AiCompletion('Nice to meet you!');
      await container
          .read(aiChatSendProvider.notifier)
          .send('My name is Piyush');

      fake.completion = const AiCompletion('Piyush, of course.');
      await container
          .read(aiChatSendProvider.notifier)
          .send('What is my name?');

      expect(fake.capturedHistory, hasLength(2));
      // First request: only the user's message (welcome excluded).
      expect(fake.capturedHistory[0], hasLength(1));
      expect(fake.capturedHistory[0].single.role, 'user');
      expect(fake.capturedHistory[0].single.content, 'My name is Piyush');
      // Second request: full prior conversation + the new message.
      expect(fake.capturedHistory[1], hasLength(3));
      expect(fake.capturedHistory[1][0].role, 'user');
      expect(fake.capturedHistory[1][1].role, 'assistant');
      expect(fake.capturedHistory[1][1].content, 'Nice to meet you!');
      expect(fake.capturedHistory[1].last.content, 'What is my name?');
    });

    test('AI failure shows an honest error bubble and retry recovers',
        () async {
      fake.thrown = const AiServiceException(AiErrorKind.offline);

      await container.read(aiChatSendProvider.notifier).send('Hey');

      final history = container.read(chatHistoryProvider);
      expect(history.length, 2);
      expect(history.last.isError, isTrue);
      expect(history.last.text, contains("You're offline right now"));
      // No fake assistant reply was fabricated.
      expect(history.where((m) => m.sender == 'ai' && !m.isError), isEmpty);

      // Pending message kept for retry.
      expect(container.read(aiChatSendProvider).pendingUserText, 'Hey');
      expect(container.read(aiChatSendProvider).isTyping, isFalse);

      // Retry with a healthy backend: error bubble removed, real reply added.
      fake.thrown = null;
      fake.completion = const AiCompletion('Hey 😊 What is up?');
      await container.read(aiChatSendProvider.notifier).retry();

      final after = container.read(chatHistoryProvider);
      expect(after.length, 2);
      expect(after.last.isError, isFalse);
      expect(after.last.text, 'Hey 😊 What is up?');
      expect(container.read(aiChatSendProvider).pendingUserText, isNull);
    });

    test('not-configured backend explains the setup steps honestly',
        () async {
      fake.isConfigured = false;

      await container.read(aiChatSendProvider.notifier).send('Hello');

      final history = container.read(chatHistoryProvider);
      expect(history.last.isError, isTrue);
      expect(history.last.text, contains('GEMINI_API_KEY'));
      expect(history.last.text, contains('.env'));
    });

    test('rate limit and auth failures map to distinct honest messages',
        () async {
      fake.thrown = const AiServiceException(AiErrorKind.rateLimit);
      await container.read(aiChatSendProvider.notifier).send('Hi');
      expect(messageAt(1).text, contains('rate-limiting'));

      fake.thrown = const AiServiceException(AiErrorKind.auth);
      await container.read(aiChatSendProvider.notifier).retry();
      expect(
        container.read(chatHistoryProvider).last.text,
        contains('rejected the API key'),
      );
    });

    test('empty messages are ignored (no request, no bubble)', () async {
      await container.read(aiChatSendProvider.notifier).send('   ');
      expect(container.read(chatHistoryProvider), isEmpty);
      expect(fake.capturedHistory, isEmpty);
    });
  });

  group('ChatMessage — new assistant fields persist', () {
    test('assistantMode and isError round-trip through JSON', () {
      final msg = ChatMessage(
        id: 'm1',
        sender: 'ai',
        text: 'oops',
        timestamp: DateTime(2024, 5, 5),
        assistantMode: 'male',
        isError: true,
      );
      final restored = ChatMessage.fromJson(msg.toJson());
      expect(restored.assistantMode, 'male');
      expect(restored.isError, isTrue);
    });

    test('legacy JSON without the new fields still decodes', () {
      final restored = ChatMessage.fromJson({
        'id': 'legacy',
        'sender': 'ai',
        'text': 'old message',
        'timestamp': '2024-01-01T00:00:00.000',
      });
      expect(restored.assistantMode, isNull);
      expect(restored.isError, isFalse);
    });
  });
}

