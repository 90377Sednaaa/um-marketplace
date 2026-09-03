import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.linear,
        transform: Matrix4.translationValues(
          _pressed ? 2 : 0,
          _pressed ? 2 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: UmColors.surface,
          border: Border.all(color: UmColors.ink, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _pressed
              ? null
              : const [
                  BoxShadow(
                    color: UmColors.ink,
                    offset: UmShadows.card,
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: UmColors.muted,
                  border: Border.all(color: UmColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
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
                    // Photo count badge when multiple images
                    if (listing.photos.length > 1)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: UmColors.surface,
                            border: Border.all(color: UmColors.ink, width: 1.5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.images500,
                                size: 10,
                                color: UmColors.ink,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${listing.photos.length}',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  color: UmColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // SOLD status badge
                    if (listing.status == 'sold')
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Transform.rotate(
                          angle: -0.04,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: UmColors.gold,
                              border: Border.all(
                                color: UmColors.ink,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'SOLD',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                                letterSpacing: 0.6,
                                color: UmColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          listing.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: UmColors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatPesos(listing.price),
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: UmColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: UmColors.surface,
                          border: Border.all(color: UmColors.ink, width: 1.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          listing.category,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            fontSize: 9.5,
                            color: UmColors.ink,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (listing.condition.isNotEmpty)
                        Text(
                          listing.condition,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                            color: UmColors.mutedForeground,
                          ),
                        )
                      else if (listing.location?.isNotEmpty ?? false)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.mapPin500,
                              size: 10,
                              color: UmColors.mutedForeground,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              listing.location!,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                fontSize: 10.5,
                                color: UmColors.mutedForeground,
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
      ),
    );
  }
}
