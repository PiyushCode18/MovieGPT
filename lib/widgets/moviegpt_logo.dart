import 'package:flutter/material.dart';

/// MovieGPT brand colors used by the clapperboard logo.
abstract final class MovieGptBrand {
  static const Color red = Color(0xFFE50914);
  static const Color redDeep = Color(0xFF8E060D);
  static const Color redBright = Color(0xFFF21D2C);
  static const Color metalHi = Color(0xFFF4F4F6);
  static const Color metalMid = Color(0xFFB8BAC4);
  static const Color metalLow = Color(0xFF5B5D66);
  static const Color metalDark = Color(0xFF3A3C44);
  static const Color clapperDark = Color(0xFF111111);
  static const Color clapperBody = Color(0xFF1A1A1A);
}

/// Paints the MovieGPT clapperboard logo into [canvas].
///
/// Fully relative design: renders crisply at any size. [glow] (0..1) controls
/// the outer red cinematic halo intensity.
void paintMovieGptEmblem(
  Canvas canvas,
  Size size, {
  double glow = 0.0,
}) {
  final side = size.shortestSide;
  final c = Offset(size.width / 2, size.height / 2);
  final r = side * 0.5;
  final g = glow.clamp(0.0, 1.0);

  // ---- 1. Outer red cinematic halo (strength driven by [glow]). ----
  final haloRect = Rect.fromCircle(center: c, radius: r * 1.22);
  canvas.drawCircle(
    c,
    r * 1.22,
    Paint()
      ..shader = RadialGradient(
        radius: 1.08,
        colors: [
          MovieGptBrand.red.withValues(alpha: (0.12 + 0.35 * g)),
          MovieGptBrand.red.withValues(alpha: 0.03),
          const Color(0x00000000),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(haloRect),
  );

  // Soft warm rim glow.
  final rimRect = Rect.fromCircle(center: c, radius: r * 1.04);
  canvas.drawCircle(
    c,
    r * 1.04,
    Paint()
      ..shader = RadialGradient(
        radius: 0.96,
        colors: [
          const Color(0x00000000),
          MovieGptBrand.red.withValues(alpha: (0.08 + 0.20 * g)),
          const Color(0x00000000),
        ],
        stops: const [0.45, 0.82, 1.0],
      ).createShader(rimRect),
  );

  // ---- 2. Clapperboard body dimensions. ----
  final bodyW = r * 1.72;
  final bodyH = r * 1.52;
  final bodyTop = c.dy - bodyH * 0.48;
  final bodyLeft = c.dx - bodyW * 0.5;
  final bodyRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(bodyLeft, bodyTop, bodyW, bodyH),
    Radius.circular(r * 0.06),
  );

  // Drop shadow behind clapperboard.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        bodyLeft + r * 0.02,
        bodyTop + r * 0.03,
        bodyW,
        bodyH,
      ),
      Radius.circular(r * 0.06),
    ),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
  );

  // ---- 3. Clapperboard dark body. ----
  canvas.drawRRect(
    bodyRect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          MovieGptBrand.clapperBody,
          MovieGptBrand.clapperDark,
          Color(0xFF0A0A0A),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bodyRect.outerRect),
  );

  // Body edge highlight.
  canvas.drawRRect(
    bodyRect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.010
      ..color = Colors.white.withValues(alpha: 0.08),
  );

  // ---- 4. Top clapper strip with red/black diagonal stripes. ----
  final stripH = bodyH * 0.14;
  final stripLeft = bodyLeft + r * 0.03;
  final stripTop = bodyTop + r * 0.03;
  final stripW = bodyW - r * 0.06;
  final stripeCount = 5;
  final sw = stripW / stripeCount;
  for (var i = 0; i < stripeCount; i++) {
    final isRed = i.isEven;
    final sRect = Rect.fromLTWH(stripLeft + i * sw, stripTop, sw + 0.5, stripH);
    final tl = i == 0 ? Radius.circular(r * 0.04) : Radius.zero;
    final tr = i == stripeCount - 1 ? Radius.circular(r * 0.04) : Radius.zero;
    canvas.drawRRect(
      RRect.fromRectAndCorners(sRect, topLeft: tl, topRight: tr),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isRed
              ? const [Color(0xFFF21D2C), MovieGptBrand.red, MovieGptBrand.redDeep]
              : const [Color(0xFF2A2A2A), MovieGptBrand.clapperDark, Color(0xFF111111)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(sRect),
    );
  }

  // Metallic silver border on strip.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(stripLeft, stripTop, stripW, stripH),
      Radius.circular(r * 0.04),
    ),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.010
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFFE0E0E4),
          MovieGptBrand.metalMid,
          Color(0xFF707378),
        ],
      ).createShader(Rect.fromLTWH(stripLeft, stripTop, stripW, stripH)),
  );

  // Hinge line between strip and body.
  final hingeY = stripTop + stripH;
  canvas.drawLine(
    Offset(stripLeft + r * 0.04, hingeY),
    Offset(stripLeft + stripW - r * 0.04, hingeY),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFFC8C8CC),
          MovieGptBrand.metalMid,
          Color(0xFF606064),
        ],
      ).createShader(Rect.fromLTWH(stripLeft, hingeY, stripW, 1))
      ..strokeWidth = side * 0.012
      ..style = PaintingStyle.stroke,
  );

  // ---- 5. Film-reel notches along the left edge. ----
  final notchPaint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFFD8D8DC),
        MovieGptBrand.metalMid,
        Color(0xFF606064),
      ],
    ).createShader(Rect.fromLTWH(bodyLeft, bodyTop, r * 0.08, bodyH));
  final notchCount = 7;
  final notchSpacing = (bodyH - r * 0.16) / (notchCount - 1);
  for (var i = 0; i < notchCount; i++) {
    final ny = bodyTop + r * 0.08 + i * notchSpacing;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bodyLeft + r * 0.02, ny - r * 0.025, r * 0.05, r * 0.05),
        Radius.circular(r * 0.012),
      ),
      notchPaint,
    );
  }

  // ---- 6. Red glow behind the "M". ----
  final mGlowCenter = c + Offset(0, r * 0.08);
  canvas.drawCircle(
    mGlowCenter,
    r * 0.58,
    Paint()
      ..shader = RadialGradient(
        radius: 0.58,
        colors: [
          MovieGptBrand.red.withValues(alpha: (0.30 + 0.25 * g)),
          MovieGptBrand.red.withValues(alpha: 0.08),
          const Color(0x00000000),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: mGlowCenter, radius: r * 0.58)),
  );

  // ---- 6. The large metallic "M". ----
  final bw = r * 1.18; // M width
  final bh = r * 0.95; // M height
  final mCenter = c + Offset(0, r * 0.10);
  final x0 = mCenter.dx - bw / 2;
  final x1 = mCenter.dx + bw / 2;
  final y0 = mCenter.dy - bh / 2;
  final y1 = mCenter.dy + bh / 2;

  final mPath = Path()
    ..moveTo(x0, y1)
    ..lineTo(x0, y0)
    ..lineTo(x0 + 0.28 * bw, y0 + 0.52 * bh)
    ..lineTo(x0 + 0.50 * bw, y0 + 0.12 * bh)
    ..lineTo(x0 + 0.72 * bw, y0 + 0.52 * bh)
    ..lineTo(x1, y0)
    ..lineTo(x1, y1)
    ..lineTo(x0 + 0.72 * bw, y1)
    ..lineTo(x0 + 0.28 * bw, y1)
    ..close();

  // Drop shadow under M.
  final mShadowPath = Path()..addPath(mPath, Offset(0, side * 0.016));
  canvas.drawPath(
    mShadowPath,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.018
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..color = Colors.black.withValues(alpha: 0.55),
  );

  // Metallic M fill.
  final mRect = Rect.fromLTRB(x0, y0, x1, y1);
  canvas.drawPath(
    mPath,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          MovieGptBrand.metalHi,
          Color(0xFFD8DAE2),
          MovieGptBrand.metalMid,
          MovieGptBrand.metalLow,
          MovieGptBrand.metalDark,
        ],
        stops: const [0.0, 0.25, 0.55, 0.80, 1.0],
      ).createShader(mRect),
  );

  // M edge highlight.
  canvas.drawPath(
    mPath,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.008
      ..color = Colors.white.withValues(alpha: 0.22),
  );

  // ---- 7. Red interior valley of the "M" (play/cinema accent). ----
  final vPath = Path()
    ..moveTo(x0 + 0.28 * bw, y0 + 0.52 * bh)
    ..lineTo(x0 + 0.50 * bw, y0 + 0.12 * bh)
    ..lineTo(x0 + 0.72 * bw, y0 + 0.52 * bh)
    ..lineTo(x0 + 0.72 * bw, y1)
    ..lineTo(x0 + 0.28 * bw, y1)
    ..close();
  final vRect = Rect.fromLTRB(x0 + 0.28 * bw, y0, x0 + 0.72 * bw, y1);
  canvas.drawPath(
    vPath,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          MovieGptBrand.redBright,
          MovieGptBrand.red,
          MovieGptBrand.redDeep,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(vRect),
  );

  // ---- 8. Red play triangle in the valley. ----
  final halfH = bh * 0.18;
  final vcy = y0 + bh * 0.74;
  final tri = Path()
    ..moveTo(c.dx - r * 0.10, vcy - halfH)
    ..lineTo(c.dx - r * 0.10, vcy + halfH)
    ..lineTo(c.dx + r * 0.04, vcy)
    ..close();

  // Triangle shadow.
  final triShadow = Path()..addPath(tri, Offset(0, side * 0.012));
  canvas.drawPath(
    triShadow,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.50)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
  );
  // Triangle fill.
  canvas.drawPath(
    tri,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFFF4D5A),
          Colors.white,
          Color(0xFFE8E8EC),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset(c.dx, vcy), radius: r * 0.08),
      ),
  );
  // Triangle edge.
  canvas.drawPath(
    tri,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.005
      ..color = Colors.black.withValues(alpha: 0.25),
  );

  // ---- 9. Top gloss reflection on the clapperboard. ----
  canvas.save();
  canvas.clipRRect(bodyRect);
  final glossRect = Rect.fromCenter(
    center: Offset(c.dx, bodyTop + bodyH * 0.22),
    width: bodyW * 0.88,
    height: bodyH * 0.22,
  );
  canvas.drawRect(
    glossRect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(glossRect),
  );
  canvas.restore();

  // ---- 10. Bottom subtle reflection. ----
  canvas.save();
  canvas.clipRRect(bodyRect);
  final reflRect = Rect.fromCenter(
    center: Offset(c.dx, bodyTop + bodyH * 0.82),
    width: bodyW * 0.60,
    height: bodyH * 0.10,
  );
  canvas.drawRect(
    reflRect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(reflRect),
  );
  canvas.restore();
}

/// [CustomPainter] that draws the clapperboard logo via [paintMovieGptEmblem].
class MovieGptLogoPainter extends CustomPainter {
  const MovieGptLogoPainter({this.glow = 0.0});

  /// 0..1 strength of the outer red cinematic glow.
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    paintMovieGptEmblem(canvas, size, glow: glow);
  }

  @override
  bool shouldRepaint(MovieGptLogoPainter oldDelegate) =>
      oldDelegate.glow != glow;
}

/// Reusable square wrapper around the painted clapperboard logo.
///
/// [size] forces a fixed square; when `null` the widget expands to the parent
/// constraints. [glow] (0..1) raises the outer red halo.
class MovieGptLogo extends StatelessWidget {
  const MovieGptLogo({
    super.key,
    this.size,
    this.glow = 0.0,
  });

  /// Stable identity so widgets/tests can locate the logo.
  static const Key logoKey = Key('moviegpt_logo_emblem');

  final double? size;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final paint = RepaintBoundary(
      child: CustomPaint(
        painter: MovieGptLogoPainter(glow: glow),
        child: const SizedBox.expand(),
      ),
    );
    final sized =
        size == null ? paint : SizedBox.square(dimension: size!, child: paint);
    return Semantics(
      label: 'MovieGPT clapperboard logo',
      image: true,
      child: ExcludeSemantics(child: sized),
    );
  }
}
