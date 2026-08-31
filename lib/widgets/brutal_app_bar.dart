import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Modernized Neo Brutalism AppBar for pushed screens:
///
/// Maroon (UM primary) to add color against the mostly-white canvas —
/// 3dp ink bottom border + hard shadow, brutal white back button
/// (40dp square, 2dp border, 3dp shadow) and a gold pill title with
/// ink border. Keeps the SAME text strings ('LISTING',
/// 'NOTIFICATIONS', 'MODERATION') so existing widget tests still find
/// them via `find.text`.
class BrutalAppBar extends StatelessWidget {
  const BrutalAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.leadingIcon,
    this.subtitle,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final IconData? leadingIcon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: UmColors.primary,
        border: Border(bottom: BorderSide(color: UmColors.ink, width: 3)),
        boxShadow: [
          BoxShadow(
            color: UmColors.ink,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
        children: [
          BrutalIconButton(
            icon: LucideIcons.arrowLeft300,
            tooltip: 'Back',
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
          // Title pill — gold, ink border, hard shadow, icon + uppercase label.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: UmColors.gold,
              border: Border.all(color: UmColors.ink, width: 2),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: UmColors.ink,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 14, color: UmColors.ink),
                  const SizedBox(width: 6),
                ],
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.1,
                    color: UmColors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: UmColors.surface,
                      border: Border.all(color: UmColors.ink, width: 1.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      subtitle!,
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: UmColors.ink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class BrutalIconButton extends StatefulWidget {
  const BrutalIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    required this.onTap,
    this.fill = UmColors.surface,
    this.iconColor = UmColors.ink,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;
  final Color fill;
  final Color iconColor;

  @override
  State<BrutalIconButton> createState() => _BrutalIconButtonState();
}

class _BrutalIconButtonState extends State<BrutalIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? '',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.linear,
          transform: Matrix4.translationValues(
            _pressed ? 2 : 0,
            _pressed ? 2 : 0,
            0,
          ),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.fill,
            border: Border.all(color: UmColors.ink, width: 2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _pressed
                ? null
                : const [
                    BoxShadow(
                      color: UmColors.ink,
                      offset: Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Icon(widget.icon, size: 20, color: widget.iconColor),
        ),
      ),
    );
  }
}
