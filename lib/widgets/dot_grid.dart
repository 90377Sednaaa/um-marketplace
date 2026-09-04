import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Default ink dot color: [UmColors.ink] at ~8% opacity (`#14000000`).
const Color kDefaultDotGridColor = Color(0x14000000);

/// Neubrutalist campus notebook dot-grid custom painter.
///
/// Draws an evenly spaced grid of ink dots across the canvas (~24dp spacing,
/// ~1.3dp radius, 8% ink opacity) evoking student graph/sketchbook paper.
class DotGridPainter extends CustomPainter {
  const DotGridPainter({
    this.spacing = 24.0,
    this.dotRadius = 1.3,
    this.dotColor = kDefaultDotGridColor,
  });

  /// The distance between adjacent dot centers in logical pixels.
  final double spacing;

  /// The radius of each dot in logical pixels.
  final double dotRadius;

  /// The color of each dot.
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || spacing <= 0 || dotRadius <= 0) {
      return;
    }

    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) {
    return oldDelegate.spacing != spacing ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.dotColor != dotColor;
  }
}

/// A background container that paints a subtle Neubrutalist dot grid behind [child].
///
/// Wraps the custom paint in a [RepaintBoundary] and [ExcludeSemantics] for
/// optimal performance and accessibility.
class DotGridBackground extends StatelessWidget {
  const DotGridBackground({
    super.key,
    this.spacing = 24.0,
    this.dotRadius = 1.3,
    this.dotColor = kDefaultDotGridColor,
    this.backgroundColor = UmColors.background,
    this.child,
  });

  /// The distance between adjacent dot centers in logical pixels.
  final double spacing;

  /// The radius of each dot in logical pixels.
  final double dotRadius;

  /// The color of the dots.
  final Color dotColor;

  /// The canvas background color behind the dot grid.
  final Color backgroundColor;

  /// The widget content rendered above the dot grid background.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: DotGridPainter(
                    spacing: spacing,
                    dotRadius: dotRadius,
                    dotColor: dotColor,
                  ),
                  isComplex: true,
                  willChange: false,
                ),
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}
