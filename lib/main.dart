import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env_config.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

/// Global Flutter error handling.
///
/// This catches Flutter framework errors and prevents the default
/// red error screen from appearing in release builds.
void _setupGlobalErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      debugPrint(
        'FlutterError: ${details.exceptionAsString()}',
      );

      if (details.stack != null) {
        debugPrint('Stack: ${details.stack}');
      }
    } else {
      debugPrint(
        '[MovieGPT] Uncaught Flutter error: '
        '${details.exceptionAsString()}',
      );
    }
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: AppTheme.bgDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.movie_creation_outlined,
                color: AppTheme.primaryRed,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'An unexpected error occurred. Please restart the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                Text(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  };
}

/// Application entry point.
Future<void> main() async {
  await runZonedGuarded(
    () async {
      // ------------------------------------------------------------
      // FLUTTER INITIALIZATION
      // ------------------------------------------------------------

      WidgetsFlutterBinding.ensureInitialized();

      // ------------------------------------------------------------
      // GLOBAL ERROR HANDLING
      // ------------------------------------------------------------

      _setupGlobalErrorHandling();

      // ------------------------------------------------------------
      // IMAGE CACHE
      // ------------------------------------------------------------

      final cache = PaintingBinding.instance.imageCache;

      cache.maximumSizeBytes = 100 * 1024 * 1024;
      cache.maximumSize = 2000;

      // ------------------------------------------------------------
      // LOAD ENVIRONMENT VARIABLES
      // ------------------------------------------------------------

      runApp(
        const ProviderScope(
          child: MovieGptApp(),
        ),
      );

      // Initialize dependencies in the background while Splash is animating.
      MovieGptApp.initFuture = _initializeDependencies();
    },
    (Object error, StackTrace stack) {
      debugPrint('[MovieGPT] Uncaught async error: $error');
      if (kDebugMode) debugPrint('$stack');
    },
  );
}

/// Handles all heavy startup initialization.
Future<void> _initializeDependencies() async {
  // 1. Load Environment Variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[MovieGPT] WARNING: Could not load .env: $e');
  }

  // 2. Diagnostics
  if (kDebugMode) {
    EnvConfig.debugPrintConfig();
  }

  // 3. Supabase Initialization
  if (EnvConfig.hasSupabaseConfig) {
    try {
      await Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        publishableKey: EnvConfig.supabaseAnonKey,
      );
      if (kDebugMode) {
        debugPrint('[MovieGPT] Supabase initialized successfully.');
      }
    } catch (e, stack) {
      debugPrint('[MovieGPT] Supabase initialization failed: $e');
      if (kDebugMode) debugPrint('$stack');
    }
  } else {
    debugPrint('[MovieGPT] ERROR: Supabase is not configured.');
  }
}

/// Main MovieGPT application.
class MovieGptApp extends StatelessWidget {
  const MovieGptApp({super.key});

  /// Stores the heavy initialization future.
  static Future<void>? initFuture;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MovieGPT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}