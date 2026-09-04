import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'brutal_app_bar.dart';
import 'brutal_shimmer.dart';

/// Full-page skeleton placeholder for the product detail view.
///
/// Matches [ListingDetailScreen] visual hierarchy: a maroon [BrutalAppBar],
/// a 4:3 hero frame with hard card shadow, price and condition chips,
/// multi-line title, category/location pill placeholders, a neo-brutalist
/// seller strip card, and description lines.
class ListingDetailSkeleton extends StatelessWidget {
  const ListingDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BrutalAppBar(title: 'LISTING'),
            Expanded(
              child: BrutalShimmer(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 4:3 Hero photo frame
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: UmColors.muted,
                          border: Border.all(color: UmColors.ink, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: UmColors.ink,
                              offset: UmShadows.card,
                              blurRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Price & condition block
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BrutalSkeletonBox(
                          height: 32,
                          width: 140,
                          color: Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        BrutalSkeletonBox(
                          height: 20,
                          width: 64,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Title placeholder (2 lines)
                    const BrutalSkeletonBox(
                      height: 20,
                      width: double.infinity,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    const SizedBox(height: 6),
                    const BrutalSkeletonBox(
                      height: 16,
                      width: 200,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    const SizedBox(height: 16),
                    // Category & location chips
                    const Row(
                      children: [
                        BrutalSkeletonBox(
                          height: 24,
                          width: 80,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        SizedBox(width: 8),
                        BrutalSkeletonBox(
                          height: 24,
                          width: 100,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Seller strip placeholder card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: UmColors.surface,
                        border: Border.all(color: UmColors.ink, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: UmColors.ink,
                            offset: UmShadows.card,
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          BrutalSkeletonBox(
                            width: 44,
                            height: 44,
                            borderRadius:
                                BorderRadius.all(Radius.circular(999)),
                            hasBorder: true,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BrutalSkeletonBox(
                                  height: 14,
                                  width: 120,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(4)),
                                ),
                                SizedBox(height: 6),
                                BrutalSkeletonBox(
                                  height: 12,
                                  width: 80,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(999)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description paragraph placeholders
                    const BrutalSkeletonBox(
                      height: 14,
                      width: double.infinity,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    const SizedBox(height: 6),
                    const BrutalSkeletonBox(
                      height: 14,
                      width: 240,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
