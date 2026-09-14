import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../state/auth_providers.dart';
import '../state/guest_provider.dart';
import '../theme/app_theme.dart';
import 'main_navigation_screen.dart';

/// Premium cinematic MovieGPT login screen.
///
/// Sign-in methods:
/// - Continue with Google (Android + Web)
/// - Continue with Email (sign in + registration)
/// - Skip for now (Guest Mode)
///
/// NOTE: Phone number authentication has been fully removed from MovieGPT.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// Which button is currently processing, so each button can show its own
  /// inline progress indicator without disabling the whole page UI.
  String? _busyMethod;

  // ---------------------------------------------------------------------------
  // FEEDBACK / NAVIGATION HELPERS
  // ---------------------------------------------------------------------------

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.primaryRed,
        ),
      );
  }

  void _navigateToHome() {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  void _continueGuest() {
    ref.read(guestModeProvider.notifier).setGuestMode(true);
    _navigateToHome();
  }

  Future<void> _runAuthAction(
    String methodKey,
    Future<void> Function() action,
  ) async {
    if (_busyMethod != null) return;

    setState(() => _busyMethod = methodKey);

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busyMethod = null);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // GOOGLE SIGN-IN
  // ---------------------------------------------------------------------------

  Future<void> _signInWithGoogle() async {
    await _runAuthAction('google', () async {
      try {
        final auth = ref.read(authServiceProvider);

        await auth.signInWithGoogle();

        // Successful authentication clears explicit guest mode.
        await ref.read(guestModeProvider.notifier).setGuestMode(false);

        _navigateToHome();
      } on MovieGptAuthException catch (e) {
        _showError(e.message);
      } on PlatformException catch (e) {
        _showError(
          e.code == 'sign_in_canceled'
              ? 'Sign-in cancelled.'
              : 'Google sign-in failed. Please try again.',
        );
      } catch (_) {
        _showError('Google sign-in failed. Please check your connection.');
      }
    });
  }

  // ---------------------------------------------------------------------------
  // EMAIL SIGN-IN
  // ---------------------------------------------------------------------------

  Future<void> _openEmailSignIn() async {
    if (_busyMethod != null) return;

    setState(() => _busyMethod = 'email');

    try {
      final bool authenticated = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const EmailAuthSheet(),
          ) ??
          false;

      if (authenticated) {
        _navigateToHome();
      }
    } finally {
      if (mounted) {
        setState(() => _busyMethod = null);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final Size size = media.size;

    final bool wide = size.width >= 640;
    final double contentWidth = wide ? 440 : double.infinity;
    final double logoSize = (size.height * 0.13).clamp(84.0, 118.0);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // ---------------------------------------------------------
          // Cinematic background lighting.
          // ---------------------------------------------------------
          const _CinematicBackdrop(),

          // ---------------------------------------------------------
          // Scrollable content.
          // ---------------------------------------------------------
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---------------------------------------------
                      // Brand emblem + wordmark
                      // ---------------------------------------------
                      Center(
                        child: Image.asset(
                          'assets/images/moviegpt_logo.png',
                          width: logoSize,
                          height: logoSize,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Center(
                        child: ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.primaryGradient.createShader(bounds),
                          child: const Text(
                            'MovieGPT',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 44),

                      // ---------------------------------------------
                      // Headline
                      // ---------------------------------------------
                      const Text(
                        'Welcome Back!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Sign in to continue your cinematic journey',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ---------------------------------------------
                      // Continue with Google
                      // ---------------------------------------------
                      AuthButton(
                        busy: _busyMethod == 'google',
                        enabled: _busyMethod == null,
                        onTap: _signInWithGoogle,
                        background: AppTheme.cardDark,
                        border: Border.all(color: AppTheme.cardBorder),
                        foreground: AppTheme.textPrimary,
                        leading: _busyMethod == 'google'
                            ? const ButtonSpinner(
                                color: AppTheme.textSecondary)
                            : const GoogleGIcon(size: 22),
                        label: 'Continue with Google',
                      ),

                      const SizedBox(height: 14),

                      // ---------------------------------------------
                      // Continue with Email
                      // ---------------------------------------------
                      AuthButton(
                        busy: false,
                        enabled: _busyMethod == null,
                        onTap: _openEmailSignIn,
                        background: Colors.transparent,
                        gradient: AppTheme.primaryGradient,
                        foreground: Colors.white,
                        leading: const Icon(
                          Icons.mail_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        label: 'Continue with Email',
                        boxShadow: BoxShadow(
                          color:
                              AppTheme.primaryRed.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ),

                      const SizedBox(height: 26),

                      // ---------------------------------------------
                      // Guest mode
                      // ---------------------------------------------
                      Center(
                        child: TextButton(
                          onPressed:
                              _busyMethod == null ? _continueGuest : null,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          child: Text.rich(
                            TextSpan(
                              text: 'Skip for now ',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: '(Guest Mode)',
                                  style: TextStyle(
                                    color: AppTheme.textMuted
                                        .withValues(alpha: 0.9),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ---------------------------------------------
                      // Footer tagline
                      // ---------------------------------------------
                      const Text(
                        'AI MOVIES. ENDLESS DISCOVERIES.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.4,
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
  }
}

// =============================================================================
// CINEMATIC BACKDROP
// =============================================================================

/// Layered cinematic lighting used behind the login content.
///
/// Purely decorative: a soft red key light from the top, a faint violet
/// counter-glow near the bottom and a gentle vignette so the buttons read
/// clearly on large desktop windows too.
class _CinematicBackdrop extends StatelessWidget {
  const _CinematicBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Red key light from the top left, like a cinema projector.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.2, -1.1),
                  radius: 1.15,
                  colors: [Color(0x33E50914), Color(0x00000000)],
                  stops: [0.0, 1.0],
                ),
              ),
            ),

            // Violet counter-glow from the bottom right (AI accent).
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.9, 1.2),
                  radius: 1.1,
                  colors: [Color(0x2A7701D0), Color(0x00000000)],
                  stops: [0.0, 1.0],
                ),
              ),
            ),

            // Vignette keeps the edges deep black like a cinema frame.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PREMIUM BUTTON
// =============================================================================

/// Rounded premium authentication button with an optional leading icon,
/// gradient background and inline busy indicator.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.busy,
    required this.enabled,
    required this.onTap,
    required this.background,
    required this.foreground,
    required this.leading,
    required this.label,
    this.gradient,
    this.border,
    this.boxShadow,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final Widget leading;
  final String label;
  final Gradient? gradient;
  final Border? border;
  final BoxShadow? boxShadow;

  @override
  Widget build(BuildContext context) {
    final double height =
        MediaQuery.of(context).size.height < 640 ? 52 : 56;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.72,
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: gradient == null ? background : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            border: border,
            boxShadow: boxShadow == null ? null : <BoxShadow>[boxShadow!],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              busy ? const ButtonSpinner() : leading,
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small circular progress indicator used inside auth buttons while busy.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        strokeCap: StrokeCap.round,
        color: color,
      ),
    );
  }
}

// =============================================================================
// GOOGLE ICON (official four-colour "G")
// =============================================================================

/// Draws the official multi-colour Google "G" mark.
class GoogleGIcon extends StatelessWidget {
  const GoogleGIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  // Canonical 18x18 Google "G" geometry.
  // NOTE: Path() is not const-constructible, so this is `final`.
  static final List<Path> _paths = [
    // Blue
    Path()
      ..moveTo(17.64, 9.2045)
      ..cubicTo(17.64, 8.5664, 17.5827, 7.9527, 17.4764, 7.3636)
      ..lineTo(9.0, 7.3636)
      ..lineTo(9.0, 10.845)
      ..lineTo(13.8436, 10.845)
      ..cubicTo(13.635, 11.97, 13.0009, 12.9232, 12.0477, 13.5614)
      ..lineTo(12.0477, 15.8195)
      ..lineTo(14.9564, 15.8195)
      ..cubicTo(16.6582, 14.2527, 17.64, 11.9455, 17.64, 9.2045)
      ..close(),
    // Green
    Path()
      ..moveTo(9.0, 18.0)
      ..cubicTo(11.43, 18.0, 13.4673, 17.194, 14.9564, 15.8195)
      ..lineTo(12.0477, 13.5614)
      ..cubicTo(11.2418, 14.1014, 10.2109, 14.4205, 9.0, 14.4205)
      ..cubicTo(6.656, 14.4205, 4.6718, 12.8373, 3.964, 10.71)
      ..lineTo(0.9573, 10.71)
      ..lineTo(0.9573, 13.0418)
      ..cubicTo(2.4382, 15.9832, 5.4818, 18.0, 9.0, 18.0)
      ..close(),
    // Yellow
    Path()
      ..moveTo(3.964, 10.71)
      ..cubicTo(3.784, 10.17, 3.6818, 9.5932, 3.6818, 9.0)
      ..cubicTo(3.6818, 8.4068, 3.7841, 7.83, 3.9641, 7.29)
      ..lineTo(3.9641, 4.9582)
      ..lineTo(0.9573, 4.9582)
      ..cubicTo(0.3477, 6.1732, 0.0, 7.5477, 0.0, 9.0)
      ..cubicTo(0.0, 10.4523, 0.3477, 11.8268, 0.9573, 13.0418)
      ..lineTo(3.964, 10.71)
      ..close(),
    // Red
    Path()
      ..moveTo(9.0, 3.5795)
      ..cubicTo(10.3214, 3.5795, 11.5077, 4.0336, 12.4405, 4.9255)
      ..lineTo(15.0218, 2.3441)
      ..cubicTo(13.4632, 0.8918, 11.426, 0.0, 9.0, 0.0)
      ..cubicTo(5.4818, 0.0, 2.4382, 2.0168, 0.9573, 4.9582)
      ..lineTo(3.964, 7.29)
      ..cubicTo(4.6718, 5.1627, 6.656, 3.5795, 9.0, 3.5795)
      ..close(),
  ];

  static const List<Color> _colors = [
    Color(0xFF4285F4), // blue
    Color(0xFF34A853), // green
    Color(0xFFFBBC05), // yellow
    Color(0xFFEA4335), // red
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 18.0;

    canvas.save();
    canvas.scale(scale, scale);

    for (var i = 0; i < _paths.length; i++) {
      canvas.drawPath(_paths[i], Paint()..color = _colors[i]);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// EMAIL AUTH SHEET
// =============================================================================

/// Cinematic bottom sheet hosting both Email sign-in and registration.
class EmailAuthSheet extends ConsumerStatefulWidget {
  const EmailAuthSheet({super.key});

  @override
  ConsumerState<EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends ConsumerState<EmailAuthSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isCreateMode = false;
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.primaryRed,
        ),
      );
  }

  String? _validateEmail(String? value) {
    final String email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Please enter your email address.';
    }

    if (!AuthService.isValidEmail(email)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final String password = value?.trim() ?? '';

    if (!_isCreateMode) {
      return password.isEmpty ? 'Please enter your password.' : null;
    }

    return AuthService.validatePassword(password);
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final bool valid = _formKey.currentState?.validate() ?? false;

    if (!valid) return;

    setState(() => _submitting = true);

    try {
      final auth = ref.read(authServiceProvider);

      bool sessionStarted = false;

      if (_isCreateMode) {
        final result = await auth.registerWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
        sessionStarted = result.sessionStarted;

        if (!sessionStarted) {
          if (!mounted) return;
          setState(() => _submitting = false);
          _showError(
            'Account created! Please check your email to confirm your account.',
          );
          return;
        }
      } else {
        await auth.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
        sessionStarted = true;
      }

      if (sessionStarted) {
        // Successful authentication clears explicit guest mode.
        await ref.read(guestModeProvider.notifier).setGuestMode(false);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on MovieGptAuthException catch (e) {
      if (!mounted) return;

      setState(() => _submitting = false);

      _showError(e.message);
    } catch (e) {
      debugPrint('[MovieGPT] Email auth unexpected error: $e');

      if (!mounted) return;

      setState(() => _submitting = false);

      _showError(
        'Authentication failed. Please check your connection and try again.',
      );
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? helperText,
    Widget? suffixIcon,
    Color focusedColor = AppTheme.primaryViolet,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textMuted),
      helperText: helperText,
      helperStyle: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 11,
      ),
      prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppTheme.bgDark,
      errorStyle: const TextStyle(color: AppTheme.primaryRed),
      enabledBorder: border(AppTheme.cardBorder),
      focusedBorder: border(focusedColor),
      errorBorder: border(AppTheme.primaryRed),
      focusedErrorBorder: border(AppTheme.primaryRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppTheme.cardBorder),
            left: BorderSide(color: AppTheme.cardBorder),
            right: BorderSide(color: AppTheme.cardBorder),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.disabled,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle.
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title + subtitle.
                  Text(
                    _isCreateMode ? 'Create your account' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    _isCreateMode
                        ? 'Start your cinematic journey with MovieGPT'
                        : 'Sign in to continue your cinematic journey',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Sign in / create toggle.
                  AuthModeToggle(
                    isCreateMode: _isCreateMode,
                    onChanged: (create) =>
                        setState(() => _isCreateMode = create),
                  ),

                  const SizedBox(height: 22),

                  // Email field.
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    enabled: !_submitting,
                    validator: _validateEmail,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: _fieldDecoration(
                      label: 'Email address',
                      icon: Icons.alternate_email_rounded,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Password field.
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    enabled: !_submitting,
                    validator: _validatePassword,
                    onFieldSubmitted: (_) => _submit(),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: _fieldDecoration(
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      helperText: _isCreateMode
                          ? 'At least 8 characters with letters and numbers.'
                          : null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                        onPressed: _submitting
                            ? null
                            : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit button.
                  GestureDetector(
                    onTap: _submitting ? null : _submit,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppTheme.primaryRed.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _submitting
                            ? const ButtonSpinner()
                            : Text(
                                _isCreateMode ? 'Create Account' : 'Sign In',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

// =============================================================================
// MODE TOGGLE (SIGN IN / CREATE ACCOUNT)
// =============================================================================

class AuthModeToggle extends StatelessWidget {
  const AuthModeToggle({
    super.key,
    required this.isCreateMode,
    required this.onChanged,
  });

  final bool isCreateMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segment(label: 'Sign In', selected: !isCreateMode),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _segment(
              label: 'Create Account',
              selected: isCreateMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required bool selected,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryRed : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}