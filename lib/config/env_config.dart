import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central configuration for MovieGPT environment variables and API keys.
///
/// Values are resolved in this order:
/// 1. --dart-define=KEY=VALUE
/// 2. .env
///
/// API key values are never printed to the debug log.
class EnvConfig {
  EnvConfig._();

  // ---------------------------------------------------------------------------
  // COMPILE-TIME CONFIGURATION
  // ---------------------------------------------------------------------------

  static const String _tmdbKey =
      String.fromEnvironment('TMDB_API_KEY');

  static const String _geminiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  static const String _openAiKey =
      String.fromEnvironment('OPENAI_API_KEY');

  static const String _aiBackendUrl =
      String.fromEnvironment('AI_BACKEND_URL');

  static const String _geminiModel =
      String.fromEnvironment('GEMINI_MODEL');

  static const String _openAiBaseUrl =
      String.fromEnvironment('OPENAI_BASE_URL');

  static const String _openAiModel =
      String.fromEnvironment('OPENAI_MODEL');

  static const String _aiProvider =
      String.fromEnvironment('AI_PROVIDER');

  // ---------------------------------------------------------------------------
  // SUPABASE COMPILE-TIME CONFIGURATION
  // ---------------------------------------------------------------------------

  static const String _supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');

  static const String _supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  /// Removes whitespace and accidental surrounding quotes.
  static String _clean(String raw) {
    return raw
        .trim()
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll(';', ''); // Netlify variables sometimes have trailing chars
  }

  /// Resolves a value from --dart-define first, then .env.
  static String _resolve(
    String dartDefine,
    String name,
  ) {
    // 1. Try --dart-define (compile-time)
    final define = _clean(dartDefine);
    if (define.isNotEmpty && define != 'null') {
      return define;
    }

    // 2. Try flutter_dotenv (.env asset at runtime)
    String fromEnv = '';
    try {
      fromEnv = dotenv.get(name, fallback: '');
    } catch (_) {
      fromEnv = '';
    }

    return _clean(fromEnv);
  }

  // ---------------------------------------------------------------------------
  // TMDB
  // ---------------------------------------------------------------------------

  /// TMDB API key / Read Access Token.
  static String get tmdbApiKey =>
      _resolve(
        _tmdbKey,
        'TMDB_API_KEY',
      );

  static bool get hasApiKey =>
      tmdbApiKey.isNotEmpty;

  // ---------------------------------------------------------------------------
  // SUPABASE
  // ---------------------------------------------------------------------------

  /// Supabase project URL.
  ///
  /// Example:
  /// https://xxxxxxxxxxxx.supabase.co
  static String get supabaseUrl =>
      _resolve(
        _supabaseUrl,
        'SUPABASE_URL',
      );

  /// Supabase publishable/anon client key.
  ///
  /// IMPORTANT:
  /// Never put a Supabase service_role/secret key
  /// inside the Flutter application.
  static String get supabaseAnonKey =>
      _resolve(
        _supabaseAnonKey,
        'SUPABASE_ANON_KEY',
      );

  /// Whether Supabase has been configured.
  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;

  // ---------------------------------------------------------------------------
  // AI BACKEND
  // ---------------------------------------------------------------------------

  /// Optional server-side AI backend URL.
  ///
  /// This is optional for the current direct Gemini setup.
  static String get aiBackendUrl =>
      _resolve(
        _aiBackendUrl,
        'AI_BACKEND_URL',
      );

  /// Whether MovieGPT should use the AI backend.
  static bool get useAiBackend =>
      aiBackendUrl.isNotEmpty;

  // ---------------------------------------------------------------------------
  // GEMINI
  // ---------------------------------------------------------------------------

  /// Google Gemini API key.
  static String get geminiApiKey =>
      _resolve(
        _geminiKey,
        'GEMINI_API_KEY',
      );

  /// Gemini model.
  ///
  /// Default: gemini-3.6-flash
  static String get geminiModel {
    final model = _resolve(
      _geminiModel,
      'GEMINI_MODEL',
    );

    return model.isEmpty
        ? 'gemini-3.6-flash'
        : model;
  }

  // ---------------------------------------------------------------------------
  // OPENAI-COMPATIBLE PROVIDER
  // ---------------------------------------------------------------------------

  /// OpenAI-compatible API key.
  ///
  /// Can be used with OpenAI, Groq, OpenRouter,
  /// LM Studio, Ollama, etc.
  static String get openAiApiKey =>
      _resolve(
        _openAiKey,
        'OPENAI_API_KEY',
      );

  /// OpenAI-compatible base URL.
  static String get openAiBaseUrl {
    final raw = _resolve(
      _openAiBaseUrl,
      'OPENAI_BASE_URL',
    );

    final cleaned = _clean(raw);

    if (cleaned.isEmpty) {
      return 'https://api.openai.com/v1';
    }

    return cleaned.endsWith('/')
        ? cleaned.substring(
            0,
            cleaned.length - 1,
          )
        : cleaned;
  }

  /// OpenAI-compatible model.
  static String get openAiModel {
    final model = _resolve(
      _openAiModel,
      'OPENAI_MODEL',
    );

    return model.isEmpty
        ? 'gpt-4o-mini'
        : model;
  }

  // ---------------------------------------------------------------------------
  // AI PROVIDER
  // ---------------------------------------------------------------------------

  /// Supported values:
  ///
  /// auto
  /// gemini
  /// openai
  static String get aiProvider {
    final provider = _resolve(
      _aiProvider,
      'AI_PROVIDER',
    ).toLowerCase();

    return provider.isEmpty
        ? 'auto'
        : provider;
  }

  /// Whether Gemini is configured.
  static bool get hasGeminiConfig =>
      geminiApiKey.isNotEmpty;

  /// Whether OpenAI-compatible provider is configured.
  static bool get hasOpenAiConfig =>
      openAiApiKey.isNotEmpty;

  /// Whether any real AI configuration is available.
  static bool get hasAiConfig {
    if (useAiBackend) {
      return true;
    }

    switch (aiProvider) {
      case 'gemini':
        return hasGeminiConfig;

      case 'openai':
        return hasOpenAiConfig;

      case 'auto':
      default:
        return hasGeminiConfig ||
            hasOpenAiConfig;
    }
  }

  // ---------------------------------------------------------------------------
  // DEBUG INFORMATION
  // ---------------------------------------------------------------------------

  /// Prints configuration status without exposing secret values.
  static void debugPrintConfig() {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '[MovieGPT] TMDB configured: $hasApiKey',
    );

    debugPrint(
      '[MovieGPT] Supabase configured: $hasSupabaseConfig',
    );

    debugPrint(
      '[MovieGPT] Gemini configured: $hasGeminiConfig',
    );

    debugPrint(
      '[MovieGPT] OpenAI configured: $hasOpenAiConfig',
    );

    debugPrint(
      '[MovieGPT] AI provider: $aiProvider',
    );

    if (hasGeminiConfig) {
      debugPrint(
        '[MovieGPT] Gemini model: $geminiModel',
      );
    }

    if (useAiBackend) {
      debugPrint(
        '[MovieGPT] AI backend configured: true',
      );
    }
  }

  /// Shows a warning when AI isn't configured.
  static void debugWarnIfAiMissing() {
    if (kDebugMode && !hasAiConfig) {
      debugPrint(
        '[MovieGPT] AI chat is not configured.\n'
        'Add GEMINI_API_KEY to .env, or configure '
        'AI_BACKEND_URL.',
      );
    }
  }

  /// Shows a warning when Supabase isn't configured.
  static void debugWarnIfSupabaseMissing() {
    if (kDebugMode && !hasSupabaseConfig) {
      debugPrint(
        '[MovieGPT] Supabase is not configured.\n'
        'Check SUPABASE_URL and SUPABASE_ANON_KEY '
        'in .env.',
      );
    }
  }
}