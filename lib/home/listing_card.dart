import 'package:flutter/material.dart';

import '../data/listing_store.dart';
import '../theme/app_theme.dart';
import '../widgets/photo_placeholder.dart';
import 'money_format.dart';

/// The product card (DESIGN.md §5): white fill, 2 dp ink border, 8 dp
/// radius, 4 dp hard shadow; photo top (4:3), price in green weight 800,
/// category chip in `goldSoft`, condition/location captions.
///
/// With an [onTap] the card becomes interactive and gains the mechanical
/// press (DESIGN.md §1/§7): it translates onto its shadow on tap-down and
/// snaps back on release, so every tap has visible press feedback.
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
    final captionStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: UmColors.mutedForeground,
          fontSize: 11.5,
        );

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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: listing.photos.isEmpty
                ? const PhotoPlaceholder()
                : Image.memory(
                    listing.photos.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const PhotoPlaceholder(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatPesos(listing.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: UmColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: UmColors.goldSoft,
                        border: Border.all(color: UmColors.ink, width: 1.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        listing.category,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: UmColors.ink,
                                ),
                      ),
                    ),
                    Text(
                      [
                        if (listing.condition.isNotEmpty) listing.condition,
                        if (listing.location?.isNotEmpty ?? false)
                          listing.location!,
                      ].join(' · '),
                      style: captionStyle,
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
          // Hard offset shadow behind the face, uncovered while the card
          // sits translated at rest (disabled cards have no shadow).
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