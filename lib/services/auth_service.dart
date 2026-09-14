import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

/// A typed, user-friendly error surfaced from the authentication layer.
class MovieGptAuthException implements Exception {
  final String message;

  const MovieGptAuthException(this.message);

  @override
  String toString() => message;
}

/// Result of a registration attempt.
class RegisterResult {
  final AppUser user;
  final bool sessionStarted;

  const RegisterResult({
    required this.user,
    required this.sessionStarted,
  });
}

/// Central authentication service for MovieGPT.
///
/// Authentication is handled entirely by Supabase Auth.
///
/// Supported:
/// - Email / Password
/// - Google OAuth
/// - Sign out
/// - Current user
/// - Authentication state changes
/// - Password reset
/// - Password update
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  bool _signInInProgress = false;

  bool get isSignInInProgress => _signInInProgress;

  // ============================================================
  // OAUTH REDIRECT
  // ============================================================

  /// Redirect URL used after Google authentication.
  ///
  /// IMPORTANT:
  /// Add this exact URL to:
  ///
  /// Supabase Dashboard
  /// → Authentication
  /// → URL Configuration
  /// → Redirect URLs
  ///
  /// For your production website:
  /// https://moviegpt.dev/auth/callback
  String get _redirectUrl {
    if (kIsWeb) {
      return 'https://moviegpt.dev/auth/callback';
    }

    // Android / iOS deep-link fallback.
    // Configure this deep link in the respective platform later
    // if you need native Google OAuth.
    return 'io.moviegpt.app://login-callback';
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  AppUser? get currentUser {
    final User? user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    return _appUserFromSupabase(user);
  }

  bool get isSignedIn => _supabase.auth.currentUser != null;

  // ============================================================
  // AUTH STATE
  // ============================================================

  Stream<AppUser?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      final User? user = session?.user;

      debugPrint(
        '[MovieGPT Auth] State changed: ${event.name} '
        '(Session: ${session != null}, User: ${user?.id})',
      );

      if (user == null || session == null) {
        return null;
      }

      return _appUserFromSupabase(user);
    });
  }

  // ============================================================
  // SUPABASE USER → MOVIEGPT USER
  // ============================================================

  AppUser _appUserFromSupabase(User user) {
    final Map<String, dynamic> metadata =
        user.userMetadata ?? <String, dynamic>{};

    final String? metadataDisplayName =
        metadata['display_name']?.toString();

    final String? metadataFullName =
        metadata['full_name']?.toString();

    final String? metadataName =
        metadata['name']?.toString();

    final String? avatarUrl =
        metadata['avatar_url']?.toString() ??
        metadata['picture']?.toString();

    String displayName =
        metadataDisplayName ??
        metadataFullName ??
        metadataName ??
        '';

    if (displayName.trim().isEmpty && user.email != null) {
      displayName = user.email!.split('@').first;
    }

    if (displayName.trim().isEmpty) {
      displayName = 'MovieGPT User';
    }

    return AppUser(
      uid: user.id,
      email: user.email ?? '',
      displayName: displayName,
      photoUrl: avatarUrl,
    );
  }

  // ============================================================
  // GOOGLE SIGN-IN
  // ============================================================

  /// Starts Google OAuth through Supabase.
  ///
  /// The actual authentication happens in the browser.
  /// Supabase then redirects back to [_redirectUrl].
  Future<void> signInWithGoogle() async {
    if (_signInInProgress) {
      throw const MovieGptAuthException(
        'Sign-in already in progress. Please wait.',
      );
    }

    _signInInProgress = true;

    try {
      debugPrint('[MovieGPT Auth] Starting Google OAuth...');

      final bool launched =
          await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _redirectUrl,
        authScreenLaunchMode:
            LaunchMode.externalApplication,
      );

      if (!launched) {
        throw const MovieGptAuthException(
          'Could not start Google sign-in.',
        );
      }

      debugPrint(
        '[MovieGPT Auth] Google OAuth started successfully.',
      );
    } on MovieGptAuthException {
      rethrow;
    } on AuthRetryableFetchException catch (e) {
      debugPrint(
        '[MovieGPT] Supabase Google Fetch Error (CORS?): $e',
      );

      throw const MovieGptAuthException(
        'Google sign-in connection failed. Please try again.',
      );
    } on AuthApiException catch (e) {
      debugPrint(
        '[MovieGPT] Supabase Google Sign-In Error: '
        '${e.code} - ${e.message}',
      );

      throw _mapSupabaseAuthException(e);
    } catch (e) {
      debugPrint(
        '[MovieGPT] Google Sign-In Error: $e',
      );

      throw const MovieGptAuthException(
        'Google sign-in failed. Please try again.',
      );
    } finally {
      _signInInProgress = false;
    }
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();

      debugPrint(
        '[MovieGPT] Supabase sign-out successful.',
      );
    } on AuthApiException catch (e) {
      debugPrint(
        '[MovieGPT] Supabase Sign-Out Error: '
        '${e.code} - ${e.message}',
      );

      throw _mapSupabaseAuthException(e);
    } catch (e) {
      debugPrint(
        '[MovieGPT] Supabase Sign-Out Error: $e',
      );

      throw const MovieGptAuthException(
        'Could not sign out. Please try again.',
      );
    }
  }

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  static bool isValidEmail(String email) {
    final String value = email.trim().toLowerCase();

    return RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$',
    ).hasMatch(value);
  }

  // ============================================================
  // PASSWORD VALIDATION
  // ============================================================

  /// Returns null when the password is valid.
  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Please enter a password.';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return 'Password must contain both letters and numbers.';
    }

    return null;
  }

  // ============================================================
  // EMAIL SIGN IN
  // ============================================================

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final String cleanEmail = email.trim().toLowerCase();
    final String cleanPassword = password; // DO NOT MODIFY PASSWORD

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      throw const MovieGptAuthException(
        'Please enter your email and password.',
      );
    }

    if (!isValidEmail(cleanEmail)) {
      throw const MovieGptAuthException(
        'Please enter a valid email address.',
      );
    }

    if (_signInInProgress) {
      throw const MovieGptAuthException(
        'Sign-in already in progress. Please wait.',
      );
    }

    _signInInProgress = true;

    try {
      debugPrint('[MovieGPT Auth] Starting email sign-in for: $cleanEmail');

      final AuthResponse response =
          await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPassword,
      );

      final User? user = response.user;
      final Session? session = response.session;

      if (user == null || session == null) {
        debugPrint('[MovieGPT Auth] Sign-in failed: No user or session.');
        throw const MovieGptAuthException(
          'Sign-in failed. Please check your email and password.',
        );
      }

      debugPrint('[MovieGPT Auth] Email sign-in successful. User ID: ${user.id}');
      return _appUserFromSupabase(user);
    } on MovieGptAuthException {
      rethrow;
    } on AuthRetryableFetchException catch (e) {
      debugPrint(
        '[MovieGPT] Supabase Email Fetch Error (CORS?): $e',
      );

      throw const MovieGptAuthException(
        'Connection failed. Please check your internet connection.',
      );
    } on AuthApiException catch (e) {
      debugPrint(
        '[MovieGPT] Supabase Email Sign-In Error: '
        '${e.code} - ${e.message}',
      );

      throw _mapSupabaseAuthException(e);
    } catch (e) {
      debugPrint(
        '[MovieGPT] Email Sign-In Error: $e',
      );

      throw const MovieGptAuthException(
        'Sign-in failed. Please check your connection and try again.',
      );
    } finally {
      _signInInProgress = false;
    }
  }

  // ============================================================
  // EMAIL REGISTRATION
  // ============================================================

  Future<RegisterResult> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final String cleanEmail = email.trim().toLowerCase();
    final String cleanPassword = password; // DO NOT MODIFY PASSWORD

    if (!isValidEmail(cleanEmail)) {
      throw const MovieGptAuthException(
        'Please enter a valid email address.',
      );
    }

    final String? passwordError =
        validatePassword(cleanPassword);

    if (passwordError != null) {
      throw MovieGptAuthException(passwordError);
    }

    try {
      debugPrint('[MovieGPT Auth] Starting email registration: $cleanEmail');

      final AuthResponse response =
          await _supabase.auth.signUp(
        email: cleanEmail,
        password: cleanPassword,
      );

      final User? user = response.user;

      if (user == null) {
        throw const MovieGptAuthException(
          'Could not create your account. Please try again.',
        );
      }

      // Check if user already exists (unconfirmed case).
      // If email confirmation is enabled, Supabase returns the user object
      // even if they exist but are unconfirmed.
      // For a truly new user, response.user.identities should be populated.
      final identities = user.identities ?? [];
      final bool isNewUser = identities.isNotEmpty;

      // Fallback: check createdAt vs now (within 10 seconds).
      final createdAtStr = user.createdAt;
      final createdAt = DateTime.tryParse(createdAtStr);
      final bool recentlyCreated = createdAt != null &&
          DateTime.now().difference(createdAt).inSeconds.abs() < 10;

      if (!isNewUser && !recentlyCreated && response.session == null) {
        debugPrint('[MovieGPT Auth] User already registered but unconfirmed.');
        throw const MovieGptAuthException(
          'This email is already registered. Please check your email to confirm your account or sign in.',
        );
      }

      final bool sessionStarted = response.session != null;

      if (!sessionStarted) {
        debugPrint(
          '[MovieGPT Auth] Registration successful. '
          'Email confirmation is required.',
        );
      } else {
        debugPrint('[MovieGPT Auth] Registration successful. Session started.');
      }

      return RegisterResult(
        user: _appUserFromSupabase(user),
        sessionStarted: sessionStarted,
      );
    } on MovieGptAuthException {
      rethrow;
    } on AuthRetryableFetchException catch (e) {
      debugPrint(
        '[MovieGPT] Supabase Registration Fetch Error (CORS?): $e',
      );

      throw const MovieGptAuthException(
        'Connection failed. Please check your internet connection.',
      );
    } on AuthApiException catch (e) {
      debugPrint(
        '[MovieGPT] Supabase Registration Error: '
        '${e.code} - ${e.message}',
      );

      throw _mapSupabaseAuthException(e);
    } catch (e) {
      debugPrint(
        '[MovieGPT] Email Registration Error: $e',
      );

      throw const MovieGptAuthException(
        'Could not create your account. '
        'Please check your connection and try again.',
      );
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> resetPassword(String email) async {
    final String cleanEmail = email.trim().toLowerCase();

    if (!isValidEmail(cleanEmail)) {
      throw const MovieGptAuthException(
        'Please enter a valid email address.',
      );
    }

    try {
      await _supabase.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo:
            'https://moviegpt.dev/reset-password',
      );

      debugPrint(
        '[MovieGPT] Password reset email requested.',
      );
    } on AuthRetryableFetchException catch (e) {
      debugPrint(
        '[MovieGPT] Supabase Password Reset Fetch Error: $e',
      );

      throw const MovieGptAuthException(
        'Connection failed. Please try again.',
      );
    } on AuthApiException catch (e) {
      debugPrint(
        '[MovieGPT] Supabase Password Reset Error: '
        '${e.code} - ${e.message}',
      );

      throw _mapSupabaseAuthException(e);
    } catch (e) {
      debugPrint(
        '[MovieGPT] Password Reset Error: $e',
      );

      throw const MovieGptAuthException(
        'Could not send the password reset email. '
        'Please try again.',
      );
    }
  }

  // ============================================================
  // UPDATE PASSWORD
  // ============================================================

  Future<void> updatePassword(
    String newPassword,
  ) async {
    final String? passwordError =
        validatePassword(newPassword);

    if (passwordError != null) {
      throw MovieGptAuthException(passwordError);
    }

    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      debugPrint(
        '[MovieGPT] Password updated successfully.',
      );
    } on AuthRetryableFetchException catch (e) {
      debugPrint(
        '[MovieGPT] Supabase Password Update Fetch Error: $e',
      );

      throw const MovieGptAuthException(
        'Connection failed. Please try again.',
      );
    } on AuthApiException catch (e) {
      debugPrint(
        '[MovieGPT] Supabase Password Update Error: '
        '${e.code} - ${e.message}',
      );

      throw _mapSupabaseAuthException(e);
    } catch (e) {
      debugPrint(
        '[MovieGPT] Password Update Error: $e',
      );

      throw const MovieGptAuthException(
        'Could not update your password. Please try again.',
      );
    }
  }

  // ============================================================
  // SUPABASE ERROR MAPPING
  // ============================================================

  MovieGptAuthException _mapSupabaseAuthException(
    AuthException e,
  ) {
    final String message =
        e.message.toLowerCase();

    String? code;
    if (e is AuthApiException) {
      code = e.code?.toLowerCase();
    }

    if (message.contains('invalid login credentials') ||
        (code?.contains('invalid_credentials') ?? false)) {
      return const MovieGptAuthException(
        'Unable to sign in. Please check your credentials or confirm your email address if you recently registered.',
      );
    }

    if (message.contains('email not confirmed') ||
        (code?.contains('email_not_confirmed') ?? false)) {
      return const MovieGptAuthException(
        'Please verify your email before signing in.',
      );
    }

    if (message.contains('user already registered') ||
        message.contains('already registered') ||
        message.contains('already exists')) {
      return const MovieGptAuthException(
        'An account already exists with this email.',
      );
    }

    if (message.contains('invalid email')) {
      return const MovieGptAuthException(
        'Please enter a valid email address.',
      );
    }

    if (message.contains('password')) {
      return const MovieGptAuthException(
        'The password does not meet the required security rules.',
      );
    }

    if (message.contains('provider') &&
        message.contains('disabled')) {
      return const MovieGptAuthException(
        'This sign-in provider is currently disabled.',
      );
    }

    if (message.contains('oauth')) {
      return const MovieGptAuthException(
        'OAuth sign-in could not be started. '
        'Please check your Supabase provider configuration.',
      );
    }

    if (message.contains('redirect')) {
      return const MovieGptAuthException(
        'Authentication redirect is not configured correctly.',
      );
    }

    if (message.contains('rate limit') ||
        message.contains('too many')) {
      return const MovieGptAuthException(
        'Too many attempts. Please wait a while and try again.',
      );
    }

    if (message.contains('network') ||
        message.contains('connection')) {
      return const MovieGptAuthException(
        'Please check your internet connection.',
      );
    }

    return const MovieGptAuthException(
      'Authentication failed. Please try again.',
    );
  }
}