import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'brutal_dialog.dart';
import 'nbr_button.dart';

/// Brutal-styled confirmation dialog with spring pop-in animation (3dp ink border,
/// 5dp hard shadow, and mechanical buttons). Returns `true` when confirmed,
/// `false`/`null` when dismissed or cancelled — callers treat `!= true` as
/// "keep the current state".
Future<bool?> showBrutalConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool isDestructive = true,
}) {
  return showBrutalGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: UmColors.surface,
          border: Border.all(color: UmColors.ink, width: 3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: UmColors.ink, offset: Offset(5, 5), blurRadius: 0),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? UmColors.destructive
                        : UmColors.primary,
                    border: Border.all(color: UmColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isDestructive
                        ? LucideIcons.triangleAlert500
                        : LucideIcons.helpCircle500,
                    size: 20,
                    color: UmColors.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: isDestructive
                          ? UmColors.destructive
                          : UmColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1.45,
                color: UmColors.onSurface,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: NbrButton(
                    label: cancelLabel,
                    fill: UmColors.surface,
                    labelColor: UmColors.ink,
                    compact: true,
                    stretch: true,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NbrButton(
                    label: confirmLabel,
                    fill:
                        isDestructive ? UmColors.destructive : UmColors.primary,
                    labelColor: UmColors.onPrimary,
                    compact: true,
                    stretch: true,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
