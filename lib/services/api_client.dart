import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env_config.dart';

/// Centralized Dio HTTP client configured for the TMDB API.
class ApiClient {
  /// Primary TMDB API origin (official standard).
  static const String _primaryOrigin = 'https://api.themoviedb.org/3';

  /// alternate origin used as transparent fallback.
  static const String _fallbackOrigin = 'https://api.tmdb.org/3';

  /// Extra key marking a request that already used the fallback host.
  static const String _kFallbackUsed = 'tmdb_fallback_used';

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: _primaryOrigin,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 12),
        headers: {'Accept': 'application/json'},
      ),
    );

    // Guarantee the TMDB API key is merged into EVERY request's query
    // parameters. This is critical because Dio's per-request `queryParameters`
    // argument replaces the base `queryParameters` rather than merging them —
    // so without this interceptor the key could be silently dropped and every
    // call would return 401 ("Could Not Load").
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final apiKey = EnvConfig.tmdbApiKey;
          if (apiKey.isEmpty) {
            debugPrint('[MovieGPT] WARNING: TMDB API key is empty in interceptor.');
          }
          options.queryParameters['api_key'] = apiKey;
          handler.next(options);
        },
      ),
    );

    // Resilience: If the primary host fails at the CONNECTION level,
    // retry transparently against the fallback host.
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) async {
          final opts = e.requestOptions;
          final alreadyUsed = opts.extra[_kFallbackUsed] == true;
          final isPrimaryHost = opts.baseUrl.startsWith(_primaryOrigin);
          // Connection-level failure = NO HTTP response came back at all.
          final connectionLevelFailure = e.response == null &&
              (e.type == DioExceptionType.connectionError ||
                  e.type == DioExceptionType.connectionTimeout ||
                  e.type == DioExceptionType.unknown);

          if (!connectionLevelFailure || alreadyUsed || !isPrimaryHost) {
            handler.next(e);
            return;
          }

          if (kDebugMode) {
            debugPrint(
              '[MovieGPT] TMDB primary host unreachable (${e.type.name}) — '
              'retrying once via fallback host $_fallbackOrigin',
            );
          }
          try {
            final retryOptions = opts.copyWith(
              baseUrl: _fallbackOrigin,
              extra: {...opts.extra, _kFallbackUsed: true},
            );
            final response = await dio.fetch<dynamic>(retryOptions);
            handler.resolve(response);
          } on DioException catch (fallbackError) {
            if (kDebugMode) {
              debugPrint(
                '[MovieGPT] TMDB fallback host also failed: '
                '${fallbackError.type.name}',
              );
            }
            handler.next(e);
          }
        },
      ),
    );


    // Add a lightweight logging interceptor for debugging.
    // IMPORTANT: `logPrint` redacts the `api_key` before printing so the TMDB
    // key is never written to logs. The Dio `LogInterceptor` by default logs
    // the full request URI (including query params), which would otherwise
    // leak the API key.
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
        logPrint: (Object obj) {
          final line = obj.toString();
          // Redact any query param that looks like the API key.
          final redacted = line.replaceAllMapped(
            RegExp(r'api_key=[^&\s]+'),
            (_) => 'api_key=***',
          );
          debugPrint(redacted);
        },
      ),
    );
  }

  static final ApiClient _instance = ApiClient._internal();
  static ApiClient get instance => _instance;

  late final Dio dio;
}

