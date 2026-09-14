import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/movie_model.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Load/availability state of the official trailer for the current movie.
enum _TrailerLoadState { loading, unavailable, error, ready }

/// A cinematic, trailer-focused player.
///
/// The screen shows ONLY:
///   1. the YouTube trailer player,
///   2. a MovieGPT back button,
///   3. a MovieGPT fullscreen toggle —
/// on a very dark MovieGPT background.
///
/// There is NO MovieGPT content underneath the player: no movie title
/// overlay, no poster, no "More Videos", no related videos, no recommendations,
/// no external/YouTube links and no second video.
///
/// NOTE on YouTube's own UI: the YouTube logo, channel/title/channel
/// information, the player controls, and the "More videos" / related-video
/// list you may see at the end of a video are rendered BY THE YouTube embedded
/// player (youtube_player_iframe). They belong to YouTube and cannot be
/// removed through Flutter or the official IFrame API. MovieGPT simply does
/// not add any duplicate version of them.
///
/// Trailer resolution flow:
///   TMDb movie -> exact TMDb id -> `/movie/{id}/videos` -> strict filtering
///   -> official trailer -> YouTube id -> embedded player (youtube_player_iframe).
///
/// Fullscreen: portrait-inline 16:9 by default. The fullscreen button rotates
/// to landscape, hides the system UI and expands the video while preserving the
/// 16:9 aspect ratio. Leaving fullscreen (or closing the screen) restores the
/// previous orientation and system UI.
class TrailerScreen extends ConsumerStatefulWidget {
  final int movieId;
  final Movie? movie;

  /// An already-verified official trailer. When null the screen resolves it
  /// itself through [TrailerService] (the normal path).
  final Trailer? trailer;

  const TrailerScreen({
    super.key,
    required this.movieId,
    this.movie,
    this.trailer,
  });

  @override
  ConsumerState<TrailerScreen> createState() => _TrailerScreenState();
}

class _TrailerScreenState extends ConsumerState<TrailerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  YoutubePlayerController? _controller;

  /// Whether a controller has been created (prevents duplicate creation).
  bool _controllerRequested = false;

  /// Whether playback has actually started (used to hide transient overlays).
  bool _hasStarted = false;

  /// True while the user is in fullscreen (landscape + immersive UI).
  bool _isFullscreen = false;

  /// True once the cinematic exit animation has begun (about to pop).
  bool _closing = false;

  _TrailerLoadState _loadState = _TrailerLoadState.loading;

  /// Saved orientation so it can be restored when leaving the screen.
  List<DeviceOrientation> _savedOrientations = const [];

  late final AnimationController _entrance;
  late final Animation<double> _entranceFade;
  late final Animation<double> _entranceScale;

  late final AnimationController _exit;
  late final Animation<double> _exitFade;
  late final Animation<double> _exitScale;

  @override
  void initState() {
    super.initState();

    // Cinematic fade + scale entrance.
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entranceFade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _entranceScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic),
    );
    _entrance.forward();

    // Cinematic fade + scale exit (played right before popping).
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _exitFade = CurvedAnimation(parent: _exit, curve: Curves.easeIn);
    _exitScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _exit, curve: Curves.easeInCubic),
    );

    // Remember current orientation so we can restore it on close.
    _saveOrientations();
    // Keep the screen awake while the trailer is open.
    WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this);

    // Resolve + create the player (never synchronously during build).
    _resolveTrailer();
  }

  @override
  void dispose() {
    _controller?.pauseVideo();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.close();
    _controller = null;
    _entrance.dispose();
    _exit.dispose();

    // Restore orientation + system UI + allow the screen to sleep again.
    _restoreOrientations();
    _restoreSystemUi();
    WakelockPlus.disable();
    super.dispose();
  }

  /// Resolve the official trailer for the movie, then create the player.
  ///
  /// Uses [TrailerService] which is driven by the EXACT TMDb movie id — never
  /// a YouTube search and never another movie's trailer.
  Future<void> _resolveTrailer() async {
    // A verified trailer was passed in — use it directly.
    final preResolved = widget.trailer;
    if (preResolved != null) {
      _onTrailerResolved(preResolved);
      return;
    }

    // The state is already `loading` on entry; `_retry` resets it before
    // calling this again.
    final movie = widget.movie ?? Movie(id: widget.movieId, title: '');
    try {
      final trailer = await ref
          .read(trailerServiceProvider)
          .getOfficialTrailer(movie);
      if (!mounted) return;
      if (trailer != null) {
        _onTrailerResolved(trailer);
      } else {
        setState(() => _loadState = _TrailerLoadState.unavailable);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadState = _TrailerLoadState.error);
    }
  }

  void _onTrailerResolved(Trailer trailer) {
    setState(() => _loadState = _TrailerLoadState.ready);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _createController(trailer);
    });
  }

  /// Create the YouTube controller ONCE, outside of build (post-frame), with
  /// the cleanest supported player configuration.
  void _createController(Trailer trailer) {
    if (_controller != null || _controllerRequested) return;
    _controllerRequested = true;

    final controller = YoutubePlayerController.fromVideoId(
      videoId: trailer.key,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        enableCaption: false,
        playsInline: true,
        // rel = 0: strictly limit related-video suggestions (same channel).
        strictRelatedVideos: true,
        // privacy-enhanced embeds use the youtube-nocookie domain.
        privacyEnhancedMode: true,
        showVideoAnnotations: false,
        enableKeyboard: false,
        color: 'black',
      ),
    );

    if (!mounted) return;
    setState(() => _controller = controller);
  }

  /// Retry: re-resolve the trailer and rebuild the player from scratch.
  void _retry() {
    setState(() {
      _loadState = _TrailerLoadState.loading;
      _hasStarted = false;
    });
    final old = _controller;
    _controller = null;
    _controllerRequested = false;
    old?.close();
    _resolveTrailer();
  }

  // ------------------------------------------------------------- fullscreen

  /// Fullscreen: rotate to landscape, hide the system UI, expand the video
  /// while preserving the 16:9 aspect ratio (no stretching / cropping).
  Future<void> _enterFullscreen() async {
    if (_isFullscreen) return;
    setState(() => _isFullscreen = true);
    await _setOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {
      // Best-effort; the video still plays without immersive mode.
    }
  }

  /// Exit fullscreen and restore the previous orientation + system UI.
  Future<void> _exitFullscreen() async {
    if (!_isFullscreen) return;
    setState(() => _isFullscreen = false);
    await _restoreOrientations();
    await _restoreSystemUi();
  }

  /// Back behavior: exit fullscreen first when fullscreen, otherwise leave the
  /// screen (orientation + system UI are restored in [dispose]).
  Future<void> _handleBack() async {
    if (_isFullscreen) {
      await _exitFullscreen();
      return;
    }
    await _popWithExit();
  }

  /// Play the cinematic exit animation, then pop back to the previous screen.
  Future<void> _popWithExit() async {
    if (_closing) return;
    _closing = true;
    _controller?.pauseVideo();
    await _exit.forward(from: 0);
    if (mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------ orientation / system UI

  /// Save the current preferred orientations (from the platform).
  Future<void> _saveOrientations() async {
    try {
      _savedOrientations = await SystemChannels.platform
          .invokeMethod<List<dynamic>>('SystemChrome.getPreferredOrientations')
          .then((list) => list?.map(_decodeOrientation).toList() ?? const []);
    } catch (_) {
      _savedOrientations = const [];
    }
  }

  static DeviceOrientation _decodeOrientation(dynamic value) {
    switch (value) {
      case 'portraitUp':
        return DeviceOrientation.portraitUp;
      case 'portraitDown':
        return DeviceOrientation.portraitDown;
      case 'landscapeLeft':
        return DeviceOrientation.landscapeLeft;
      case 'landscapeRight':
        return DeviceOrientation.landscapeRight;
      default:
        return DeviceOrientation.portraitUp;
    }
  }

  Future<void> _setOrientations(List<DeviceOrientation> orientations) async {
    try {
      await SystemChrome.setPreferredOrientations(orientations);
    } catch (_) {
      // Orientation lock is best-effort; the player still works in portrait.
    }
  }

  Future<void> _restoreOrientations() async {
    if (_savedOrientations.isEmpty) {
      await _setOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await _setOrientations(_savedOrientations);
    }
  }

  /// Restore the system UI to edge-to-edge (normal app display).
  Future<void> _restoreSystemUi() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {
      // Best-effort.
    }
  }

  /// Pause playback when the app goes to the background so audio/video never
  /// keeps playing off-screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      controller.pauseVideo();
    } else if (state == AppLifecycleState.resumed) {
      // Resume playback after an interruption (safe no-op if not paused).
      controller.playVideo();
    }
  }

  void _markStarted() {
    if (mounted && !_hasStarted) setState(() => _hasStarted = true);
  }

  void _markReset() {
    if (mounted && _hasStarted) setState(() => _hasStarted = false);
  }

  @override
  Widget build(BuildContext context) {
    // Intercept the system back gesture so we always restore orientation +
    // system UI before leaving, and so fullscreen is dismissed first.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: AnimatedBuilder(
          animation: _entrance,
          builder: (context, _) {
            // When closing, layer the exit fade + scale on top of the entrance
            // value so the screen animates out before it pops.
            final exitFade = _closing ? _exitFade.value : 0.0;
            final exitScale = _closing ? _exitScale.value : 1.0;
            final opacity = _entranceFade.value * (1.0 - exitFade);
            final scale = _entranceScale.value * exitScale;
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale.clamp(0.0, 1.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Very dark cinematic MovieGPT background.
                    const ColoredBox(color: AppTheme.bgDark),
                    // Only the player (no MovieGPT content underneath it).
                    SafeArea(child: _buildBody()),
                    // Minimal back handle (top-left).
                    Positioned(
                      top: 0,
                      left: 0,
                      child: SafeArea(
                        bottom: false,
                        child: _TopBarBack(onBack: _handleBack),
                      ),
                    ),
                    // Fullscreen toggle (top-right).
                    Positioned(
                      top: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: _TopBarFullscreen(
                          isFullscreen: _isFullscreen,
                          onToggle: _isFullscreen
                              ? _exitFullscreen
                              : _enterFullscreen,
                        ),
                      ),
                    ),
                    // Minimal trailer caption: movie title + selected
                    // language + canonical type label (e.g.
                    // "Inception · Hindi — Hindi Dubbed Trailer").
                    // Hidden while playing and in fullscreen so playback
                    // stays fully cinematic; no other content is added.
                    if (!_isFullscreen &&
                        !_hasStarted &&
                        widget.trailer != null)
                      Positioned(
                        top: 0,
                        left: 60,
                        right: 60,
                        child: SafeArea(
                          bottom: false,
                          child: Column(
                            children: [
                              Text(
                                widget.movie?.title ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.trailer!.languageName} · '
                                '${widget.trailer!.trailerTypeLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Body: ONLY the player (16:9, no stretching), centered in the available
  /// video area. There is deliberately NO Column underneath it — no "OFFICIAL
  /// TRAILER" label, no More Videos, no related content. The back button and
  /// fullscreen toggle (MovieGPT-owned) are layered on top via the outer Stack.
  Widget _buildBody() {
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _buildPlayer(),
      ),
    );
  }

  Widget _buildPlayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget player;
        switch (_loadState) {
          case _TrailerLoadState.loading:
            player = const _PlayerLoading();
            break;
          case _TrailerLoadState.unavailable:
            player = _PlayerUnavailable(onRetry: _retry, onBack: _handleBack);
            break;
          case _TrailerLoadState.error:
            player = _PlayerError(
              message: 'Trailer unavailable',
              onRetry: _retry,
              onBack: _handleBack,
            );
            break;
          case _TrailerLoadState.ready:
            final controller = _controller;
            if (controller == null) {
              player = const _PlayerLoading();
            } else {
              player = _PlayerWithState(
                controller: controller,
                onStarted: _markStarted,
                onReset: _markReset,
                onRetry: _retry,
                onBack: _handleBack,
              );
            }
            break;
        }
        return player;
      },
    );
  }
}

/// Renders the embedded player plus a reactive loading / error overlay.
///
/// Uses [YoutubeValueBuilder] to react to the controller's stream (buffering,
/// error, playing) WITHOUT calling `setState` during the parent's build.
class _PlayerWithState extends StatelessWidget {
  final YoutubePlayerController controller;
    final VoidCallback onStarted;
  final VoidCallback onReset;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _PlayerWithState({
    required this.controller,
    required this.onStarted,
    required this.onReset,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        YoutubePlayer(controller: controller),
        YoutubeValueBuilder(
          controller: controller,
          builder: (context, value) {
            final hasError = value.hasError;
            final isBuffering =
                value.playerState == PlayerState.buffering ||
                value.playerState == PlayerState.unStarted ||
                value.playerState == PlayerState.unknown;

            final playing = value.playerState == PlayerState.playing;
            if (playing) {
              WidgetsBinding.instance.addPostFrameCallback((_) => onStarted());
            } else if (hasError ||
                value.playerState == PlayerState.cued ||
                value.playerState == PlayerState.paused) {
              WidgetsBinding.instance.addPostFrameCallback((_) => onReset());
            }

            Widget? centerOverlay;
            if (hasError) {
              centerOverlay = _PlayerError(
                message: 'Trailer unavailable',
                onRetry: onRetry,
                onBack: onBack,
              );
            } else if (isBuffering) {
              centerOverlay = const Center(child: _PlayerLoading());
            }

            return Stack(
              fit: StackFit.expand,
              children: [const SizedBox.shrink(), ?centerOverlay],
            );
          },
        ),
      ],
    );
  }
}

/// Premium cinematic loading state: dark background, subtle red MovieGPT
/// accent, a small spinner and a "Loading trailer..." label.
class _PlayerLoading extends StatelessWidget {
  const _PlayerLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.bgDark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primaryRed,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading trailer...',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when no verified trailer exists for the requested movie. Offers a
/// "Try again" and a "Go Back" action — it NEVER auto-plays another movie's
/// trailer and never opens an empty player.
class _PlayerUnavailable extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _PlayerUnavailable({required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.bgDark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: AppTheme.textMuted,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'Trailer unavailable',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppTheme.primaryRed,
              ),
              label: const Text(
                'Try again',
                style: TextStyle(color: AppTheme.primaryRed),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textSecondary,
              ),
              label: const Text(
                'Go Back',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state with a "Trailer unavailable" message, a "Try again" and a
/// "Go Back" action. Never substitutes another video.
class _PlayerError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _PlayerError({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.bgDark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppTheme.primaryRed,
              size: 40,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppTheme.primaryRed,
              ),
              label: const Text(
                'Try again',
                style: TextStyle(color: AppTheme.primaryRed),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textSecondary,
              ),
              label: const Text(
                'Go Back',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal back handle (top-left). Closes the screen via [_handleBack] logic.
class _TopBarBack extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBarBack({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onBack,
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

/// Fullscreen toggle (top-right). Enters landscape fullscreen or exits back
/// to the portrait-inline player.
class _TopBarFullscreen extends StatelessWidget {
  final bool isFullscreen;
  final VoidCallback onToggle;

  const _TopBarFullscreen({
    required this.isFullscreen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onToggle,
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isFullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}