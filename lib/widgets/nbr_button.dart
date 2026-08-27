import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Solid block button with the DESIGN.md §5 neubrutalist treatment:
/// 2 dp ink border, 8 dp radius, a 4 dp hard offset shadow (blur 0), and a
/// mechanical press — the button translates onto its shadow on tap-down and
/// snaps back on release (80 ms, linear).
class NbrButton extends StatefulWidget {
  const NbrButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fill = UmColors.primary,
    this.labelColor = UmColors.onPrimary,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Optional leading icon, drawn right before the label.
  final Widget? icon;

  final Color fill;
  final Color labelColor;

  @override
  State<NbrButton> createState() => _NbrButtonState();
}

class _NbrButtonState extends State<NbrButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final fill = enabled ? widget.fill : UmColors.muted;
    final labelColor = enabled ? widget.labelColor : UmColors.mutedForeground;

    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      curve: Curves.linear,
      transform: Matrix4.translationValues(
        _pressed ? 0 : 4,
        _pressed ? 0 : 4,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            widget.icon!,
            const SizedBox(width: 10),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: labelColor,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: Stack(
        children: [
          // Hard offset shadow: sits behind the face, uncovered when the
          // face translates away at rest (disabled buttons have no shadow).
          if (enabled)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: UmColors.ink,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          face,
        ],
      ),
    );
  }
}