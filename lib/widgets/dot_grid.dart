import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Default ink dot color: [UmColors.ink] at ~14% opacity (`#24000000`).
/// Dark enough to read as notebook paper on white in daylight.
const Color kDefaultDotGridColor = Color(0x24000000);

/// Neubrutalist campus notebook dot-grid custom painter.
///
/// Draws an evenly spaced grid of ink dots across the canvas (~22dp spacing,
/// ~1.6dp radius, 14% ink opacity) evoking student graph/sketchbook paper.
class DotGridPainter extends CustomPainter {
  const DotGridPainter({
    this.spacing = 22.0,
    this.dotRadius = 1.6,
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
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        !spacing.isFinite ||
        !dotRadius.isFinite ||
        size.width <= 0 ||
        size.height <= 0 ||
        spacing <= 0 ||
        dotRadius <= 0) {
      return;
    }

    final minDimension = dotRadius * 2;
    if (size.width < minDimension || size.height < minDimension) {
      return;
    }

    final availableWidth = size.width - minDimension;
    final availableHeight = size.height - minDimension;
    final countX = (availableWidth / spacing).floor();
    final countY = (availableHeight / spacing).floor();

    final startX = (size.width - (countX * spacing)) / 2;
    final startY = (size.height - (countY * spacing)) / 2;

    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (int j = 0; j <= countY; j++) {
      final y = startY + (j * spacing);
      for (int i = 0; i <= countX; i++) {
        final x = startX + (i * spacing);
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DotGridPainter &&
        other.spacing == spacing &&
        other.dotRadius == dotRadius &&
        other.dotColor == dotColor;
  }

  @override
  int get hashCode => Object.hash(spacing, dotRadius, dotColor);
}

/// A background container that paints a subtle Neubrutalist dot grid behind [child].
///
/// Wraps the custom paint in a [RepaintBoundary] and [ExcludeSemantics] for
/// optimal performance and accessibility.
class DotGridBackground extends StatelessWidget {
  const DotGridBackground({
    super.key,
    this.spacing = 22.0,
    this.dotRadius = 1.6,
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
    // Positioned.fill gives the grid tight finite bounds; Size.zero lets
    // the CustomPaint take exactly the Stack size instead of requesting
    // infinity (which stays invisible under unbounded constraints).
    final grid = RepaintBoundary(
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
    );

    final currentChild = child;
    if (currentChild == null) {
      return ColoredBox(color: backgroundColor, child: grid);
    }

    return ColoredBox(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: grid),
          currentChild,
        ],
      ),
    );
  }
}
