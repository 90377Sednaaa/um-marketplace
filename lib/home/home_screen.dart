import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

/// Home (DESIGN.md screen 1): hero search + category tiles + recent
/// listings feed. Lean — no member card, no Sell/SignOut
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

  void _openBrowse(
    BuildContext context, {
    String query = '',
    String? category,
  }) {
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
      floatingActionButton: onSellRequested == null
          ? null
          : _BrutalFab(onTap: onSellRequested!),
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
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 4,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: kListingCategories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = kListingCategories[index];
                      return _CategoryCapsule(
                        icon: _categoryIcons[category] ?? LucideIcons.tag500,
                        label: category,
                        onTap: () => _openBrowse(context, category: category),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
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
                          childAspectRatio: 0.70,
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
          BoxShadow(color: UmColors.ink, offset: UmShadows.card, blurRadius: 0),
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
              LucideIcons.store500,
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
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: UmColors.mutedForeground),
          ),
          if (onSellRequested != null) ...[
            const SizedBox(height: 16),
            // CTA is intentionally brutal gold; icon uses Phosphor bold.
            // Keep label Space Grotesk via NbrButton internally.
            GestureDetector(
              onTap: onSellRequested,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: UmColors.gold,
                  border: Border.all(color: UmColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.plus500,
                      size: 16,
                      color: UmColors.ink,
                    ),
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

class _BrutalFab extends StatefulWidget {
  const _BrutalFab({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BrutalFab> createState() => _BrutalFabState();
}

class _BrutalFabState extends State<_BrutalFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.linear,
        transform: Matrix4.translationValues(
          _pressed ? 2 : 0,
          _pressed ? 2 : 0,
          0,
        ),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: UmColors.gold,
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
        child: const Icon(LucideIcons.plus500, size: 28, color: UmColors.ink),
      ),
    );
  }
}

/// Brutal icons for the fixed category tiles — Lucide bold inside
/// goldSoft circle, ink-bordered square tile.
const Map<String, IconData> _categoryIcons = {
  'textbooks': LucideIcons.bookOpen500,
  'gadgets': LucideIcons.smartphone500,
  'org merch': LucideIcons.award500,
  'dorm essentials': LucideIcons.bed500,
  'review materials': LucideIcons.notebookPen500,
};

/// The hero search bar (DESIGN.md §5): pill, white fill, 3 dp ink border,
/// 4 dp hard shadow, leading search icon. Tappable entry — typing happens
/// on Browse so results update live. Press translates onto shadow.
class _HeroSearchBar extends StatefulWidget {
  const _HeroSearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_HeroSearchBar> createState() => _HeroSearchBarState();
}

class _HeroSearchBarState extends State<_HeroSearchBar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.linear,
        transform: Matrix4.translationValues(
          _pressed ? 2 : 0,
          _pressed ? 2 : 0,
          0,
        ),
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: UmColors.surface,
          border: Border.all(color: UmColors.ink, width: 3),
          borderRadius: BorderRadius.circular(999),
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
        child: Row(
          children: [
            const Icon(LucideIcons.search500, size: 20, color: UmColors.ink),
            const SizedBox(width: 10),
            Text(
              'Search textbooks, gadgets…',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: UmColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

/// A category action capsule: pill with 2dp ink border, 2dp hard shadow,
/// bold icon + single-line Space Grotesk label. Press translates onto shadow.
class _CategoryCapsule extends StatefulWidget {
  const _CategoryCapsule({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_CategoryCapsule> createState() => _CategoryCapsuleState();
}

class _CategoryCapsuleState extends State<_CategoryCapsule> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.linear,
        transform: Matrix4.translationValues(
          _pressed ? 2 : 0,
          _pressed ? 2 : 0,
          0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: UmColors.surface,
          border: Border.all(color: UmColors.ink, width: 2),
          borderRadius: BorderRadius.circular(999),
          boxShadow: _pressed
              ? null
              : const [
                  BoxShadow(
                    color: UmColors.ink,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 16, color: UmColors.primary),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.2,
                color: UmColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
