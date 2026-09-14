import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie_model.dart';
import '../screens/trailer_screen.dart';
import '../services/trailer_service.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// The multilingual trailer section on the movie details screen.
///
/// Shows:
///  - a "Trailer Language" dropdown containing ONLY the languages that have a
///    real, verified trailer for this exact TMDb movie (never fabricated);
///  - the selected trailer's canonical type label (e.g. "Official Trailer",
///    "Hindi Dubbed Trailer", "International Teaser");
///  - the "Watch Trailer" action (only enabled when a verified trailer exists),
///    or "Trailer Unavailable" when nothing verified exists.
///
/// Language priority when no explicit choice is made: user preference ->
/// movie original language -> English -> Hindi -> any other verified.
class TrailerLanguageSection extends ConsumerStatefulWidget {
  final Movie movie;

  const TrailerLanguageSection({super.key, required this.movie});

  @override
  ConsumerState<TrailerLanguageSection> createState() =>
      _TrailerLanguageSectionState();
}

class _TrailerLanguageSectionState
    extends ConsumerState<TrailerLanguageSection> {
  /// The language chosen in this session (null = auto / follow preference).
  String? _selectedLang;

  @override
  Widget build(BuildContext context) {
    final verifiedAsync = ref.watch(verifiedTrailersProvider(widget.movie.id));
    final preferred = ref.watch(trailerLanguagePreferenceProvider);

    return verifiedAsync.when(
      loading: () => const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => _unavailableButton(),
      data: (verified) {
        if (verified.isEmpty) return _unavailableButton();

        // Only languages with an ACTUAL verified trailer are offered.
        final languages = <String>{};
        for (final t in verified) {
          final code = t.lang.trim().toLowerCase();
          if (code.isNotEmpty) languages.add(code);
        }
        if (languages.isEmpty) return _unavailableButton();

        // Effective selection: session pick > persisted preference > auto.
        String? effective = _selectedLang;
        if ((effective == null || !languages.contains(effective)) &&
            preferred != null &&
            languages.contains(preferred)) {
          effective = preferred;
        }

        final selectedTrailer = TrailerService.selectForLanguages(
          verified,
          requested: effective,
          movie: widget.movie,
        );
        if (selectedTrailer == null) return _unavailableButton();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TRAILER LANGUAGE',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            _languageDropdown(verified, sortedLangs(languages), effective),
            const SizedBox(height: 8),
            Text(
              selectedTrailer.trailerTypeLabel,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _watchButton(context, selectedTrailer),
          ],
        );
      },
    );
  }


  Widget _languageDropdown(
    List<Trailer> verified,
    List<String> sortedLangs,
    String? effective,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        gradient: AppTheme.glassCardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effective,
          isExpanded: true,
          dropdownColor: AppTheme.cardDark,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white70),
          hint: const Text(
            'Auto',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: AppTheme.neonCyan, size: 18),
                  SizedBox(width: 10),
                  Text('Auto', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            ...sortedLangs.map((code) => _langItem(verified, code)),
          ],
          onChanged: (value) => setState(() => _selectedLang = value),
        ),
      ),
    );
  }

  DropdownMenuItem<String> _langItem(List<Trailer> verified, String code) {
    final t = TrailerService.selectForLanguages(
      verified,
      requested: code,
      movie: widget.movie,
    )!;
    final label = '${t.languageName} — ${t.trailerTypeLabel}';
    return DropdownMenuItem<String>(
      value: code,
      child: Row(
        children: [
          Icon(
            t.isDubbed ? Icons.translate_rounded : Icons.movie_rounded,
            color: t.isHindi ? AppTheme.goldAccent : AppTheme.primaryViolet,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _watchButton(BuildContext context, Trailer trailer) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrailerScreen(
            movieId: widget.movie.id,
            movie: widget.movie,
            trailer: trailer,
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryRed.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text(
              'Watch Trailer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Strict rule: when NO verified trailer exists, show "Trailer Unavailable"
  /// and never open a player.
  Widget _unavailableButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TRAILER LANGUAGE',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        const Text('Not available', style: TextStyle(color: AppTheme.textMuted)),
        const SizedBox(height: 12),
        IgnorePointer(
          child: SizedBox(
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.cardBorder, AppTheme.cardBorder],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_off_outlined,
                      color: Colors.white54, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Trailer Unavailable',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

  List<String> sortedLangs(Set<String> languages) => languages.toList()..sort();
