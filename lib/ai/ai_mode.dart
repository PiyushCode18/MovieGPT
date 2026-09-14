import 'package:flutter/material.dart';

/// The three selectable MovieGPT AI personalities.
///
/// The human-readable name the UI shows is [AiPersonality.displayName].
/// Every persona is transparent about being an AI assistant.
enum AiMode { female, male, assistant }

/// Configuration for a single AI personality.
///
/// This is UI configuration for the mode selector / chat header only. The
/// actual assistant behavior comes from the LLM system prompt built in
/// lib/ai/system_prompts.dart — no canned responses live here.
class AiPersonality {
  final AiMode mode;

  /// Generic UI name shown in mode selector, header and indicator.
  /// e.g. "Female Assistant".
  final String displayName;

  final String gender;

  final String emoji;
  final IconData icon;

  /// Short helper line under the mode title in the selector.
  final String subtitle;

  /// Longer description used in the mode selector card.
  final String description;

  /// Voice-guide: warm/casual/playful/professional.
  final String tone;

  /// 0..1 steering: how playful/silly the generated talking is.
  final double humor;

  /// 0..1 steering of warmth / affection in casual chat.
  final double affection;

  /// 0..1 how formal/structured the generated phrasing is.
  final double formality;

  /// 0..1 how much the assistant steers the conversation towards movies.
  final double movieFocus;

  const AiPersonality({
    required this.mode,
    required this.displayName,
    required this.gender,
    required this.emoji,
    required this.icon,
    required this.subtitle,
    required this.description,
    required this.tone,
    required this.humor,
    required this.affection,
    required this.formality,
    required this.movieFocus,
  });

  /// Back-compat alias for callers that read `.label`.
  String get label => displayName;
}

/// Personality catalogue — the single source of truth for MovieGPT's three
/// modes. Each entry is UI configuration; responses are generated dynamically
/// by the configured LLM backend (see lib/services/ai_service.dart).
class AiPersonalities {
  static const AiPersonality female = AiPersonality(
    mode: AiMode.female,
    displayName: 'Female Friend',
    gender: 'female',
    emoji: '👩',
    icon: Icons.face_rounded,
    subtitle: 'Natural, friendly conversation',
    description:
        'Warm, friendly, caring, playful and emotionally aware. Talks to you '
        'like a natural female companion — supportive and light-hearted.',
    tone: 'warm',
    humor: 0.5,
    affection: 0.55,
    formality: 0.15,
    movieFocus: 0.4,
  );

  static const AiPersonality male = AiPersonality(
    mode: AiMode.male,
    displayName: 'Male Assistant',
    gender: 'male',
    emoji: '👨',
    icon: Icons.face_rounded,
    subtitle: 'Casual, friendly conversation',
    description:
        'Friendly, casual, funny and confident like a natural male friend. '
        'Light teasing, relaxed and supportive.',
    tone: 'casual',
    humor: 0.8,
    affection: 0.15,
    formality: 0.1,
    movieFocus: 0.45,
  );

  static const AiPersonality assistant = AiPersonality(
    mode: AiMode.assistant,
    displayName: 'AI Assistant',
    gender: 'neutral',
    emoji: '🧠',
    icon: Icons.psychology_rounded,
    subtitle: 'Smart MovieGPT assistant',
    description:
        'A highly capable smart assistant. Intelligent, accurate, structured, '
        'professional and especially strong at factual movie intelligence.',
    tone: 'professional',
    humor: 0.1,
    affection: 0.0,
    formality: 0.7,
    movieFocus: 0.9,
  );

  static const List<AiPersonality> all = [female, male, assistant];

  /// Default mode when no persisted preference exists: the Female Assistant.
  static const AiMode defaultMode = AiMode.female;

  static AiPersonality byMode(AiMode mode) {
    return all.firstWhere((p) => p.mode == mode, orElse: () => female);
  }

  static String modeToName(AiMode mode) {
    switch (mode) {
      case AiMode.female:
        return 'female';
      case AiMode.male:
        return 'male';
      case AiMode.assistant:
        return 'assistant';
    }
  }

  static AiMode modeFromName(String? name) {
    if (name == 'male') return AiMode.male;
    if (name == 'assistant') return AiMode.assistant;
    return AiMode.female;
  }
}
