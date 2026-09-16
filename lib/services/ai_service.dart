import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env_config.dart';
import '../models/movie_model.dart';

/// Which LLM backend a request should use.
enum AiProvider { gemini, openAiCompatible }

/// Typed failure kinds surfaced by the AI service so the UI can show an
/// honest, useful message (never a fake "AI" reply).
enum AiErrorKind {
  notConfigured,
  offline,
  timeout,
  auth,
  rateLimit,
  dailyQuota,
  server,
  badResponse,
  empty,
  unknown,
}

/// A typed, user-friendly error from the AI layer.
class AiServiceException implements Exception {
  final AiErrorKind kind;
  final String? debugDetail;

  const AiServiceException(this.kind, [this.debugDetail]);

  /// Honest, actionable copy shown to the user. Never impersonates an AI reply.
  String get friendlyMessage {
    switch (kind) {
      case AiErrorKind.notConfigured:
        return "MovieGPT's AI chat is not configured. Please add your API key "
            'to the configuration.';
      case AiErrorKind.offline:
        return 'Please check your internet connection and try again.';
      case AiErrorKind.timeout:
        return 'The AI request took too long. Please try again.';
      case AiErrorKind.auth:
        return 'Gemini authentication failed. Please check your Gemini API key and Google AI configuration.';
      case AiErrorKind.rateLimit:
        return 'Gemini rate limit reached. Please try again shortly.';
      case AiErrorKind.dailyQuota:
        return "Gemini's daily AI usage limit has been reached. Please try "
            'again later.';
      case AiErrorKind.server:
        return 'Gemini is temporarily unavailable. Please try again.';
      case AiErrorKind.badResponse:
        if (debugDetail != null && debugDetail!.contains('404')) {
          return 'Gemini model or endpoint not found. Check the configured model name.';
        }
        if (debugDetail != null && debugDetail!.contains('400')) {
          return 'Gemini rejected the request. Check the request configuration.';
        }
        return debugDetail ??
            'Gemini is temporarily unavailable due to an API usage limit '
                'or resource limit.';
      case AiErrorKind.empty:
        return 'The AI returned an empty response. Please try again.';
      case AiErrorKind.unknown:
        return "Sorry, I couldn't connect right now. Please try again.";
    }
  }

  @override
  String toString() =>
      'AiServiceException(${kind.name}${debugDetail == null ? '' : ': $debugDetail'})';
}

/// One turn of the conversation. `role` is `'user'` or `'assistant'`.
class AiChatTurn {
  final String role;
  final String content;

  const AiChatTurn({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// A tool the model may call to fetch REAL data (TMDb / watchlist).
/// [parameters] is a JSON-Schema subset (lowercase types) compatible with the
/// OpenAI tool format; it is converted for Gemini automatically.
class AiToolSpec {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const AiToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });
}

/// The outcome of a tool invocation: a JSON payload handed back to the model,
/// plus any movies the chat UI should render as cards.
class AiToolResult {
  final Map<String, dynamic> payload;
  final List<Movie> movies;

  const AiToolResult(this.payload, {this.movies = const []});
}

/// The final completion: assistant text + movies surfaced from tool results.
class AiCompletion {
  final String text;
  final List<Movie> movies;

  const AiCompletion(this.text, {this.movies = const []});
}

/// One streamed piece of an AI response.
///
/// * [delta] is the incremental text received since the previous chunk
///   (may be empty for bookkeeping chunks).
/// * [done] marks the end of the stream; [movies] carries any movie cards
///   produced by tool calls and is only populated on the final chunk.
class AiStreamChunk {
  final String delta;
  final bool done;
  final List<Movie> movies;

  const AiStreamChunk(this.delta, {this.done = false, this.movies = const []});
}

/// Abstraction over the LLM backend so the chat state can be tested with a
/// fake client.
abstract class AiClient {
  bool get isConfigured;
  String get providerName;

  Future<AiCompletion> complete({
    required String systemPrompt,
    required List<AiChatTurn> history,
    List<AiToolSpec> tools,
    Future<AiToolResult> Function(String toolName, Map<String, dynamic> args)?
        onToolCall,
    int maxToolRounds,
  });

  /// Streaming variant of [complete].
  ///
  /// Yields text deltas as soon as the provider produces them so the UI can
  /// render the response progressively instead of waiting for the whole
  /// completion. The default implementation falls back to a single
  /// [complete] round-trip (used by fakes and providers without streaming
  /// support), which keeps the UI contract identical.
  Stream<AiStreamChunk> streamComplete({
    required String systemPrompt,
    required List<AiChatTurn> history,
    List<AiToolSpec> tools = const [],
    Future<AiToolResult> Function(String toolName, Map<String, dynamic> args)?
        onToolCall,
    int maxToolRounds = 3,
    CancelToken? cancelToken,
  }) async* {
    final completion = await complete(
      systemPrompt: systemPrompt,
      history: history,
      tools: tools,
      onToolCall: onToolCall,
      maxToolRounds: maxToolRounds,
    );
    yield AiStreamChunk(
      completion.text,
      done: true,
      movies: completion.movies,
    );
  }
}

/// Real AI conversation backend for MovieGPT.
///
/// Supports:
///  * **Google Gemini** (`GEMINI_API_KEY`, default model `gemini-2.0-flash`)
///  * **Any OpenAI-compatible API** (`OPENAI_API_KEY` + optional
///    `OPENAI_BASE_URL` / `OPENAI_MODEL`) — OpenAI, Groq, OpenRouter, etc.
///
/// Every request contains the system prompt plus bounded conversation history,
/// so follow-ups ("it", "yes", "the second one") are resolved from real
/// context. Optional function calling lets the model fetch live TMDb data
/// instead of guessing.
///
/// **Security:** API keys are sent via headers (never query strings) and are
/// never written to logs.
class AiService implements AiClient {
  AiService({Dio? dio}) : _dio = dio ?? _createDio();

  final Dio _dio;

  static Dio _createDio() {
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 45),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    // Minimal logging that can never leak secrets (no headers, no body, no
    // API key).  Logs the HTTP method, path, status code, and error details.
    if (kDebugMode) {
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final via = EnvConfig.useAiBackend
                ? ' (via backend: ${_redactBackendUrl(EnvConfig.aiBackendUrl)})'
                : '';
            
            // Redact 'key' query parameter if present to never log the API key.
            final uriString = options.uri.toString();
            final redactedUri = uriString.replaceAll(RegExp(r'key=[^&]+'), 'key=***');
            
            debugPrint('[AI] -> ${options.method} $redactedUri$via');
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint('[AI] <- HTTP ${response.statusCode}');
            handler.next(response);
          },
          onError: (error, handler) {
            final status = error.response?.statusCode;
            final reason = error.message ?? error.error?.toString() ?? 'unknown';
            debugPrint('[AI] ✗ error: status=$status, reason=$reason');
            // Surface the AI API's own error message (safe to print — it never
            // contains the key itself, only a message like "API key not valid").
            if (error.response?.data != null && error.response?.data is Map) {
              final data = error.response!.data as Map;
              final err = data['error'];
              if (err is Map) {
                final msg = err['message'];
                if (msg != null && msg is String && msg.isNotEmpty) {
                  debugPrint('[AI] ✗ API error message: $msg');
                }
              }
            }
            handler.next(error);
          },
        ),
      );
    }
    return client;
  }

  /// Returns a shortened, non-sensitive representation of the backend URL
  /// for debug logs (strips query params and keeps only the host).
  static String _redactBackendUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.host}${uri.path}';
    } catch (_) {
      return '<invalid-url>';
    }
  }

  // -- Provider resolution ---------------------------------------------------

  AiProvider? get _resolvedProvider {
    // When using the secure backend proxy, no client-side API key is needed.
    // The provider preference (gemini vs openai) is forwarded to the backend
    // so it knows which API key to use.
    if (EnvConfig.useAiBackend) {
      debugPrint('[AI] Using backend proxy: ${EnvConfig.aiBackendUrl}');
      switch (EnvConfig.aiProvider) {
        case 'openai':
          return AiProvider.openAiCompatible;
        case 'gemini':
        default:
          return AiProvider.gemini;
      }
    }
    // Direct API: require a client-side key.
    final providerPref = EnvConfig.aiProvider.trim().toLowerCase();
    switch (providerPref) {
      case 'gemini':
        final key = EnvConfig.geminiApiKey;
        final isConfigured = key.isNotEmpty;
        if (kDebugMode) {
          debugPrint('[AI] Provider: Gemini');
          debugPrint('[AI] Model: ${EnvConfig.geminiModel}');
          debugPrint('[AI] Gemini API key configured: $isConfigured');
          debugPrint('[AI] Backend mode: ${EnvConfig.useAiBackend}');
        }
        if (!isConfigured) return null;
        return AiProvider.gemini;
      case 'openai':
        if (EnvConfig.openAiApiKey.isEmpty) {
          debugPrint('[AI] OpenAI selected but OPENAI_API_KEY is empty.');
          return null;
        }
        return AiProvider.openAiCompatible;
      default:
        if (EnvConfig.geminiApiKey.isNotEmpty) return AiProvider.gemini;
        if (EnvConfig.openAiApiKey.isNotEmpty) {
          return AiProvider.openAiCompatible;
        }
        debugPrint('[AI] No AI provider configured (GEMINI_API_KEY and OPENAI_API_KEY are empty).');
        return null;
    }
  }

  @override
  bool get isConfigured => _resolvedProvider != null;

  @override
  String get providerName {
    final suffix = EnvConfig.useAiBackend ? ' (via backend)' : '';
    switch (_resolvedProvider) {
      case AiProvider.gemini:
        return 'Google Gemini (${EnvConfig.geminiModel})$suffix';
      case AiProvider.openAiCompatible:
        return 'OpenAI-compatible (${EnvConfig.openAiModel})$suffix';
      default:
        return 'not configured';
    }
  }

  @override
  Future<AiCompletion> complete({
    required String systemPrompt,
    required List<AiChatTurn> history,
    List<AiToolSpec> tools = const [],
    Future<AiToolResult> Function(
      String toolName,
      Map<String, dynamic> args,
    )? onToolCall,
    int maxToolRounds = 3,
  }) async {
    final provider = _resolvedProvider;

    if (provider == null) {
      debugPrint(
        '[AI] Not configured — no AI backend or API key available.',
      );
      throw const AiServiceException(AiErrorKind.notConfigured);
    }

    if (history.isEmpty) {
      debugPrint(
        '[AI] Empty history — cannot complete request.',
      );
      throw const AiServiceException(
        AiErrorKind.badResponse,
        'empty history',
      );
    }

    debugPrint(
      '[AI] Request started: provider=$provider(${provider.name}), '
      '${EnvConfig.useAiBackend ? "backend proxy" : "direct API"}, '
      '${history.length} turns, ${tools.length} tools',
    );

    if (kDebugMode && provider == AiProvider.gemini) {
      debugPrint('[AI] Gemini Diagnostics:');
      debugPrint('  - Model: ${EnvConfig.geminiModel}');
    }

    switch (provider) {
      case AiProvider.gemini:
        return _completeGemini(
          systemPrompt: systemPrompt,
          history: history,
          tools: tools,
          onToolCall: onToolCall,
          maxToolRounds: maxToolRounds,
        );

      case AiProvider.openAiCompatible:
        return _completeOpenAi(
          systemPrompt: systemPrompt,
          history: history,
          tools: tools,
          onToolCall: onToolCall,
          maxToolRounds: maxToolRounds,
        );
    }
  }
  // -- Streaming -------------------------------------------------------------

  /// Streaming is the default path for chat sends: text deltas are yielded as
  /// soon as the provider emits them so the UI shows the reply progressively.
  @override
  Stream<AiStreamChunk> streamComplete({
    required String systemPrompt,
    required List<AiChatTurn> history,
    List<AiToolSpec> tools = const [],
    Future<AiToolResult> Function(String, Map<String, dynamic>)? onToolCall,
    int maxToolRounds = 3,
    CancelToken? cancelToken,
  }) async* {
    final provider = _resolvedProvider;

    if (provider == null) {
      debugPrint('[AI] Not configured - no AI backend or API key available.');
      throw const AiServiceException(AiErrorKind.notConfigured);
    }
    if (history.isEmpty) {
      throw const AiServiceException(AiErrorKind.badResponse, 'empty history');
    }

    debugPrint(
      '[AI] Stream request started: provider=${provider.name}, '
      '${history.length} turns, ${tools.length} tools',
    );

    if (kDebugMode && provider == AiProvider.gemini) {
      debugPrint('[AI] Gemini Stream Diagnostics:');
      debugPrint('  - Model: ${EnvConfig.geminiModel}');
    }

    switch (provider) {
      case AiProvider.gemini:
        yield* _streamGemini(
          systemPrompt: systemPrompt,
          history: history,
          tools: tools,
          onToolCall: onToolCall,
          maxToolRounds: maxToolRounds,
          cancelToken: cancelToken,
        );
        break;
      case AiProvider.openAiCompatible:
        // OpenAI-compatible endpoints: stream plain-text replies; tool flows
        // keep the reliable non-streaming path.
        if (tools.isNotEmpty && onToolCall != null) {
          final completion = await complete(
            systemPrompt: systemPrompt,
            history: history,
            tools: tools,
            onToolCall: onToolCall,
            maxToolRounds: maxToolRounds,
          );
          debugPrint(
            '[AI] Response completed (non-streamed tool flow)',
          );
          yield AiStreamChunk(
            completion.text,
            done: true,
            movies: completion.movies,
          );
          return;
        }
        yield* _streamOpenAi(
          systemPrompt: systemPrompt,
          history: history,
          cancelToken: cancelToken,
        );
        break;
    }
  }

  /// Retries a request with exponential backoff or the specified retry delay.
  Future<Response<T>> _withRetry<T>(
    Future<Response<T>> Function() request, {
    int maxRetries = 2,
  }) async {
    int attempts = 0;
    while (true) {
      try {
        if (kDebugMode) debugPrint('[AI] Gemini request started');
        final res = await request();
        if (kDebugMode) debugPrint('[AI] Gemini response: HTTP ${res.statusCode}');
        return res;
      } on DioException catch (e) {
        attempts++;
        final status = e.response?.statusCode ?? 0;
        if (kDebugMode) debugPrint('[AI] Gemini response: HTTP $status');
        
        final isTransient = status == 500 || status == 502 || status == 503 || status == 504 || status == 408;
        final isRateLimit = status == 429;

        // Determine if this 429 is a daily quota exhaustion (don't retry).
        bool isDailyQuota = false;
        if (isRateLimit && e.response?.data != null && e.response?.data is Map) {
          final data = e.response!.data as Map;
          final msg = data['error']?['message']?.toString().toLowerCase() ?? '';
          if (msg.contains('quota exceeded') && (msg.contains('day') || msg.contains('daily'))) {
            isDailyQuota = true;
          }
        }

        if ((isTransient || (isRateLimit && !isDailyQuota)) && attempts <= maxRetries) {
          Duration delay;
          if (isRateLimit) {
            // Attempt to extract Gemini's retryDelay (e.g. "37s" or "37.5s").
            delay = _extractRetryDelay(e) ?? Duration(seconds: pow(2, attempts).toInt());
            // Add jitter
            final jitter = Random().nextInt(1000);
            delay += Duration(milliseconds: jitter);
            
            debugPrint('[AI] Rate limit hit (429), waiting ${delay.inSeconds}s before retry $attempts/$maxRetries...');
          } else {
            delay = Duration(seconds: attempts);
            debugPrint('[AI] Transient error $status, retrying in ${delay.inSeconds}s ($attempts/$maxRetries)...');
          }
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
  }

  Duration? _extractRetryDelay(DioException e) {
    try {
      if (e.response?.data is Map) {
        final data = e.response!.data as Map;
        final details = data['error']?['details'];
        if (details is List) {
          for (final d in details) {
            if (d is Map && d['retryDelay'] != null) {
              final raw = d['retryDelay'].toString();
              // Format: "37s" or "37.5s"
              final seconds = double.tryParse(raw.replaceAll('s', ''));
              if (seconds != null) {
                return Duration(milliseconds: (seconds * 1000).toInt());
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Streams a Gemini response via the SSE endpoint
  /// (`:streamGenerateContent?alt=sse`), yielding text deltas as they arrive.
  /// Tool calls are supported: when the model emits function calls, the tools
  /// run and the next round is streamed with the tool results appended.
  Stream<AiStreamChunk> _streamGemini({
    required String systemPrompt,
    required List<AiChatTurn> history,
    required List<AiToolSpec> tools,
    required Future<AiToolResult> Function(String, Map<String, dynamic>)?
        onToolCall,
    required int maxToolRounds,
    CancelToken? cancelToken,
  }) async* {
    final model = EnvConfig.geminiModel;
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse';

    if (kDebugMode) {
      debugPrint('[AI] Gemini endpoint: generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse');
    }

    final contents = <Map<String, dynamic>>[
      for (final turn in history)
        {
          'role': turn.role == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': turn.content},
          ],
        },
    ];

    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.8,
        'topP': 0.95,
        'maxOutputTokens': 768,
      },
    };
    if (tools.isNotEmpty && onToolCall != null) {
      body['tools'] = [
        {
          'functionDeclarations': tools.map(_geminiToolDeclaration).toList(),
        },
      ];
    }

    final movies = <Movie>[];
    var rounds = 0;
    final stopwatch = Stopwatch()..start();
    var firstTokenLogged = false;

    while (true) {
      final Response<ResponseBody> response;
      try {
        response = await _withRetry(
          () => _dio.post<ResponseBody>(
            url,
            data: body,
            options: Options(
              responseType: ResponseType.stream,
              headers: {
                'x-goog-api-key': EnvConfig.geminiApiKey,
                'Content-Type': 'application/json',
              },
            ),
            cancelToken: cancelToken,
          ),
        );
      } on DioException catch (e) {
        throw _mapDioError(e, 'Gemini');
      }

      var roundText = '';
      final functionCalls = <Map<String, dynamic>>[];
      final rawParts = <Map<String, dynamic>>[];

      // Parse the SSE stream incrementally. Frames are separated by a blank
      // line and each payload line looks like `data: {json}`. The buffer
      // carries partial frames across network chunks.
      var sseBuffer = '';
      await for (final bytes in response.data!.stream) {
        sseBuffer += utf8.decode(bytes, allowMalformed: true);
        sseBuffer = sseBuffer.replaceAll('\r\n', '\n');
        while (true) {
          final idx = sseBuffer.indexOf('\n\n');
          if (idx == -1) break;
          final frame = sseBuffer.substring(0, idx);
          sseBuffer = sseBuffer.substring(idx + 2);
          final line = frame.trim();
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload.isEmpty || payload == '[DONE]') continue;

          Map<String, dynamic>? event;
          try {
            final decoded = jsonDecode(payload);
            if (decoded is Map) {
              event = decoded.map((k, v) => MapEntry(k.toString(), v));
            }
          } catch (_) {
            continue;
          }
          if (event == null) continue;

          final candidates = event['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) continue;
          final candidate = candidates.first as Map;
          final content = candidate['content'] as Map?;
          final parts = (content?['parts'] as List?) ?? const [];
          for (final rawPart in parts) {
            if (rawPart is! Map) continue;
            final part = rawPart.map((k, v) => MapEntry(k.toString(), v));
            rawParts.add(part);
            // Internal "thought" summary parts are never user-facing text.
            if (part['thought'] == true) continue;
            final partText = part['text']?.toString();
            if (partText != null && partText.isNotEmpty) {
              roundText += partText;
              if (!firstTokenLogged) {
                firstTokenLogged = true;
                debugPrint(
                  '[AI] First token received after '
                  '${stopwatch.elapsedMilliseconds} ms',
                );
              }
              yield AiStreamChunk(partText);
            }
            final call = part['functionCall'];
            if (call is Map) {
              functionCalls
                  .add(call.map((k, v) => MapEntry(k.toString(), v)));
            }
          }
        }
      }

      // No tool calls -> the streamed text is the final answer.
      if (functionCalls.isEmpty || onToolCall == null) {
        final cleaned = _cleanText(roundText);
        if (cleaned.isEmpty && movies.isEmpty) {
          throw const AiServiceException(AiErrorKind.empty);
        }
        debugPrint(
          '[AI] Response completed in ${stopwatch.elapsedMilliseconds} ms',
        );
        yield AiStreamChunk('', done: true, movies: movies);
        return;
      }

      // Tool round: echo the model's call parts, then the function responses.
      rounds += 1;
      contents.add({'role': 'model', 'parts': rawParts});

      final responseParts = <Map<String, dynamic>>[];
      for (final call in functionCalls) {
        final name = call['name']?.toString() ?? '';
        final rawArgs = call['args'];
        final args = rawArgs is Map
            ? rawArgs.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};

        try {
          final result = await onToolCall(name, args);
          movies.addAll(result.movies);
          responseParts.add({
            'functionResponse': {'name': name, 'response': result.payload},
          });
        } on AiServiceException {
          rethrow;
        } catch (e) {
          responseParts.add({
            'functionResponse': {
              'name': name,
              'response': {'error': 'Tool "$name" failed: ${e.toString()}'},
            },
          });
        }
      }
      contents.add({'role': 'user', 'parts': responseParts});

      if (rounds >= maxToolRounds) {
        final cleaned = _cleanText(roundText);
        if (cleaned.isNotEmpty) {
          debugPrint(
            '[AI] Response completed in ${stopwatch.elapsedMilliseconds} ms '
            '(tool loop exhausted)',
          );
          yield AiStreamChunk('', done: true, movies: movies);
          return;
        }
        throw const AiServiceException(
          AiErrorKind.badResponse,
          'tool loop exhausted',
        );
      }
    }
  }

  /// Streams an OpenAI-compatible response (plain text only; tool flows use
  /// the non-streaming [complete] path).
  Stream<AiStreamChunk> _streamOpenAi({
    required String systemPrompt,
    required List<AiChatTurn> history,
    CancelToken? cancelToken,
  }) async* {
    final url = '${EnvConfig.openAiBaseUrl}/chat/completions';

    final body = <String, dynamic>{
      'model': EnvConfig.openAiModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        for (final turn in history)
          {'role': turn.role, 'content': turn.content},
      ],
      'temperature': 0.8,
      'max_tokens': 768,
      'stream': true,
    };

    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        url,
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Authorization': 'Bearer ${EnvConfig.openAiApiKey}'},
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapDioError(e, EnvConfig.openAiBaseUrl);
    }

    final stopwatch = Stopwatch()..start();
    var firstTokenLogged = false;
    var text = '';
    var sseBuffer = '';

    await for (final bytes in response.data!.stream) {
      sseBuffer += utf8.decode(bytes, allowMalformed: true);
      sseBuffer = sseBuffer.replaceAll('\r\n', '\n');
      while (true) {
        final idx = sseBuffer.indexOf('\n\n');
        if (idx == -1) break;
        final frame = sseBuffer.substring(0, idx);
        sseBuffer = sseBuffer.substring(idx + 2);
        final line = frame.trim();
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') continue;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is! Map) continue;
          final choices = decoded['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final delta = (choices.first as Map)['delta'];
          if (delta is! Map) continue;
          final piece = delta['content']?.toString() ?? '';
          if (piece.isNotEmpty) {
            text += piece;
            if (!firstTokenLogged) {
              firstTokenLogged = true;
              debugPrint(
                '[AI] First token received after '
                '${stopwatch.elapsedMilliseconds} ms',
              );
            }
            yield AiStreamChunk(piece);
          }
        } catch (_) {
          continue;
        }
      }
    }

    final cleaned = _cleanText(text);
    if (cleaned.isEmpty) {
      throw const AiServiceException(AiErrorKind.empty);
    }
    debugPrint(
      '[AI] Response completed in ${stopwatch.elapsedMilliseconds} ms',
    );
    yield AiStreamChunk('', done: true);
  }
  // -- Google Gemini ---------------------------------------------------------

  Future<AiCompletion> _completeGemini({
    required String systemPrompt,
    required List<AiChatTurn> history,
    required List<AiToolSpec> tools,
    required Future<AiToolResult> Function(String, Map<String, dynamic>)?
        onToolCall,
    required int maxToolRounds,
  }) async {
    final model = EnvConfig.geminiModel;
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

    if (kDebugMode) {
      debugPrint('[AI] Gemini endpoint: generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    }

    final contents = <Map<String, dynamic>>[
      for (final turn in history)
        {
          'role': turn.role == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': turn.content},
          ],
        },
    ];

    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.85,
        'topP': 0.95,
        'maxOutputTokens': 1024,
      },
    };
    if (tools.isNotEmpty && onToolCall != null) {
      body['tools'] = [
        {
          'functionDeclarations': tools.map(_geminiToolDeclaration).toList(),
        },
      ];
    }

    final movies = <Movie>[];
    var rounds = 0;

    while (true) {
      final Response<Map<String, dynamic>> response;
      try {
        response = await _withRetry(
          () => _dio.post<Map<String, dynamic>>(
            url,
            data: body,
            options: Options(
              headers: {
                'x-goog-api-key': EnvConfig.geminiApiKey,
                'Content-Type': 'application/json',
              },
            ),
          ),
        );
      } on DioException catch (e) {
        throw _mapDioError(e, 'Gemini');
      }

      final data = response.data;
      if (data == null) {
        throw const AiServiceException(AiErrorKind.badResponse);
      }
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        final block =
            (data['promptFeedback'] as Map?)?['blockReason']?.toString();
        throw AiServiceException(
          AiErrorKind.badResponse,
          block == null ? 'no candidates' : 'blocked: $block',
        );
      }

      final candidate = candidates.first as Map;
      final content = candidate['content'] as Map?;
      final parts = (content?['parts'] as List?) ?? const [];

      var text = '';
      final functionCalls = <Map<String, dynamic>>[];
      for (final rawPart in parts) {
        if (rawPart is! Map) continue;
        final partText = rawPart['text']?.toString();
        if (partText != null && partText.isNotEmpty) text += partText;
        final call = rawPart['functionCall'];
        if (call is Map) {
          functionCalls.add(call.map((k, v) => MapEntry(k.toString(), v)));
        }
      }

      // No tool calls — we have the final answer.
      if (functionCalls.isEmpty || onToolCall == null) {
        final cleaned = _cleanText(text);
        if (cleaned.isEmpty) {
          throw const AiServiceException(AiErrorKind.empty);
        }
        return AiCompletion(cleaned, movies: movies);
      }

      // Tool round: echo the model's call parts, then the function responses.
      rounds += 1;
      contents.add({
        'role': 'model',
        'parts': parts
            .whereType<Map>()
            .map((p) => p.map((k, v) => MapEntry(k.toString(), v)))
            .toList(),
      });

      final responseParts = <Map<String, dynamic>>[];
      for (final call in functionCalls) {
        final name = call['name']?.toString() ?? '';
        final rawArgs = call['args'];
        final args = rawArgs is Map
            ? rawArgs.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};

        try {
          final result = await onToolCall(name, args);
          movies.addAll(result.movies);
          responseParts.add({
            'functionResponse': {'name': name, 'response': result.payload},
          });
        } on AiServiceException {
          rethrow;
        } catch (e) {
          responseParts.add({
            'functionResponse': {
              'name': name,
              'response': {'error': 'Tool "$name" failed: ${e.toString()}'},
            },
          });
        }
      }
      contents.add({'role': 'user', 'parts': responseParts});

      if (rounds >= maxToolRounds) {
        final cleaned = _cleanText(text);
        if (cleaned.isNotEmpty) return AiCompletion(cleaned, movies: movies);
        throw const AiServiceException(
          AiErrorKind.badResponse,
          'tool loop exhausted',
        );
      }
    }
  }

  /// Converts a neutral JSON-schema subset into Gemini's function declaration
  /// format (UPPERCASE types).
  Map<String, dynamic> _geminiToolDeclaration(AiToolSpec spec) {
    return {
      'name': spec.name,
      'description': spec.description,
      'parameters': _geminiSchema(spec.parameters),
    };
  }

  Map<String, dynamic> _geminiSchema(Map<String, dynamic> schema) {
    final out = <String, dynamic>{};
    final type = schema['type'];
    if (type is String) out['type'] = type.toUpperCase();
    if (schema['description'] is String) {
      out['description'] = schema['description'];
    }
    if (schema['nullable'] == true) out['nullable'] = true;
    final props = schema['properties'];
    if (props is Map) {
      out['properties'] = props.map(
        (key, value) => MapEntry(
          key.toString(),
          value is Map
              ? _geminiSchema(
                  value.map((k, v) => MapEntry(k.toString(), v)))
              : <String, dynamic>{},
        ),
      );
    }
    final required = schema['required'];
    if (required is List) out['required'] = required;
    final items = schema['items'];
    if (items is Map) {
      out['items'] = _geminiSchema(items.map((k, v) => MapEntry(k.toString(), v)));
    }
    final enumValues = schema['enum'];
    if (enumValues is List) out['enum'] = enumValues;
    return out;
  }

  // -- OpenAI-compatible (OpenAI, Groq, OpenRouter, LM Studio, ...) ----------

  Future<AiCompletion> _completeOpenAi({
    required String systemPrompt,
    required List<AiChatTurn> history,
    required List<AiToolSpec> tools,
    required Future<AiToolResult> Function(String, Map<String, dynamic>)?
        onToolCall,
    required int maxToolRounds,
  }) async {
    final url = '${EnvConfig.openAiBaseUrl}/chat/completions';

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      for (final turn in history)
        {'role': turn.role, 'content': turn.content},
    ];

    final body = <String, dynamic>{
      'model': EnvConfig.openAiModel,
      'messages': messages,
      'temperature': 0.85,
      'max_tokens': 1024,
    };
    if (tools.isNotEmpty && onToolCall != null) {
      body['tools'] = [
        for (final tool in tools)
          {
            'type': 'function',
            'function': {
              'name': tool.name,
              'description': tool.description,
              'parameters': tool.parameters,
            },
          },
      ];
      body['tool_choice'] = 'auto';
    }

    final movies = <Movie>[];
    var rounds = 0;

    while (true) {
      final Response<Map<String, dynamic>> response;
      try {
        response = await _dio.post<Map<String, dynamic>>(
          url,
          data: body,
          options: Options(
            headers: {'Authorization': 'Bearer ${EnvConfig.openAiApiKey}'},
          ),
        );
      } on DioException catch (e) {
        throw _mapDioError(e, EnvConfig.openAiBaseUrl);
      }

      final data = response.data;
      final choices = data?['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw const AiServiceException(AiErrorKind.badResponse);
      }
      final message = (choices.first as Map)['message'];
      if (message is! Map) {
        throw const AiServiceException(AiErrorKind.badResponse);
      }

      final toolCalls = message['tool_calls'];
      final content = message['content']?.toString() ?? '';

      if (toolCalls is! List || toolCalls.isEmpty || onToolCall == null) {
        final cleaned = _cleanText(content);
        if (cleaned.isEmpty) {
          throw const AiServiceException(AiErrorKind.empty);
        }
        return AiCompletion(cleaned, movies: movies);
      }

      // Tool round: echo the assistant tool-call message, then tool results.
      rounds += 1;
      messages.add({
        'role': 'assistant',
        if (content.isNotEmpty) 'content': content,
        'tool_calls': toolCalls
            .whereType<Map>()
            .map((c) => c.map((k, v) => MapEntry(k.toString(), v)))
            .toList(),
      });

      for (final rawCall in toolCalls) {
        if (rawCall is! Map) continue;
        final call = rawCall.map((k, v) => MapEntry(k.toString(), v));
        final function = (call['function'] as Map?) ?? const {};
        final name = function['name']?.toString() ?? '';
        final callId = call['id']?.toString() ?? name;
        final rawArgs = function['arguments']?.toString() ?? '';

        var args = <String, dynamic>{};
        if (rawArgs.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawArgs);
            if (decoded is Map) {
              args = decoded.map((k, v) => MapEntry(k.toString(), v));
            }
          } catch (_) {
            args = <String, dynamic>{};
          }
        }

        Map<String, dynamic> payload;
        try {
          final result = await onToolCall(name, args);
          movies.addAll(result.movies);
          payload = result.payload;
        } on AiServiceException {
          rethrow;
        } catch (e) {
          payload = {'error': 'Tool "$name" failed: ${e.toString()}'};
        }
        messages.add({
          'role': 'tool',
          'tool_call_id': callId,
          'content': jsonEncode(payload),
        });
      }

      if (rounds >= maxToolRounds) {
        final cleaned = _cleanText(content);
        if (cleaned.isNotEmpty) return AiCompletion(cleaned, movies: movies);
        throw const AiServiceException(
          AiErrorKind.badResponse,
          'tool loop exhausted',
        );
      }
    }
  }

  // -- Helpers ---------------------------------------------------------------

  /// Maps transport/HTTP failures to typed errors.
  AiServiceException _mapDioError(DioException e, String endpoint) {
    final status = e.response?.statusCode ?? 0;
    String? detail;

    // Try to extract a more specific error message from the API response body.
    if (e.response?.data != null && e.response?.data is Map) {
      final data = e.response!.data as Map;
      final error = data['error'];
      if (error is Map) {
        detail = error['message']?.toString();
      }
    }

    if (kDebugMode) {
      debugPrint('[AI] Gemini HTTP status: $status');
      if (detail != null) debugPrint('[AI] Gemini error: $detail');
    }

    if (kDebugMode && status == 429) {
      debugPrint('--- GEMINI 429 DIAGNOSTIC ---');
      debugPrint('status: 429');
      debugPrint('code: RESOURCE_EXHAUSTED');
      
      String? quotaInfo;
      String? retryDelay;

      if (e.response?.data is Map) {
        final data = e.response!.data as Map;
        final error = data['error'];
        debugPrint('message: ${error?['message']}');
        
        final details = error?['details'];
        if (details is List) {
          for (final d in details) {
            if (d['retryDelay'] != null) {
              retryDelay = d['retryDelay'].toString();
            }
            final violations = d['violations'];
            if (violations is List) {
              for (final v in violations) {
                quotaInfo = '${v['quotaMetric']} (${v['quotaId']})';
                debugPrint('quota: $quotaInfo');
              }
            }
          }
        }
      }
      
      if (quotaInfo == null) {
        debugPrint('quota: Gemini returned 429 RESOURCE_EXHAUSTED without quota details.');
      }
      debugPrint('retryDelay: ${retryDelay ?? 'unknown'}');
      debugPrint('model: ${EnvConfig.geminiModel}');
      debugPrint('-----------------------------');
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AiServiceException(AiErrorKind.timeout);
      case DioExceptionType.connectionError:
        return const AiServiceException(AiErrorKind.offline);
      case DioExceptionType.badResponse:
        if (status == 400) {
          return AiServiceException(AiErrorKind.badResponse, detail ?? 'Invalid request');
        }
        if (status == 401 || status == 403) {
          return AiServiceException(AiErrorKind.auth, detail ?? 'API authentication failed');
        }
        if (status == 404) {
          return AiServiceException(
            AiErrorKind.badResponse,
            'The configured Gemini model (${EnvConfig.geminiModel}) or endpoint is unavailable. '
            'Please check the AI configuration.',
          );
        }
        if (status == 429) {
          final lowerDetail = detail?.toLowerCase() ?? '';
          final isDaily = lowerDetail.contains('quota exceeded') && 
                          (lowerDetail.contains('day') || lowerDetail.contains('daily'));
          
          if (isDaily) {
            return const AiServiceException(AiErrorKind.dailyQuota);
          }
          return AiServiceException(AiErrorKind.rateLimit, detail);
        }
        if (status >= 500) {
          return AiServiceException(AiErrorKind.server, detail ?? 'Server error ($status)');
        }
        return AiServiceException(
          AiErrorKind.badResponse,
          detail ?? '$endpoint status $status',
        );
      default:
        final msg = e.message ?? e.error?.toString() ?? '';
        final lower = msg.toLowerCase();
        final looksOffline = lower.contains('failed host lookup') ||
            lower.contains('socketexception') ||
            lower.contains('network is unreachable') ||
            lower.contains('connection refused') ||
            lower.contains('connection reset') ||
            lower.contains('internet');
        if (looksOffline) {
          return const AiServiceException(AiErrorKind.offline);
        }
        return AiServiceException(AiErrorKind.unknown, msg);
    }
  }

  /// Normalizes model output: trims, strips stray code fences and a leading
  /// "Assistant:" role prefix, and collapses excess blank lines.
  String _cleanText(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '')
          .replaceFirst(RegExp(r'```\s*$'), '')
          .trim();
    }
    text = text.replaceFirst(
      RegExp(r'^assistant\s*:\s*', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
