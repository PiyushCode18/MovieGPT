import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env_config.dart';

/// Centralized Dio HTTP client configured for the TMDB API.
class ApiClient {
  /// Primary TMDB API origin (documented base URL).
  static const String _primaryOrigin = 'https://api.themoviedb.org/3';

  /// TMDB's real alternate API hostname. Serves the identical v3 API and is
  /// used ONLY as a transparent fallback when the primary origin fails at the
  /// connection level (see the onError interceptor below).
  static const String _fallbackOrigin = 'https://api.tmdb.org/3';

  /// Extra key marking a request that already used the fallback host.
  static const String _kFallbackUsed = 'tmdb_fallback_used';

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.themoviedb.org/3',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
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
          options.queryParameters['api_key'] = EnvConfig.tmdbApiKey;
          handler.next(options);
        },
      ),
    );

    // Resilience: some networks / security software terminate the TLS
    // handshake to `api.themoviedb.org` specifically (verified on Windows:
    // connection reset right after the ClientHello, while other HTTPS hosts
    // on the same CloudFront IPs work fine). TMDB operates the identical v3
    // API on its real alternate hostname `api.tmdb.org` (same endpoints, same
    // key handling, valid TLS certificate). When the primary host fails at
    // the CONNECTION level (no HTTP response at all), the request is retried
    // ONCE against the fallback host. No data is ever faked: a fallback
    // response comes from the real TMDB API. Requests that already used the
    // fallback, or that received an actual HTTP response (401/404/429/5xx...),
    // are never retried here.
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) async {
          final opts = e.requestOptions;
          final alreadyUsed = opts.extra[_kFallbackUsed] == true;
          final isPrimaryHost = opts.baseUrl.startsWith(_primaryOrigin);
          // Connection-level failure = NO HTTP response came back at all.
          // NOTE: dio wraps TLS handshake failures (HandshakeException) as
          // DioExceptionType.unknown with the original error attached, so
          // `unknown` with a null response is included here on purpose.
          // On Web, e.error might be null even for network errors.
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
              'retrying once via fallback host api.tmdb.org',
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

