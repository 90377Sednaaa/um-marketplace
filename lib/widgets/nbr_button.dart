import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    this.stretch = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Optional leading icon, drawn right before the label.
  final Widget? icon;

  final Color fill;
  final Color labelColor;

  /// Whether the button fills the width of its parent (for full-width
  /// bars) instead of hugging its label.
  final bool stretch;

  /// Compact reduces padding + font so two buttons fit in a dialog row
  /// without a 9 px overflow on narrow phones.
  final bool compact;

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

    final horizontal = widget.compact ? 14.0 : 20.0;
    final vertical = widget.compact ? 12.0 : 14.0;
    final fontSize = widget.compact ? 14.0 : 15.0;
    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      curve: Curves.linear,
      transform: Matrix4.translationValues(
        _pressed ? 0 : UmShadows.card.dx,
        _pressed ? 0 : UmShadows.card.dy,
        0,
      ),
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: widget.stretch ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 8)],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700,
                  fontSize: fontSize,
                  letterSpacing: 0.3,
                  color: labelColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final stack = Stack(
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
    );

    // When not stretching, the button hugs its label — wrap in Align so a
    // parent Column with crossAxisAlignment.stretch doesn't force the shadow
    // to fill the parent width (which causes the huge-shadow artefact in
    // Image 3). When stretching, expand to fill the parent.
    final child = widget.stretch
        ? SizedBox(width: double.infinity, child: stack)
        : Align(alignment: Alignment.center, child: stack);

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: child,
    );
  }
}
