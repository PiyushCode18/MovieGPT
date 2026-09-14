import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moviegpt_app/models/movie_model.dart';
import 'package:moviegpt_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatMessage serialization', () {
    test('toJson round-trips a text message', () {
      final msg = ChatMessage(
        id: 'm1',
        sender: 'user',
        text: 'Recommend horror movies',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );
      final map = msg.toJson();
      final restored = ChatMessage.fromJson(map);
      expect(restored.id, 'm1');
      expect(restored.sender, 'user');
      expect(restored.text, 'Recommend horror movies');
      expect(restored.timestamp, DateTime(2024, 1, 1, 12, 0, 0));
      expect(restored.recommended, isNull);
    });

    test('toJson round-trips a message with recommended movies', () {
      final movie = Movie(
        id: 42,
        title: 'Interstellar',
        genre: 'Sci-fi',
        rating: 8.6,
        year: '2014',
        posterPath: '/x.jpg',
      );
      final msg = ChatMessage(
        id: 'm2',
        sender: 'ai',
        text: 'Here are some movies.',
        timestamp: DateTime(2024, 2, 2),
        recommended: [movie],
      );
      final restored = ChatMessage.fromJson(msg.toJson());
      expect(restored.recommended, isNotNull);
      expect(restored.recommended!.length, 1);
      expect(restored.recommended!.first.id, 42);
      expect(restored.recommended!.first.title, 'Interstellar');
      expect(restored.recommended!.first.posterPath, '/x.jpg');
    });

    test('fromJson handles malformed input gracefully', () {
      // Missing required fields -> id marker '<invalid>'.
      final bad = ChatMessage.fromJson({'sender': 'user'});
      expect(bad.id, '<invalid>');

      // Invalid timestamp -> falls back to epoch 0.
      final badTs = ChatMessage.fromJson({
        'id': 'x',
        'sender': 'ai',
        'text': 'hi',
        'timestamp': 'not-a-date',
      });
      expect(badTs.id, 'x');
      expect(badTs.timestamp, DateTime.fromMillisecondsSinceEpoch(0));

      // Malformed recommended entries are skipped.
      final msg = ChatMessage.fromJson({
        'id': 'y',
        'sender': 'ai',
        'text': 'hi',
        'timestamp': '2024-01-01T00:00:00.000',
        'recommended': [
          'not-a-map',
          {'id': 1, 'title': 'A'},
        ],
      });
      expect(msg.recommended, isNotNull);
      expect(msg.recommended!.length, 1);
      expect(msg.recommended!.first.id, 1);
    });
  });

  group('ChatHistoryNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists and restores history across instances', () async {
      final notifier = ChatHistoryNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, isEmpty);

      notifier.add(
        ChatMessage(
          id: 'u1',
          sender: 'user',
          text: 'hello',
          timestamp: DateTime(2024, 1, 1),
        ),
      );
      notifier.add(
        ChatMessage(
          id: 'a1',
          sender: 'ai',
          text: 'Hi there',
          timestamp: DateTime(2024, 1, 1, 0, 1),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.length, 2);

      // A new notifier instance should restore from SharedPreferences.
      final restored = ChatHistoryNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(restored.state.length, 2);
      expect(restored.state.first.text, 'hello');
      expect(restored.state[1].text, 'Hi there');
    });

    test('bounds history to maxMessages', () async {
      final notifier = ChatHistoryNotifier();
      await Future<void>.delayed(Duration.zero);
      for (int i = 0; i < ChatHistoryNotifier.maxMessages + 10; i++) {
        notifier.add(
          ChatMessage(
            id: 'm$i',
            sender: 'user',
            text: 'msg $i',
            timestamp: DateTime(2024, 1, 1).add(Duration(minutes: i)),
          ),
        );
      }
      expect(
        notifier.state.length,
        ChatHistoryNotifier.maxMessages,
      );
      // Oldest messages are dropped.
      expect(notifier.state.first.text, contains('${10}'));
    });

    test('clear wipes persisted history', () async {
      final notifier = ChatHistoryNotifier();
      await Future<void>.delayed(Duration.zero);
      notifier.add(
        ChatMessage(
          id: 'u1',
          sender: 'user',
          text: 'hello',
          timestamp: DateTime(2024, 1, 1),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await notifier.clear();
      expect(notifier.state, isEmpty);

      final reloaded = ChatHistoryNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(reloaded.state, isEmpty);
    });

    test('recovers from corrupted persisted data', () async {
      SharedPreferences.setMockInitialValues({
        'moviegpt_chat_history_v1': '{not valid json!!',
      });
      final notifier = ChatHistoryNotifier();
      await Future<void>.delayed(Duration.zero);
      // Corrupted cache -> gracefully resets to empty (no throw).
      expect(notifier.state, isEmpty);
    });

    test('rejects messages that decode to invalid entries', () async {
      SharedPreferences.setMockInitialValues({
        'moviegpt_chat_history_v1': jsonEncode([
          {'sender': 'user'}, // missing id/text -> skipped
          {
            'id': 'ok',
            'sender': 'ai',
            'text': 'valid',
            'timestamp': '2024-01-01T00:00:00.000',
          },
        ]),
      });
      final notifier = ChatHistoryNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.length, 1);
      expect(notifier.state.first.text, 'valid');
    });
  });
}
