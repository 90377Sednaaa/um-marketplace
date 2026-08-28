import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Neo-brutal loader — thick ink border, hard shadow, flat fill, rotating
/// inner square/arc. No gradients, no blur.
class BrutalLoader extends StatefulWidget {
  const BrutalLoader({super.key, this.size = 48, this.stroke = 3});

  final double size;
  final double stroke;

  @override
  State<BrutalLoader> createState() => _BrutalLoaderState();
}

class _BrutalLoaderState extends State<BrutalLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inner = widget.size * 0.58;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hard shadow + ink border square
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: UmColors.surface,
              border: Border.all(color: UmColors.ink, width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: UmColors.ink,
                  offset: UmShadows.card,
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          // Rotating inner brutal element — gold square with ink border
          RotationTransition(
            turns: _ctrl,
            child: Container(
              width: inner,
              height: inner,
              decoration: BoxDecoration(
                color: UmColors.gold,
                border: Border.all(color: UmColors.ink, width: widget.stroke),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Container(
                  width: inner * 0.38,
                  height: inner * 0.38,
                  decoration: BoxDecoration(
                    color: UmColors.ink,
                    borderRadius: BorderRadius.circular(2),
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

/// Small inline brutal circle for button busy states.
class BrutalInlineLoader extends StatefulWidget {
  const BrutalInlineLoader({super.key, this.size = 20});

  final double size;

  @override
  State<BrutalInlineLoader> createState() => _BrutalInlineLoaderState();
}

class _BrutalInlineLoaderState extends State<BrutalInlineLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _ctrl,
        child: Container(
          decoration: BoxDecoration(
            color: UmColors.surface,
            border: Border.all(color: UmColors.ink, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                color: UmColors.gold,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: UmColors.ink, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
