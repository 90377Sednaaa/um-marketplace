import 'package:flutter/material.dart';

import '../data/listing_store.dart';
import '../theme/app_theme.dart';
import 'money_format.dart';

/// The product card (DESIGN.md §5): white fill, 2 dp ink border, 8 dp
/// radius, 4 dp hard shadow; photo top (4:3), price in green weight 800,
/// category chip in `goldSoft`, condition/location captions.
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final captionStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: UmColors.mutedForeground,
          fontSize: 11.5,
        );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: UmColors.ink,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: listing.photos.isEmpty
                ? _PhotoPlaceholder()
                : Image.memory(
                    listing.photos.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _PhotoPlaceholder(),
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
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
  }
}

class _PhotoPlaceholder extends StatelessWidget {
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