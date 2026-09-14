import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_mode.dart';
import '../ai/system_prompts.dart';
import '../config/env_config.dart';
import '../models/movie_model.dart';
import '../services/ai_service.dart';
import '../services/movie_ai_tools.dart';
import 'auth_providers.dart';
import 'providers.dart';

/// The real AI conversation backend (Gemini or OpenAI-compatible).
///
/// Override this provider in tests with a fake [AiClient].
final aiClientProvider = Provider<AiClient>((ref) => AiService());

/// UI state of an AI chat round-trip.
class AiChatSendState {
  /// True while waiting for the FIRST streamed token (typing indicator shows).
  final bool isTyping;

  /// True while a streamed response is actively flowing (first token already
  /// received and is being rendered progressively).
  final bool streaming;

  /// The most recent user message that failed to get a reply, kept so the
  /// user can retry without retyping.
  final String? pendingUserText;

  const AiChatSendState({
    this.isTyping = false,
    this.streaming = false,
    this.pendingUserText,
  });

  /// True while ANY AI request is in flight (blocks duplicate sends and
  /// keeps the input disabled until the stream fully completes).
  bool get isBusy => isTyping || streaming;
}

/// Orchestrates a REAL streaming AI conversation round-trip:
///
/// user message -> append to history -> typing indicator (first-token wait)
/// -> stream provider deltas -> render text progressively (no blank wait)
/// -> finalize message + optional movie cards -> stop typing -> enable Send.
///
/// Errors NEVER fabricate an assistant reply; they surface an honest notice
/// bubble with a retry option. Switching assistant modes cancels the
/// in-flight request so the new assistant starts a completely fresh chat.
class AiChatSendNotifier extends Notifier<AiChatSendState> {
  @override
  AiChatSendState build() => const AiChatSendState();

  /// Bounded short-term memory: the last N conversation turns are sent with
  /// every request so follow-ups resolve correctly without unbounded growth.
  static const int _maxHistoryTurns = 24;

  /// The in-flight request handle (cancelled when switching assistant or on
  /// a new send).
  CancelToken? _cancelToken;

  bool get _isBusy => state.isBusy;

  /// Sends [rawText] as a user message and streams the real AI reply.
  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _isBusy) return;

    final mode = ref.read(selectedAiModeProvider);
    final historyNotifier = ref.read(chatHistoryProvider.notifier);

    // 1. Show the user's actual message immediately.
    historyNotifier.add(
      ChatMessage(
        id: 'user-${DateTime.now().microsecondsSinceEpoch}',
        sender: 'user',
        text: text,
        timestamp: DateTime.now(),
      ),
    );

    // 2. Typing indicator while we wait for the first streamed token.
    state = AiChatSendState(isTyping: true, pendingUserText: text);

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    // Stream accumulators are declared OUTSIDE try so the catch blocks can
    // keep a partially streamed reply instead of always showing an error.
    var streamedText = '';
    final streamedMovies = <Movie>[];
    String? bubbleId;

    try {
      final client = ref.read(aiClientProvider);
      if (!client.isConfigured) {
        EnvConfig.debugWarnIfAiMissing();
        throw const AiServiceException(AiErrorKind.notConfigured);
      }

      // 3. Build the prompt: system instructions + bounded real history.
      // The Female/Male assistants are PERSONAL CHAT ONLY — they get no
      // movie tools and no watchlist/favorites context (keeps the prompt
      // small and fast). Only the AI Assistant carries the TMDb toolkit.
      final isResearchAssistant = mode == AiMode.assistant;
      final profile = ref.read(authStateProvider).value;
      final systemPrompt = SystemPrompts.build(
        mode: mode,
        now: DateTime.now(),
        userName: profile?.displayName,
        userEmail: profile?.email,
        watchlist:
            isResearchAssistant ? ref.read(watchlistProvider) : const [],
        favorites:
            isResearchAssistant ? ref.read(favoritesProvider) : const [],
      );
      final turns = _conversationTurns(ref.read(chatHistoryProvider));

      final tools = isResearchAssistant
          ? MovieAiTools(
              context: MovieToolContext(
                watchlist: () => ref.read(watchlistProvider),
                addToWatchlist: (movie) =>
                    ref.read(watchlistProvider.notifier).add(movie),
                removeFromWatchlist: (movie) =>
                    ref.read(watchlistProvider.notifier).remove(movie),
              ),
            )
          : null;

      // 4. Stream the REAL AI response. Deltas are rendered immediately so
      // the user never stares at a blank screen while the full reply is
      // generated.
await for (final chunk in client.streamComplete(
        systemPrompt: systemPrompt,
        history: turns,
        tools: tools == null ? const [] : MovieAiTools.specs,
        onToolCall: tools?.handle,
        cancelToken: cancelToken,
      )) {
        if (cancelToken.isCancelled) return;

        final delta = chunk.delta;
        if (delta.isNotEmpty) {
          streamedText += delta;
          final modeName = AiPersonalities.modeToName(mode);
          if (bubbleId == null) {
            // First chunk: create the assistant bubble so text appears ASAP.
            bubbleId = 'ai-${DateTime.now().microsecondsSinceEpoch}';
            historyNotifier.add(
              ChatMessage(
                id: bubbleId,
                sender: 'ai',
                text: delta,
                timestamp: DateTime.now(),
                assistantMode: modeName,
              ),
            );
            // Stop the typing dots: the response is now visible.
            state = AiChatSendState(streaming: true, pendingUserText: text);
          } else {
            // Subsequent chunks: grow the same bubble in place.
            final id = bubbleId;
            historyNotifier.updateLast(
              (m) => ChatMessage(
                id: id,
                sender: 'ai',
                text: streamedText,
                timestamp: m.timestamp,
                assistantMode: m.assistantMode,
                recommended: m.recommended,
              ),
            );
          }
        }

        if (chunk.done) {
          streamedMovies.addAll(chunk.movies);
        }
      }

      // 5. Finalize the streamed message.
      if (cancelToken.isCancelled) return;

      if (bubbleId != null && streamedText.trim().isNotEmpty) {
        historyNotifier.updateLast(
          (m) => ChatMessage(
            id: bubbleId!,
            sender: 'ai',
            text: streamedText.trim(),
            timestamp: m.timestamp,
            assistantMode: m.assistantMode,
            recommended:
                streamedMovies.isEmpty ? null : List.of(streamedMovies),
          ),
        );
        historyNotifier.persistNow();
      } else if (streamedText.trim().isEmpty) {
        throw const AiServiceException(AiErrorKind.empty);
      }

      debugPrint('[MovieGPT AI] stream completed (${streamedText.length} chars)');
      state = const AiChatSendState();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // Request was cancelled (e.g. assistant switched): discard silently.
        state = const AiChatSendState();
        return;
      }
      debugPrint('[MovieGPT AI] streaming failed: ${e.message}');
      _fail(mode, const AiServiceException(AiErrorKind.unknown).friendlyMessage);
    } on AiServiceException catch (e) {
      debugPrint('[MovieGPT AI] send failed — kind=${e.kind.name}'
          '${e.debugDetail != null ? ", detail=${e.debugDetail}" : ""}');
      if (streamedText.isNotEmpty) {
        // Keep the partial real text that streamed before the failure.
        historyNotifier.persistNow();
        state = const AiChatSendState();
      } else {
        _fail(mode, e.friendlyMessage);
      }
    } catch (e, st) {
      // Log the full error + stack so the real cause is always visible in the
      // console during development — do NOT swallow it silently.
      debugPrint('[MovieGPT AI] unexpected send failure: $e');
      debugPrint('[MovieGPT AI] stack trace:\n$st');
      if (streamedText.isNotEmpty) {
        historyNotifier.persistNow();
        state = const AiChatSendState();
      } else {
        _fail(mode, const AiServiceException(AiErrorKind.unknown).friendlyMessage);
      }
    }
  }

  /// Cancels the in-flight request and resets the send state. Used when the
  /// user switches assistant modes so the previous chat can never leak into
  /// the new session.
  void cancel() {
    final token = _cancelToken;
    _cancelToken = null;
    if (token != null && !token.isCancelled) {
      token.cancel();
      debugPrint('[CHAT] Cancelled in-flight AI request.');
    }
    state = const AiChatSendState();
  }
/// Retries the last failed message. Removes the stale error bubble AND the
  /// original user message of the failed attempt first, so the re-send does
  /// not duplicate either of them.
  Future<void> retry() async {
    final pending = state.pendingUserText;
    if (pending == null || _isBusy) return;

    final notifier = ref.read(chatHistoryProvider.notifier);
    final history = ref.read(chatHistoryProvider);
    if (history.isNotEmpty && history.last.isError) {
      notifier.removeLast();
    }
    final afterError = ref.read(chatHistoryProvider);
    if (afterError.isNotEmpty &&
        afterError.last.sender == 'user' &&
        afterError.last.text == pending) {
      notifier.removeLast();
    }
    await send(pending);
  }

  /// Appends an honest error/notice bubble (never a fake AI reply).
  void _fail(AiMode mode, String message) {
    ref.read(chatHistoryProvider.notifier).add(
          ChatMessage(
            id: 'ai-error-${DateTime.now().microsecondsSinceEpoch}',
            sender: 'ai',
            text: message,
            timestamp: DateTime.now(),
            assistantMode: AiPersonalities.modeToName(mode),
            isError: true,
          ),
        );
    // Keep the pending text so the UI can offer a retry.
    state = AiChatSendState(
      isTyping: false,
      pendingUserText: state.pendingUserText,
    );
  }

  /// Maps persisted chat messages into LLM turns.
  ///
  /// Excluded: the static welcome bubble, error/notice bubbles (they are not
  /// conversation content) and anything beyond the last [_maxHistoryTurns]
  /// entries. The latest user message is always the final turn.
  List<AiChatTurn> _conversationTurns(List<ChatMessage> messages) {
    final turns = <AiChatTurn>[];
    for (final message in messages) {
      if (message.id == 'welcome') continue;
      if (message.isError) continue;
      if (message.text.trim().isEmpty) continue;
      turns.add(
        AiChatTurn(
          role: message.sender == 'user' ? 'user' : 'assistant',
          content: message.text.trim(),
        ),
      );
    }
    if (turns.length > _maxHistoryTurns) {
      return turns.sublist(turns.length - _maxHistoryTurns);
    }
    return turns;
  }
}

/// Provider for the chat send orchestration.
final aiChatSendProvider =
    NotifierProvider<AiChatSendNotifier, AiChatSendState>(
  AiChatSendNotifier.new,
);