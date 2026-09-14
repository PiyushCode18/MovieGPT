import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/movie_model.dart';
import '../state/auth_providers.dart';
import '../state/guest_provider.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'login_screen.dart';
import 'watchlist_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistProvider);
    final watchedCount = watchlist.length;
    final authUser = ref.watch(authStateProvider).valueOrNull;

    // Derive a real "Match" score from the user's saved movies
    // (average AI match across the watchlist) instead of a hardcoded "--".
    final matchScore = watchlist.isEmpty
        ? null
        : (watchlist.map((m) => m.aiMatchScore).reduce((a, b) => a + b) /
                  watchlist.length)
              .round();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  _avatar(authUser),
                  const SizedBox(height: 14),
                  Text(
                    _displayName(authUser),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (authUser?.email?.isNotEmpty ?? false)
                        ? authUser!.email!
                        : (authUser != null
                              ? (authUser.phoneNumber?.isNotEmpty ?? false
                                    ? authUser.phoneNumber!
                                    : 'Signed in successfully')
                              : 'Sign in to unlock personalized recommendations'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatCard(value: '$watchedCount', label: 'Saved'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    value: matchScore?.toString() ?? 'N/A',
                    label: 'Match',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    value: _avgRating(watchlist),
                    label: 'Avg Rating',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GlassCard(
              padding: const EdgeInsets.all(20),
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology_rounded, color: AppTheme.aiPurple),
                      SizedBox(width: 10),
                      Text(
                        'AI TASTE PROFILE',
                        style: TextStyle(
                          color: AppTheme.aiPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Sign in to build your AI taste profile and receive personalized movie recommendations.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GlassCard(
              padding: EdgeInsets.zero,
              radius: 24,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.bookmark_rounded,
                    label: 'Watchlist',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WatchlistScreen(),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.translate_rounded,
                    label: 'Preferred Trailer Language',
                    onTap: () => _showTrailerLanguagePicker(context, ref),
                  ),
                  _SettingsTile(
                    icon: Icons.settings_rounded,
                    label: 'App Settings',
                  ),
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    iconColor: AppTheme.primaryRed,
                    textColor: AppTheme.primaryRed,
                    onTap: () async {
                      // Clear both Supabase session and explicit guest mode.
                      await ref.read(authServiceProvider).signOut();
                      await ref.read(guestModeProvider.notifier).clear();

                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom-sheet picker for the user's preferred trailer language.
  ///
  /// The choice is persisted via [trailerLanguagePreferenceProvider]
  /// (SharedPreferences) and drives the default selection in the movie
  /// details trailer language selector. "Auto" clears the preference.
  void _showTrailerLanguagePicker(BuildContext context, WidgetRef ref) {
    const languages = <String?>[
      null, // Auto
      'en', 'hi', 'ta', 'te', 'ml', 'kn', 'bn', 'mr', 'gu', 'pa',
      'es', 'fr', 'de', 'ja', 'ko', 'zh', 'ar', 'pt', 'ru',
    ];

    String name(String? code) {
      if (code == null) return 'Auto (original language first)';
      switch (code) {
        case 'en': return 'English';
        case 'hi': return 'Hindi';
        case 'ta': return 'Tamil';
        case 'te': return 'Telugu';
        case 'ml': return 'Malayalam';
        case 'kn': return 'Kannada';
        case 'bn': return 'Bengali';
        case 'mr': return 'Marathi';
        case 'gu': return 'Gujarati';
        case 'pa': return 'Punjabi';
        case 'es': return 'Spanish';
        case 'fr': return 'French';
        case 'de': return 'German';
        case 'ja': return 'Japanese';
        case 'ko': return 'Korean';
        case 'zh': return 'Chinese';
        case 'ar': return 'Arabic';
        case 'pt': return 'Portuguese';
        case 'ru': return 'Russian';
      }
      return code.toUpperCase();
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final current = ref.watch(trailerLanguagePreferenceProvider);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Preferred Trailer Language',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              for (final code in languages)
                Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    leading: Icon(
                      code == null
                          ? Icons.auto_awesome_rounded
                          : Icons.translate_rounded,
                      color: current == code
                          ? AppTheme.primaryRed
                          : AppTheme.textSecondary,
                      size: 20,
                    ),
                    title: Text(
                      name(code),
                      style: TextStyle(
                        color:
                            current == code ? Colors.white : AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight:
                            current == code ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    trailing: current == code
                        ? const Icon(Icons.check_rounded,
                            color: AppTheme.primaryRed)
                        : null,
                    onTap: () {
                      ref
                          .read(trailerLanguagePreferenceProvider.notifier)
                          .setLanguage(code);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _avgRating(List<Movie> list) {
    if (list.isEmpty) return 'N/A';
    final avg = list.map((m) => m.rating).reduce((a, b) => a + b) / list.length;
    return avg.toStringAsFixed(0);
  }

  /// Best-effort display name for the profile header.
  String _displayName(AppUser? user) {
    final displayName = user?.displayName ?? '';
    if (displayName.trim().isNotEmpty) return displayName;
    final email = user?.email ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    final phone = user?.phoneNumber ?? '';
    if (phone.isNotEmpty) return phone;
    return 'Guest User';
  }

  /// Profile avatar: shows the user's photo if available, otherwise a
  /// gradient circle with their initial.
  Widget _avatar(AppUser? user) {
    final photoUrl = user?.photoUrl ?? '';
    if (photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _initialsAvatar(user),
        ),
      );
    }
    return _initialsAvatar(user);
  }

  Widget _initialsAvatar(AppUser? user) {
    final name = _displayName(user);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      radius: 16,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.primaryRed,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? textColor;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.iconColor,
    this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppTheme.textSecondary, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor ?? AppTheme.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

