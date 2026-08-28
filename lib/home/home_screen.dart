import 'package:flutter/material.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../theme/app_theme.dart';
import '../widgets/nbr_button.dart';
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
    required this.onSignOut,
    required this.onSellRequested,
  });

  final Member member;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
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

  void _openDetail(Listing listing) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListingDetailScreen(
          listing: listing,
          memberStore: widget.memberStore,
          listingsStore: widget.listingsStore,
          chatStore: widget.chatStore,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: UmColors.goldSoft,
                  border: Border.all(color: UmColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user, size: 16, color: UmColors.ink),
                    SizedBox(width: 6),
                    Text(
                      'Verified UM student',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: UmColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (member.isAdmin)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: UmColors.gold,
                    border: Border.all(color: UmColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: UmColors.ink,
                    ),
                  ),
                ),
            ],
          ),
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