import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_mode.dart';
import '../models/movie_model.dart';
import '../state/chat_providers.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/movie_poster.dart';
import 'movie_details_screen.dart';

/// Modern, ChatGPT-style conversational AI chat screen supporting 3 selectable
/// AI modes: 👩 Female Assistant, 👨 Male Assistant, and 🧠 AI Assistant.
///
/// Every reply comes from the REAL AI backend (`AiChatSendNotifier` ->
/// `AiService`) with full conversation history and TMDb movie tools. There are
/// no canned responses here — only the static first-run welcome bubble.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSuggestions = true;

  static const List<String> _suggestions = [
    'Recommend a movie',
    "What's trending?",
    'Movies like Interstellar',
    'What should I watch tonight?',
    'Surprise me',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final history = ref.read(chatHistoryProvider);
      if (history.isEmpty) {
        final mode = ref.read(selectedAiModeProvider);
        ref.read(chatHistoryProvider.notifier).add(_welcomeMessage(mode));
      }
      _scrollToBottom(smooth: false);
    });
  }

  ChatMessage _welcomeMessage(AiMode mode) {
    final personality = AiPersonalities.byMode(mode);
    final bool isPersonal = mode != AiMode.assistant;
    final String body = isPersonal
        ? "Hey! I'm your MovieGPT ${personality.label} ${personality.emoji}\n"
            "I'm here for friendly, natural conversation — let's just chat. What's up?"
        : "Hey! I'm your MovieGPT ${personality.label} ${personality.emoji}\n"
            'Ask me for movie recommendations, trending titles, details about '
            'any film — or anything movie-related. What can I help you discover?';
    return ChatMessage(
      id: 'welcome',
      sender: 'ai',
      text: body,
      timestamp: DateTime.now(),
      assistantMode: AiPersonalities.modeToName(mode),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool smooth = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (smooth) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  /// Sends the user's ACTUAL text to the real AI backend. The user message is
  /// shown immediately; the reply arrives asynchronously from the model and
  /// is appended by [AiChatSendNotifier].
  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _showSuggestions = false);
    await ref.read(aiChatSendProvider.notifier).send(text);
  }

  /// Clear / New Chat with confirmation. Wipes the active conversation and
  /// persisted history, then starts fresh.
  Future<void> _confirmAndClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear this conversation?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: const Text(
          'This starts a fresh chat with full context reset. '
          'The conversation cannot be recovered.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppTheme.primaryRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(chatHistoryProvider.notifier).clear();
    if (!mounted) return;
    setState(() => _showSuggestions = true);
    final mode = ref.read(selectedAiModeProvider);
    ref.read(chatHistoryProvider.notifier).add(_welcomeMessage(mode));
    _scrollToBottom(smooth: false);
  }

  /// Switches assistant mode -> starts a COMPLETELY NEW chat session.
  ///
  /// The previous assistant's in-flight request is cancelled, the shared
  /// chat state is cleared, and the per-mode history provider is recreated
  /// empty so the new assistant has ZERO context from the old session.
  Future<void> _switchMode(AiMode mode) async {
    final current = ref.read(selectedAiModeProvider);
    if (mode == current) return;

    // Cancel any in-flight reply from the previous assistant.
    ref.read(aiChatSendProvider.notifier).cancel();
    debugPrint(
      '[CHAT] Assistant changed: '
      '${AiPersonalities.byMode(current).label} -> '
      '${AiPersonalities.byMode(mode).label}',
    );

    await ref.read(selectedAiModeProvider.notifier).setMode(mode);
    if (!mounted) return;

    // The per-mode history provider was recreated empty: start a fresh chat.
    final historyNotifier = ref.read(chatHistoryProvider.notifier);
    historyNotifier.clear();
    historyNotifier.add(_welcomeMessage(mode));
    setState(() => _showSuggestions = true);
    _scrollToBottom(smooth: false);
    debugPrint('[CHAT] New session created for ${AiPersonalities.byMode(mode).label}');
  }

  void _showModeSelectorSheet() {
    final currentMode = ref.read(selectedAiModeProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.goldAccent, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Choose AI Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...AiPersonalities.all.map((personality) {
                  final isSelected = personality.mode == currentMode;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryRed.withValues(alpha: 0.15)
                          : AppTheme.cardLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryRed : AppTheme.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Text(
                          personality.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          personality.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          personality.subtitle,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryRed)
                            : null,
                        onTap: () {
                          _switchMode(personality.mode);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(chatHistoryProvider);
    final sendState = ref.watch(aiChatSendProvider);
    final isTyping = sendState.isTyping;
    final isBusy = sendState.isBusy;
    final activeMode = ref.watch(selectedAiModeProvider);
    final personality = AiPersonalities.byMode(activeMode);

    // Keep the latest message visible without rebuilding anything manually.
    ref.listen(chatHistoryProvider, (_, _) => _scrollToBottom());
    ref.listen<AiChatSendState>(aiChatSendProvider, (previous, next) {
      if (previous?.isTyping != next.isTyping) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _header(personality, isBusy),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: history.length + (isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= history.length) {
                    return const _ThinkingIndicator();
                  }
                  final msg = history[index];
                  final canRetry = msg.isError &&
                      index == history.length - 1 &&
                      !isBusy &&
                      sendState.pendingUserText != null;
                  return _MessageBubble(
                    message: msg,
                    activeMode: activeMode,
                    canRetry: canRetry,
                    onRetry: canRetry
                        ? () => ref.read(aiChatSendProvider.notifier).retry()
                        : null,
                    key: ValueKey(msg.id),
                  );
                },
              ),
            ),
            if (_showSuggestions)
              _SuggestionChips(suggestions: _suggestions, onTap: _send),
            _ChatInputBar(
              controller: _controller,
              onSend: _send,
              onModeTap: _showModeSelectorSheet,
              activePersonality: personality,
              enabled: !isBusy,
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AiPersonality personality, bool isTyping) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.aiGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'MovieGPT',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showModeSelectorSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cardLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(personality.emoji, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              personality.label,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  isTyping
                      ? '${personality.subtitle} • typing…'
                      : '${personality.subtitle} • Online',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: AppTheme.textMuted,
              size: 20,
            ),
            tooltip: 'New chat / clear conversation',
            onPressed: isTyping ? null : _confirmAndClear,
          ),
          if (isTyping) const _TypingDots(color: AppTheme.primaryRed, size: 6),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final AiMode activeMode;
  final bool canRetry;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    required this.activeMode,
    this.canRetry = false,
    this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';
    // Each assistant bubble shows the identity of the assistant that produced
    // it — not just the currently selected mode.
    final bubbleMode =
        AiPersonalities.modeFromName(message.assistantMode ?? AiPersonalities.modeToName(activeMode));
    final personality = AiPersonalities.byMode(bubbleMode);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isUser
              ? AppTheme.primaryGradient
              : const LinearGradient(
                  colors: [AppTheme.cardMid, AppTheme.cardLow],
                ),
          border: message.isError
              ? Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.45))
              : null,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 18 : 6),
            topRight: Radius.circular(isUser ? 6 : 18),
            bottomLeft: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                children: [
                  Text(personality.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    personality.label.toUpperCase(),
                    style: TextStyle(
                      color: message.isError
                          ? AppTheme.primaryRed
                          : AppTheme.aiAzure,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : AppTheme.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (message.recommended != null) ...[
              const SizedBox(height: 12),
              ...message.recommended!.map((m) {
                try {
                  return _MiniMovieCard(movie: m);
                } catch (e) {
                  return const SizedBox.shrink();
                }
              }),
            ],
            if (canRetry) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryRed,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniMovieCard extends StatelessWidget {
  final Movie movie;
  const _MiniMovieCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      radius: 14,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MovieDetailsScreen(movieId: movie.id),
        ),
      ),
      child: Row(
        children: [
          MoviePoster(
            posterPath: movie.posterPath,
            width: 48,
            radius: 8,
            size: 'w185',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppTheme.goldAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      movie.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        movie.year.isNotEmpty ? movie.year : 'N/A',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  movie.genre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.play_circle_fill_rounded,
            color: AppTheme.primaryRed,
          ),
        ],
      ),
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  const _SuggestionChips({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onTap(suggestion),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Text(
                  suggestion,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.cardMid, AppTheme.cardLow],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const _TypingDots(color: AppTheme.aiAzure, size: 8),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  final Color color;
  final double size;
  const _TypingDots({required this.color, this.size = 8});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_controller.value * 3 + i) % 3) / 3;
            final scale = 0.6 + phase * 0.6;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: widget.size,
                height: widget.size,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final VoidCallback onModeTap;
  final AiPersonality activePersonality;
  final bool enabled;

  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.onModeTap,
    required this.activePersonality,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppTheme.cardDark,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI Mode Selector Button inside Chat Input
          GestureDetector(
            onTap: enabled ? onModeTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Text(activePersonality.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  const Icon(Icons.auto_awesome, color: AppTheme.goldAccent, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.cardLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(controller.text),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Talk to MovieGPT (${activePersonality.label})...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: enabled ? () => onSend(controller.text) : null,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: enabled
                    ? AppTheme.primaryGradient
                    : const LinearGradient(
                        colors: [AppTheme.cardBorder, AppTheme.cardBorder],
                      ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryViolet.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}





