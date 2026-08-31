import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// The DESIGN.md §5 empty-state artwork for missing or undecodable photos:
/// a `muted` block with an outline icon. Shared by listing cards and the
/// listing detail hero so both surfaces render the same placeholder.
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: UmColors.muted,
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.imageOff300,
        size: 32,
        color: UmColors.mutedForeground,
      ),
    );
  }
}