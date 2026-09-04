import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// The UM Marketplace logo (neubrutalist campus edition).
///
/// Evolves the original inline `Ga` sticker placeholder into a shared asset:
/// gold block, 2dp ink border, hard offset shadow, Space Grotesk 900 `Ga`
/// with a maroon trade-bar. [UmMark] is the icon-only mark used in the
/// auth hero and the brand band; [UmLogo] pairs it with the wordmark.
///
/// SVG sources live in `assets/logos/` ([um_mark.svg] / [um_logo.svg]) for
/// store listings and docs — in-app we draw with Flutter widgets so the
/// lettermark always uses the bundled Space Grotesk cut.
class UmMark extends StatelessWidget {
  const UmMark({super.key, this.size = 40, this.semanticsLabel});

  /// Face size (logical px). Shadow sits inside the widget box so nothing clips.
  final double size;

  /// Accessibility label. Defaults to `UM Marketplace logo`.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final face = size;
    final fontSize = size * 0.44;
    final barWidth = size * 0.5;
    final barHeight = size * 0.08;
    return Semantics(
      label: semanticsLabel ?? 'UM Marketplace logo',
      image: true,
      child: Transform.rotate(
        angle: -0.04,
        child: SizedBox(
          width: face + 3,
          height: face + 3,
          child: Container(
            margin: const EdgeInsets.only(right: 3, bottom: 3),
            decoration: BoxDecoration(
              color: UmColors.gold,
              border: Border.all(color: UmColors.ink, width: 2),
              borderRadius: BorderRadius.circular(face * 0.18),
              boxShadow: const [
                BoxShadow(
                  color: UmColors.ink,
                  offset: UmShadows.small,
                  blurRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Ga',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w900,
                        fontSize: fontSize,
                        height: 1.0,
                        letterSpacing: 1.0,
                        color: UmColors.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Container(
                      width: barWidth,
                      height: barHeight.clamp(3.0, 6.0),
                      decoration: BoxDecoration(
                        color: UmColors.primary,
                        border: Border.all(color: UmColors.ink, width: 1.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal lockup: [UmMark] + `UM MARKETPLACE` wordmark.
///
/// Used on larger headers (e.g. auth hero). Set [dark] when the lockup
/// sits on the maroon hero panel so the wordmark renders in white.
class UmLogo extends StatelessWidget {
  const UmLogo({super.key, this.markSize = 44, this.dark = false});

  final double markSize;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        UmMark(size: markSize),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'UM MARKETPLACE',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.0,
                height: 1.0,
                color: dark ? UmColors.onPrimary : UmColors.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: UmColors.surface,
                border: Border.all(color: UmColors.ink, width: 2),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                    color: UmColors.ink,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                'STUDENT EXCHANGE',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  color: UmColors.ink,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// SVG-backed mark for contexts where a raster/vector asset is required
/// (docs, store listing previews). In-app headers should prefer [UmMark]
/// so text stays in the bundled Space Grotesk cut.
class UmMarkSvg extends StatelessWidget {
  const UmMarkSvg({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logos/um_mark.svg',
      width: size,
      height: size,
      semanticsLabel: 'UM Marketplace logo',
    );
  }
}

/// SVG-backed horizontal lockup (`assets/logos/um_logo.svg`).
class UmLogoSvg extends StatelessWidget {
  const UmLogoSvg({super.key, this.height = 64});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logos/um_logo.svg',
      height: height,
      semanticsLabel: 'UM Marketplace logo',
    );
  }
}
