import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted state for explicit Guest Mode ("Skip for now").
///
/// This allows the app to remember if a user intentionally chose to browse
/// as a guest, distinct from being unauthenticated and needing to log in.
final guestModeProvider = StateNotifierProvider<GuestModeNotifier, bool>((ref) {
  return GuestModeNotifier();
});

class GuestModeNotifier extends StateNotifier<bool> {
  GuestModeNotifier() : super(false) {
    _load();
  }

  static const String _storageKey = 'moviegpt_guest_mode_v1';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_storageKey) ?? false;
    } catch (_) {
      state = false;
    }
  }

  Future<void> setGuestMode(bool isGuest) async {
    state = isGuest;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, isGuest);
    } catch (_) {
      // Best effort persistence.
    }
  }

  Future<void> clear() async {
    await setGuestMode(false);
  }
}
