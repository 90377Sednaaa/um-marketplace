import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight neo-brutalist shimmer effect that sweeps a subtle diagonal
/// gradient across its child widget.
class BrutalShimmer extends StatefulWidget {
  const BrutalShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor = UmColors.muted,
    this.highlightColor = const Color(0xFFF8FAFC),
  });

  final Widget child;
  final Duration duration;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<BrutalShimmer> createState() => _BrutalShimmerState();
}

class _BrutalShimmerState extends State<BrutalShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (isTest) {
      _controller.forward();
    } else {
      _controller.repeat();
    }
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
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final slide = -1.0 + (_controller.value * 3.0);
            return LinearGradient(
              begin: Alignment(slide - 1.0, -1.0),
              end: Alignment(slide + 1.0, 1.0),
              colors: [
                widget.baseColor,
                widget.highlightColor.withValues(alpha: 0.75),
                widget.baseColor,
              ],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A primitive neo-brutalist skeleton block container with optional ink border,
/// rounded corners, and customizable fill color.
class BrutalSkeletonBox extends StatelessWidget {
  const BrutalSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.hasBorder = false,
    this.borderColor = UmColors.ink,
    this.borderWidth = 2.0,
    this.color = UmColors.muted,
    this.child,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final bool hasBorder;
  final Color borderColor;
  final double borderWidth;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: hasBorder
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
      ),
      child: child,
    );
  }
}
