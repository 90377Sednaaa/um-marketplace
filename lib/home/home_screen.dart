import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../data/report_store.dart';
import '../theme/app_theme.dart';
import 'browse_screen.dart';
import 'listing_card.dart';
import 'listing_detail_screen.dart';

/// Home (DESIGN.md screen 1): hero search + popular searches + category
/// tiles + recent listings feed. Lean — no member card, no Sell/SignOut
/// (those live on Profile + BottomNav only, per brutal declutter).
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.member,
    required this.memberStore,
    required this.listingsStore,
    required this.chatStore,
    required this.ratingStore,
    required this.reportStore,
    this.onSellRequested,
  });

  final Member member;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final RatingStore ratingStore;
  final ReportStore reportStore;
  final VoidCallback? onSellRequested;

  void _openBrowse(BuildContext context, {String query = '', String? category}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrowseScreen(
          viewerUid: member.uid,
          memberStore: memberStore,
          listingsStore: listingsStore,
          chatStore: chatStore,
          ratingStore: ratingStore,
          reportStore: reportStore,
          initialQuery: query,
          initialCategory: category,
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, Listing listing) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListingDetailScreen(
          listing: listing,
          memberStore: memberStore,
          listingsStore: listingsStore,
          chatStore: chatStore,
          ratingStore: ratingStore,
          reportStore: reportStore,
          viewerId: member.uid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Listing>>(
          stream: listingsStore.activeListingsStream(),
          builder: (context, snapshot) {
            final listings = snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeroSearchBar(onTap: () => _openBrowse(context)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final term in kPopularSearches)
                      _PopularSearchChip(
                        label: term,
                        onTap: () => _openBrowse(context, query: term),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    for (final category in kListingCategories)
                      Expanded(
                        child: _CategoryTile(
                          icon: _categoryIcons[category] ??
                              Icons.sell_outlined,
                          label: category,
                          onTap: () =>
                              _openBrowse(context, category: category),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Recent listings',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                if (listings == null)
                  const _FeedSkeleton()
                else if (listings.isEmpty)
                  _EmptyFeed(onSellRequested: onSellRequested)
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: listings.length,
                    itemBuilder: (context, index) {
                      final listing = listings[index];
                      return ListingCard(
                        listing: listing,
                        onTap: () => _openDetail(context, listing),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  /// Static `muted` blocks (DESIGN.md §5 skeletons) — deliberately
  /// non-animated so the tree settles while the feed streams in.
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: UmColors.muted,
          border: Border.all(color: UmColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({this.onSellRequested});

  final VoidCallback? onSellRequested;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: UmColors.surface,
              border: Border.all(color: UmColors.ink, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: UmColors.ink,
                  offset: UmShadows.small,
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 28,
              color: UmColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'NO LISTINGS YET',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.8,
              color: UmColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Be the first to post one!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: UmColors.mutedForeground,
                ),
          ),
          if (onSellRequested != null) ...[
            const SizedBox(height: 16),
            // CTA is intentionally brutal gold; icon uses Phosphor bold.
            // Keep label Space Grotesk via NbrButton internally.
            GestureDetector(
              onTap: onSellRequested,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: UmColors.gold,
                  border: Border.all(color: UmColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add,
                        size: 16, color: UmColors.ink),
                    const SizedBox(width: 8),
                    Text(
                      'Sell something',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: UmColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Static v1 popular searches (DESIGN.md screen 1 — "static chips in v1").
const List<String> kPopularSearches = [
  'Statistics notes',
  'Electric fan',
  'Airpods',
  'Extension cord',
];

/// Brutal icons for the fixed category tiles — Phosphor bold inside
/// goldSoft circle, ink-bordered square tile.
const Map<String, IconData> _categoryIcons = {
  'textbooks': Icons.menu_book_outlined,
  'gadgets': Icons.devices_outlined,
  'org merch': Icons.emoji_events_outlined,
  'dorm essentials': Icons.bed_outlined,
  'review materials': Icons.edit_note_outlined,
};

/// The hero search bar (DESIGN.md §5): pill, white fill, 3 dp ink border,
/// 4 dp hard shadow, leading search icon. Tappable entry — typing happens
/// on Browse so results update live.
class _HeroSearchBar extends StatelessWidget {
  const _HeroSearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: UmColors.surface,
          border: Border.all(color: UmColors.ink, width: 3),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: UmColors.ink,
              offset: UmShadows.card,
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search,
                size: 20, color: UmColors.ink),
            const SizedBox(width: 10),
            Text(
              'Search textbooks, gadgets…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: UmColors.mutedForeground,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularSearchChip extends StatelessWidget {
  const _PopularSearchChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: UmColors.surface,
          border: Border.all(color: UmColors.ink, width: 1.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: UmColors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// A category tile (DESIGN.md §5): ink-bordered square with a goldSoft
/// circle carrying a bold Phosphor icon; tap opens Browse pre-filtered.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: UmColors.surface,
                border: Border.all(color: UmColors.ink, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: UmColors.ink,
                    offset: UmShadows.small,
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: UmColors.goldSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 19, color: UmColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                height: 1.15,
                color: UmColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
