import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/listing_store.dart';
import '../theme/app_theme.dart';
import '../widgets/photo_placeholder.dart';
import 'money_format.dart';

/// The product card (DESIGN.md §5) — polished brutal edition:
/// white fill, 2 dp ink border, 4 dp hard shadow; photo top (4:3),
/// price in green weight 800, category chip in `goldSoft`, condition/
/// location as pill + icon caption. Press translates onto shadow.
class ListingCard extends StatefulWidget {
  const ListingCard({super.key, required this.listing, this.onTap});

  final Listing listing;
  final VoidCallback? onTap;

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final listing = widget.listing;

    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      curve: Curves.linear,
      clipBehavior: Clip.antiAlias,
      transform: Matrix4.translationValues(
        _pressed ? 0 : 4,
        _pressed ? 0 : 4,
        0,
      ),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (listing.photos.isEmpty)
                  const PhotoPlaceholder()
                else
                  Image.memory(
                    listing.photos.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const PhotoPlaceholder(),
                  ),
                // Photo count badge when 2 images.
                if (listing.photos.length > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: UmColors.surface,
                        border: Border.all(color: UmColors.ink, width: 1.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.collections_outlined,
                              size: 12, color: UmColors.ink),
                          const SizedBox(width: 3),
                          Text(
                            '${listing.photos.length}',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: UmColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Subtle top gradient for legibility if we ever overlay text.
                if (listing.status == 'sold')
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Transform.rotate(
                      angle: -0.04,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: UmColors.gold,
                          border: Border.all(color: UmColors.ink, width: 1.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'SOLD',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.8,
                            color: UmColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatPesos(listing.price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: UmColors.success,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.25,
                    color: UmColors.onSurface,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: UmColors.goldSoft,
                        border: Border.all(color: UmColors.ink, width: 1.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        listing.category,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: UmColors.ink,
                        ),
                      ),
                    ),
                    if (listing.condition.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: UmColors.surface,
                          border: Border.all(
                              color: UmColors.ink.withValues(alpha: 0.85),
                              width: 1.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          listing.condition,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: UmColors.mutedForeground,
                          ),
                        ),
                      ),
                    if (listing.location?.isNotEmpty ?? false)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 11, color: UmColors.mutedForeground),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              listing.location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                                color: UmColors.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: Stack(
        children: [
          if (enabled)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: UmColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          face,
        ],
      ),
    );
  }
}
