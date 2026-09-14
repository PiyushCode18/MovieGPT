import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Provides the singleton [AuthService] throughout the app.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.instance;
});

/// The current authentication state, derived from Firebase's auth stream.
///
/// Async values:
/// - `loading`: auth state is still being resolved (splash screen).
/// - `data(AppUser?)`: `null` means signed out, a user means signed in.
/// - `error`: an unexpected stream error (rare).
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

