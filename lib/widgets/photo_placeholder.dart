import 'package:flutter/material.dart';

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
        Icons.image_not_supported_outlined,
        size: 32,
        color: UmColors.mutedForeground,
      ),
    );
  }
}