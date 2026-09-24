import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../models/app_user.dart';
import '../state/auth_providers.dart';
import '../state/guest_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

/// Premium 10-second cinematic MovieGPT splash screen.
///
/// Branding uses the existing logo asset:
///   assets/images/moviegpt_logo.png
///
/// Timeline (exactly 10.0 s, driven by ONE master [AnimationController]; the
/// splash audio is decorative and NEVER controls navigation):
///   0.0 - 1.5 s  Dark cinematic backdrop; subtle red particles/smoke appear;
///                the logo fades in at a small size.
///   1.5 - 3.5 s  Slow cinematic zoom to main size with glow, metallic sheen,
///                red rim lighting, particles and volumetric light.
///   3.5 - 5.5 s  Logo at main size; a red light sweep travels left to right;
///                red energy particles, sparks, smoke, lens flare, soft glow.
///   5.5 - 7.0 s  Reveal the "MovieGPT" brand text (smooth fade + slight rise).
///   7.0 - 8.5 s  Reveal the "AI MOVIES. ENDLESS DISCOVERIES" tagline.
///   8.5 - 9.5 s  Hold the complete branding with a subtle glow pulse.
///   9.5 - 10.0 s Smooth cinematic fade, then navigate via pushReplacement.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // 10-second master timeline (milliseconds)
  // ---------------------------------------------------------------------------

  static const double _kTotalMs = 10000;
  static const double _kFadeInEnd = 1500; // Logo fade-in completes.
  static const double _kZoomEnd = 3500; // Logo reaches main size.
  static const double _kSweepStart = 3500; // Light sweep begins.
  static const double _kSweepEnd = 5500; // Light sweep completes.
  static const double _kTextStart = 5500; // "MovieGPT" reveal begins.
  static const double _kTextEnd = 7000; // Brand text fully visible.
  static const double _kTagStart = 7000; // Tagline reveal begins.
  static const double _kTagEnd = 8500; // Tagline fully visible.
  static const double _kPulseStart = 8500; // Glow pulse begins.
  static const double _kFadeOutStart = 9500; // Cinematic fade out begins.

  static const Duration _total = Duration(milliseconds: 10000);
  static const Duration _reduced = Duration(milliseconds: 1600);
  static const Duration _authGrace = Duration(milliseconds: 1500);

  /// Pure safety net (slightly after the master animation). It is cancelled
  /// the instant navigation happens, so the total splash duration stays 10 s.
  static const Duration _safety = Duration(milliseconds: 10300);

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  late final AnimationController _controller;
  late final AudioPlayer _audioPlayer;

  StreamSubscription<void>? _completeSub;
  StreamSubscription<PlayerState>? _stateSub;
  Timer? _safetyTimer;

  bool _navigated = false;
  bool _reducedMotion = false;
  bool _audioStarted = false;

  @override
  void initState() {
    super.initState();

    // Immersive cinematic splash (best-effort; a no-op on unsupported targets).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _audioPlayer = AudioPlayer();
    
    // On non-web platforms, we can try to start audio immediately.
    // On Web, this will likely fail until a user interaction occurs.
    if (!kIsWeb) {
      unawaited(_initAudio());
    }

    _controller = AnimationController(vsync: this, duration: _total)
      ..addStatusListener(_onStatus);

    _controller.forward();

    // Safety net: navigation is normally triggered by the animation finishing
    // at exactly 10.0 s. This timer only guarantees we can never get stuck.
    _safetyTimer = Timer(_safety, _navigateSafely);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced == _reducedMotion) {
      return;
    }

    _reducedMotion = reduced;
    _controller.duration = reduced ? _reduced : _total;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _completeSub?.cancel();
    _stateSub?.cancel();

    // Restore normal system UI.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _navigateSafely();
    }
  }

  // ---------------------------------------------------------------------------
  // Audio (decorative; a failure here must never break the splash)
  // ---------------------------------------------------------------------------

  Future<void> _initAudio() async {
    if (_audioStarted) return;
    
    try {
      if (kDebugMode) {
        debugPrint('[MovieGPT Intro] Initializing cinematic audio...');
      }

      // Configure the audio context for a premium startup experience.
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ));

      _stateSub?.cancel();
      _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
        if (kDebugMode) {
          debugPrint('[MovieGPT Intro] Audio state: $state');
        }
      });

      _completeSub?.cancel();
      _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
        unawaited(_audioPlayer.release().catchError((_) {}));
      });

      // Load the asset explicitly.
      final source = AssetSource('sounds/splash_sound.wav');
      await _audioPlayer.setSource(source);
      await _audioPlayer.setVolume(0.85);

      if (kDebugMode) {
        debugPrint('[MovieGPT Intro] Audio source loaded.');
      }

      // Attempt playback.
      await _audioPlayer.resume();
      _audioStarted = true;
      
      if (kDebugMode) {
        debugPrint('[MovieGPT Intro] Audio playback started.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MovieGPT Intro] Audio failed: $e');
      }
    }
  }

  /// Manually triggers audio playback. Used to satisfy Web autoplay requirements or as a manual trigger.
  void _handleInteraction() {
    if (!_audioStarted) {
      unawaited(_initAudio());
    }
  }
  // ---------------------------------------------------------------------------
  // Safe navigation
  // ---------------------------------------------------------------------------

  Future<void> _navigateSafely() async {
    if (_navigated || !mounted) {
      return;
    }

    _navigated = true;
    _safetyTimer?.cancel();

    // Ensure dependencies (dotenv, Supabase) are initialized before navigating.
    try {
      if (MovieGptApp.initFuture != null) {
        await MovieGptApp.initFuture;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MovieGPT Splash] Initialization error during navigation: $e');
      }
    }

    AppUser? user;
    try {
      user = await ref.read(authStateProvider.future).timeout(_authGrace);
    } catch (_) {
      // Authentication must never block navigation.
      user = ref.read(authStateProvider).valueOrNull;
    }

    if (!mounted) {
      return;
    }

    final isGuest = ref.read(guestModeProvider);

    // Navigate to Home if we have a real user OR explicit Guest Mode.
    final destination = (user != null || isGuest)
        ? const MainNavigationScreen()
        : const LoginScreen();

    // Replace the splash route so the back button can never return to it.
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }
  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduced = media.disableAnimations;
    final size = media.size;

    final logoSize = (size.shortestSide * 0.5).clamp(150.0, 300.0).toDouble();
    final cx = size.width / 2;
    final cy = size.height * 0.42;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final ms = _controller.value * _kTotalMs;

          final opacity = _logoOpacity(ms);
          final scale = reduced ? 1.0 : _zoomScale(ms);
          final sweep = reduced ? null : _sweepT(ms);

          final textOpacity = reduced
              ? 1.0
              : _step(ms, _kTextStart, _kTextEnd) *
                    (1 - _step(ms, _kFadeOutStart, _kTotalMs));
          final textSlide = reduced ? 0.0 : (1 - textOpacity) * 20.0;

          final tagOpacity = reduced
              ? 1.0
              : _step(ms, _kTagStart, _kTagEnd) *
                    (1 - _step(ms, _kFadeOutStart, _kTotalMs));

          final lineOpacity = reduced
              ? 0.7
              : _step(ms, _kTagStart, _kTagEnd) *
                    (1 - _step(ms, _kFadeOutStart, _kTotalMs));

          final glowPulse = reduced ? 0.0 : _glowPulse(ms);

          final volLight = reduced
              ? 0.0
              : _step(ms, 1500, _kZoomEnd) * (1 - _step(ms, 5200, 6000));

          // ---- Logo emblem ---------------------------------------------
          final emblem = SizedBox(
            width: logoSize,
            height: logoSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.all(logoSize * 0.035),
                  child: Image.asset(
                    'assets/images/moviegpt_logo.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stack) =>
                        const SizedBox.shrink(),
                  ),
                ),
                if (!reduced)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _LogoLightingPainter()),
                    ),
                  ),
                if (sweep != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipOval(
                        child: CustomPaint(painter: _LightSweepPainter(sweep)),
                      ),
                    ),
                  ),
              ],
            ),
          );
          // ---- Brand text ----------------------------------------------
          final brand = RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: logoSize * 0.20,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: 2.4,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 18,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              children: const [
                TextSpan(
                  text: 'Movie',
                  style: TextStyle(color: Color(0xFFD6D6E0)),
                ),
                TextSpan(
                  text: 'GPT',
                  style: TextStyle(color: AppTheme.primaryRed),
                ),
              ],
            ),
          );

          // ---- Tagline --------------------------------------------------
          final tagline = Text(
            'AI MOVIES. ENDLESS DISCOVERIES',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: logoSize * 0.052,
              fontWeight: FontWeight.w600,
              letterSpacing: 4.5,
            ),
          );

          // ---- Full-screen cinematic layers -----------------------------
          final particles = reduced
              ? const SizedBox.shrink()
              : Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: CustomPaint(
                    painter: _ParticlePainter(
                      progress: ms / _kTotalMs,
                      cx: cx,
                      cy: cy,
                    ),
                    child: const SizedBox.expand(),
                  ),
                );

          final smoke = reduced
              ? const SizedBox.shrink()
              : Opacity(
                  opacity: (0.35 + 0.65 * opacity).clamp(0.0, 1.0),
                  child: CustomPaint(
                    painter: _SmokePainter(progress: ms / _kTotalMs),
                    child: const SizedBox.expand(),
                  ),
                );

          final volLightLayer = (reduced || volLight <= 0.001)
              ? const SizedBox.shrink()
              : Opacity(
                  opacity: volLight,
                  child: CustomPaint(
                    painter: _VolumetricPainter(ms / _kTotalMs),
                    child: const SizedBox.expand(),
                  ),
                );

          final flare = (reduced || sweep == null)
              ? const SizedBox.shrink()
              : IgnorePointer(
                  child: CustomPaint(
                    painter: _LensFlarePainter(sweep),
                    child: const SizedBox.expand(),
                  ),
                );

          final sparks = (reduced || sweep == null)
              ? const SizedBox.shrink()
              : IgnorePointer(
                  child: CustomPaint(
                    painter: _SparksPainter(sweep),
                    child: const SizedBox.expand(),
                  ),
                );

          final glowLayer = (reduced || glowPulse <= 0.001)
              ? const SizedBox.shrink()
              : IgnorePointer(
                  child: CustomPaint(
                    painter: _GlowPainter(glowPulse),
                    child: const SizedBox.expand(),
                  ),
                );
          // ---- Main cinematic layout -----------------------------------
          return GestureDetector(
            onTap: _handleInteraction,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(child: _CinematicBackdrop()),
                volLightLayer,
                smoke,
                particles,
                sparks,
                glowLayer,

                // Logo + branding centerpiece.
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Opacity(
                      opacity: opacity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.scale(scale: scale, child: emblem),
                          SizedBox(height: logoSize * 0.16),
                          Transform.translate(
                            offset: Offset(0, textSlide),
                            child: Opacity(opacity: textOpacity, child: brand),
                          ),
                          const SizedBox(height: 18),
                          Opacity(opacity: tagOpacity, child: tagline),
                          const SizedBox(height: 20),
                          Transform.translate(
                            offset: Offset(0, textSlide * 0.5),
                            child: Opacity(
                              opacity: lineOpacity,
                              child: Container(
                                width: logoSize * 0.62,
                                height: 1.4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppTheme.primaryRed.withValues(alpha: 0.0),
                                      AppTheme.primaryRed.withValues(alpha: 0.8),
                                      AppTheme.primaryRed.withValues(alpha: 0.0),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                flare,

                // Web-only subtle interaction hint if audio is blocked.
                if (kIsWeb && !_audioStarted)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: FadeInWidget(
                      duration: const Duration(milliseconds: 800),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white24,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.volume_up_rounded,
                                color: Colors.white70,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'TAP TO UNMUTE EXPERIENCE',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Animation helpers
  // ---------------------------------------------------------------------------

  /// Smooth 0..1 ramp between two timeline points (easeOutCubic).
  static double _step(double ms, double startMs, double endMs) {
    if (ms <= startMs) {
      return 0.0;
    }
    if (ms >= endMs) {
      return 1.0;
    }
    return Curves.easeOutCubic.transform((ms - startMs) / (endMs - startMs));
  }

  /// Linear inverse-lerp, clamped to 0..1.
  static double _lerp01(double ms, double startMs, double endMs) {
    if (ms <= startMs) {
      return 0.0;
    }
    if (ms >= endMs) {
      return 1.0;
    }
    return (ms - startMs) / (endMs - startMs);
  }

  /// Continuous slow cinematic zoom: tiny (0.26x) at t=0 up to 1.0x at 3.5 s.
  double _zoomScale(double ms) {
    final t = (ms / _kZoomEnd).clamp(0.0, 1.0);
    return 0.26 + 0.74 * Curves.easeInOutCubic.transform(t);
  }

  /// Logo opacity: fade-in (0-1.5 s), hold, fade-out (9.5-10 s).
  double _logoOpacity(double ms) {
    return _step(ms, 0, _kFadeInEnd) *
        (1 - _step(ms, _kFadeOutStart, _kTotalMs));
  }

  /// Light-sweep progress (3.5-5.5 s) or null outside the window.
  double? _sweepT(double ms) {
    if (ms <= _kSweepStart || ms >= _kSweepEnd) {
      return null;
    }
    return _lerp01(ms, _kSweepStart, _kSweepEnd);
  }

  /// Subtle glow pulse during the final hold (8.5-9.5 s).
  double _glowPulse(double ms) {
    final gain =
        _step(ms, _kPulseStart, _kPulseStart + 400) *
        (1 - _step(ms, _kFadeOutStart, _kTotalMs));
    if (gain <= 0.001) {
      return 0.0;
    }
    final wave = 0.5 + 0.5 * math.sin((ms - _kPulseStart) / 1000 * math.pi * 2);
    return gain * (0.45 + 0.55 * wave);
  }
}
// =============================================================================
// CINEMATIC BACKDROP
// =============================================================================

/// Static near-black cinematic backdrop with faint red glow, metallic silver
/// depth and a vignette.
class _CinematicBackdrop extends StatelessWidget {
  const _CinematicBackdrop();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _BackdropPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Deep cinematic black.
    canvas.drawRect(rect, Paint()..color = const Color(0xFF08080A));

    // Faint red upper glow.
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            RadialGradient(
              radius: 1.1,
              colors: [
                AppTheme.primaryRed.withValues(alpha: 0.07),
                const Color(0x00000000),
              ],
            ).createShader(
              Rect.fromCenter(
                center: Offset(size.width / 2, -size.height * 0.18),
                width: size.height * 1.5,
                height: size.height * 1.5,
              ),
            ),
    );

    // Very subtle metallic silver depth from the bottom.
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            RadialGradient(
              radius: 1.1,
              colors: [
                Colors.white.withValues(alpha: 0.025),
                const Color(0x00000000),
              ],
            ).createShader(
              Rect.fromCenter(
                center: Offset(size.width / 2, size.height * 1.12),
                width: size.height * 1.3,
                height: size.height * 1.3,
              ),
            ),
    );

    // Cinematic vignette.
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            RadialGradient(
              radius: 1.15,
              colors: [
                const Color(0x00000000),
                Colors.black.withValues(alpha: 0.46),
              ],
              stops: const [0.68, 1.0],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width / 2, size.height / 2),
                radius: size.longestSide * 0.75,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
}

// =============================================================================
// VOLUMETRIC LIGHT
// =============================================================================

/// Soft volumetric light shafts that appear during the cinematic zoom phase.
class _VolumetricPainter extends CustomPainter {
  const _VolumetricPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.42;

    final sway = math.sin(progress * math.pi * 2) * w * 0.06;

    for (var i = 0; i < 3; i++) {
      final dx = cx - w * 0.45 + i * w * 0.45 + sway;
      final shaftRect = Rect.fromLTWH(
        dx,
        cy - h * 0.30,
        w * (0.16 + i * 0.03),
        h * 0.72,
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.045), Colors.transparent],
        ).createShader(shaftRect);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(-0.12 + i * 0.12);
      canvas.translate(-cx, -cy);
      canvas.drawRect(shaftRect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_VolumetricPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// =============================================================================
// LIGHT SWEEP
// =============================================================================

/// Red cinematic light sweep that travels from left to right across the logo.
class _LightSweepPainter extends CustomPainter {
  const _LightSweepPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final env = math.sin(progress * math.pi).clamp(0.0, 1.0);
    final bandW = w * 0.48;
    final x = -bandW + progress * (w + 2 * bandW);

    final bandRect = Rect.fromLTWH(x - bandW / 2, 0, bandW, h);

    // Red glow band.
    canvas.drawRect(
      bandRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0x00E50914),
            AppTheme.primaryRed.withValues(alpha: 0.22 * env),
            const Color(0x00E50914),
          ],
        ).createShader(bandRect),
    );

    // Bright core line.
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, h),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28 * env)
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_LightSweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
// =============================================================================
// PARTICLES
// =============================================================================

/// Subtle floating cinematic particles around the logo.
class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({
    required this.progress,
    required this.cx,
    required this.cy,
  });

  final double progress;
  final double cx;
  final double cy;

  static const int _particleCount = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < _particleCount; i++) {
      final seed = i * 1.618033988749895;
      final angle = (seed * 2.39996) % (math.pi * 2);
      final dist = 40 + ((seed * 73.13) % 140);
      final px = cx + math.cos(angle + progress * 0.6) * dist;
      final py = cy + math.sin(angle + progress * 0.5) * dist * 0.65;

      final life = (math.sin(progress * math.pi * 2 + seed) + 1) * 0.5;
      final alpha = life.clamp(0.0, 1.0) * (i.isEven ? 0.35 : 0.22);
      final radius = (1.0 + (seed % 2.5)).clamp(1.0, 3.0);

      paint.color = i % 3 == 0
          ? AppTheme.primaryRed.withValues(alpha: alpha)
          : Colors.white.withValues(alpha: alpha * 0.8);

      canvas.drawCircle(Offset(px, py), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.cx != cx ||
      oldDelegate.cy != cy;
}

// =============================================================================
// SMOKE / ATMOSPHERE
// =============================================================================

/// Subtle cinematic smoke behind the logo.
class _SmokePainter extends CustomPainter {
  const _SmokePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final cx = w / 2;
    final cy = h * 0.44;

    for (var i = 0; i < 3; i++) {
      final phase = progress * 0.25 + i * 0.33;
      final dx = cx + math.sin(phase * 2.1) * w * 0.28;
      final dy = cy + math.cos(phase * 1.7) * h * 0.12;
      final rw = w * (0.28 + i * 0.08);
      final rh = h * (0.16 + i * 0.04);

      final paint = Paint()
        ..shader =
            RadialGradient(
              radius: 0.9,
              colors: [
                AppTheme.primaryRed.withValues(alpha: 0.025),
                Colors.transparent,
              ],
              stops: const [0.0, 1.0],
            ).createShader(
              Rect.fromCenter(center: Offset(dx, dy), width: rw, height: rh),
            );

      canvas.drawRect(
        Rect.fromCenter(center: Offset(dx, dy), width: rw, height: rh),
        paint,
      );
    }

    // Soft red glow around the logo.
    final glowPaint = Paint()
      ..shader = RadialGradient(
        radius: 0.55,
        colors: [
          AppTheme.primaryRed.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.38));

    canvas.drawCircle(Offset(cx, cy), w * 0.38, glowPaint);
  }

  @override
  bool shouldRepaint(_SmokePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
// =============================================================================
// LENS FLARE
// =============================================================================

/// Elegant red-white lens flare riding along the light sweep.
class _LensFlarePainter extends CustomPainter {
  const _LensFlarePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final env = math.sin(progress * math.pi).clamp(0.0, 1.0);
    final x = w * 0.12 + progress * w * 0.76;
    final y = h * 0.42;

    // Soft outer red halo.
    canvas.drawCircle(
      Offset(x, y),
      w * 0.10,
      Paint()..color = AppTheme.primaryRed.withValues(alpha: 0.10 * env),
    );

    // Mid white halo.
    canvas.drawCircle(
      Offset(x, y),
      w * 0.045,
      Paint()..color = Colors.white.withValues(alpha: 0.08 * env),
    );

    // Bright core.
    canvas.drawCircle(
      Offset(x, y),
      w * 0.012,
      Paint()..color = Colors.white.withValues(alpha: 0.28 * env),
    );

    // Horizontal streak.
    canvas.drawLine(
      Offset(x - w * 0.16, y),
      Offset(x + w * 0.16, y),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10 * env)
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_LensFlarePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// =============================================================================
// SPARKS
// =============================================================================

/// Red energy sparks emitted while the light sweep crosses the logo.
class _SparksPainter extends CustomPainter {
  const _SparksPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final env = math.sin(progress * math.pi).clamp(0.0, 1.0);
    final cx = w * 0.12 + progress * w * 0.76;
    final cy = h * 0.42;

    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 14; i++) {
      final seed = i * 2.399963;
      final angle = seed * 1.7 + progress * 1.4;
      final dist = 10 + ((seed * 41.7) % 90) * progress;
      final px = cx + math.cos(angle) * dist;
      final py = cy + math.sin(angle) * dist * 0.7;

      final life = (math.sin(progress * math.pi * 2 + seed) + 1) * 0.5;
      final alpha = life.clamp(0.0, 1.0) * 0.55 * env;

      paint.color = i.isEven
          ? AppTheme.primaryRed.withValues(alpha: alpha)
          : Colors.white.withValues(alpha: alpha * 0.8);

      canvas.drawCircle(Offset(px, py), 1.0 + (seed % 1.8), paint);
    }
  }

  @override
  bool shouldRepaint(_SparksPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
// =============================================================================
// LOGO LIGHTING (metallic sheen + red rim)
// =============================================================================

/// Metallic sheen + red rim lighting layered over the logo emblem.
class _LogoLightingPainter extends CustomPainter {
  const _LogoLightingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Subtle metallic vertical sheen.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.02),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    // Red rim lighting hugging the logo edges.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.0,
          colors: [
            Colors.transparent,
            AppTheme.primaryRed.withValues(alpha: 0.09),
            AppTheme.primaryRed.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.72, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LogoLightingPainter oldDelegate) => false;
}

// =============================================================================
// BREATHING GLOW
// =============================================================================

/// Subtle breathing glow behind the branding during the final hold.
class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.alpha);

  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final y = h * 0.42;

    final rect = Rect.fromCenter(
      center: Offset(w / 2, y),
      width: w * 0.9,
      height: h * 0.7,
    );

    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [
            AppTheme.primaryRed.withValues(alpha: 0.16 * alpha),
            AppTheme.primaryRed.withValues(alpha: 0.08 * alpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => oldDelegate.alpha != alpha;
}

// =============================================================================
// HELPERS
// =============================================================================

class FadeInWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const FadeInWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<FadeInWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }
}
