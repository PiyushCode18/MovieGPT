import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A lightweight shimmer placeholder used while image assets load.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double radius;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = 18,
    this.borderRadius,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(
      begin: -1.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
      builder: (context, _) {
        return ClipRRect(
          borderRadius:
              widget.borderRadius ?? BorderRadius.circular(widget.radius),
          child: Container(
            width: widget.width,
            height: widget.height,
            color: AppTheme.cardLow,
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [AppTheme.cardLow, AppTheme.cardMid, AppTheme.cardLow],
                stops: const [0.0, 0.5, 1.0],
                transform: _SlideGradient(_animation.value),
              ).createShader(bounds),
              blendMode: BlendMode.srcATop,
              child: Container(
                width: widget.width,
                height: widget.height,
                color: AppTheme.cardMid,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double value;
  const _SlideGradient(this.value);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * value, 0, 0);
  }
}

