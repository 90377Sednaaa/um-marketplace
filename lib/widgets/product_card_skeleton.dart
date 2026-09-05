import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'brutal_shimmer.dart';

/// High-fidelity skeleton placeholder matching [ListingCard] layout,
/// borders, and shadows with an animated [BrutalShimmer] wave.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: UmColors.ink, offset: UmShadows.card, blurRadius: 0),
        ],
      ),
      child: BrutalShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: UmColors.muted,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                  border: Border(
                    bottom: BorderSide(color: UmColors.ink, width: 2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrutalSkeletonBox(
                    height: 14,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      BrutalSkeletonBox(
                        height: 14,
                        width: 52,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      const SizedBox(width: 6),
                      BrutalSkeletonBox(
                        height: 14,
                        width: 44,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BrutalSkeletonBox(
                    height: 18,
                    width: 68,
                    borderRadius: BorderRadius.circular(4),
                    color: UmColors.success.withValues(alpha: 0.25),
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
