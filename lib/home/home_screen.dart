import 'package:flutter/material.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../data/report_store.dart';
import '../theme/app_theme.dart';
import '../widgets/member_badges.dart';
import '../widgets/nbr_button.dart';
import 'browse_screen.dart';
import 'listing_card.dart';
import 'listing_detail_screen.dart';

/// Home (DESIGN.md screen 1, milestone cut): member header, a Sell CTA and
/// the recent-listings feed straight from Firestore. The hero search,
/// category tiles and notification bell land with the full screen. Hosted
/// as the first tab of the AppShell — the shell owns the brand band and
/// the Sell CTA switches tabs instead of pushing a route.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.member,
    required this.memberStore,
    required this.listingsStore,
    required this.chatStore,
    required this.ratingStore,
    required this.reportStore,
    required this.onSignOut,
    required this.onSellRequested,
  });

  final Member member;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final RatingStore ratingStore;
  final ReportStore reportStore;
  final Future<void> Function() onSignOut;
  final VoidCallback onSellRequested;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _openSell() => widget.onSellRequested();

  void _openBrowse({String query = '', String? category}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrowseScreen(
          viewerUid: widget.member.uid,
          memberStore: widget.memberStore,
          listingsStore: widget.listingsStore,
          chatStore: widget.chatStore,
          ratingStore: widget.ratingStore,
          reportStore: widget.reportStore,
          initialQuery: query,
          initialCategory: category,
        ),
      ),
    );
  }

  void _openDetail(Listing listing) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListingDetailScreen(
          listing: listing,
          memberStore: widget.memberStore,
          listingsStore: widget.listingsStore,
          chatStore: widget.chatStore,
          ratingStore: widget.ratingStore,
          reportStore: widget.reportStore,
          viewerId: widget.member.uid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Listing>>(
          stream: widget.listingsStore.activeListingsStream(),
          builder: (context, snapshot) {
            final listings = snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _MemberCard(member: widget.member),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: NbrButton(
                        label: 'Sell something',
                        icon: const Icon(
                          Icons.add,
                          size: 20,
                          color: UmColors.onPrimary,
                        ),
                        onPressed: _openSell,
                      ),
                    ),
                    const SizedBox(width: 12),
                    NbrButton(
                      label:
                          _signingOut ? 'Signing out…' : 'Sign out',
                      fill: UmColors.surface,
                      labelColor: UmColors.ink,
                      onPressed: _signingOut ? null : _signOut,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _HeroSearchBar(onTap: () => _openBrowse()),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final term in kPopularSearches)
                      _PopularSearchChip(
                        label: term,
                        onTap: () => _openBrowse(query: term),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    for (final category in kListingCategories)
                      Expanded(
                        child: _CategoryTile(
                          icon: _categoryIcons[category] ?? Icons.sell_outlined,
                          label: category,
                          onTap: () => _openBrowse(category: category),
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
                  const _EmptyFeed()
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
                        onTap: () => _openDetail(listing),
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

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: UmColors.gold,
                child: Text(
                  member.displayName.isEmpty
                      ? '?'
                      : member.displayName[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: UmColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.displayName,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      member.email,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: UmColors.mutedForeground,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MemberBadges(member: member),
        ],
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
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 48,
            color: UmColors.mutedForeground,
          ),
          const SizedBox(height: 12),
          Text(
            'No listings yet — be the first to post one!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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

/// Maroon-outline icons for the fixed category tiles (DESIGN.md §5 —
/// category tiles carry a maroon icon inside a goldSoft circle).
const Map<String, IconData> _categoryIcons = {
  'textbooks': Icons.menu_book_outlined,
  'gadgets': Icons.devices_outlined,
  'org merch': Icons.emoji_events_outlined,
  'dorm essentials': Icons.bed_outlined,
  'review materials': Icons.edit_note_outlined,
};

/// The hero search bar (DESIGN.md §5): pill, white fill, 3 dp ink border,
/// 4 dp hard shadow, leading search icon. It is a tappable entry point —
/// typing happens on the Browse screen so results update live.
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
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 24, color: UmColors.ink),
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
          style: const TextStyle(
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
/// circle carrying a maroon icon; tap opens Browse pre-filtered.
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
                    offset: Offset(3, 3),
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
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