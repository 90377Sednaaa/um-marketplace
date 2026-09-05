import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../data/report_store.dart';
import '../moderation/moderation_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/member_badges.dart';
import 'my_listings_screen.dart';

export 'my_listings_screen.dart';

/// Profile (DESIGN.md screen 7): member identity with the trust badges,
/// the live rating summary (average + trade count, ADR 0004), My listings
/// hub navigation, and — for the Admin only — the gate to Moderation (ADR 0003).
/// Sign out lives cleanly at the bottom.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.member,
    required this.memberStore,
    required this.listingsStore,
    required this.chatStore,
    required this.ratingStore,
    required this.reportStore,
    required this.onSignOut,
    this.onSellRequested,
  });

  final Member member;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final RatingStore ratingStore;
  final ReportStore reportStore;
  final Future<void> Function() onSignOut;
  final VoidCallback? onSellRequested;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _IdentityCard(member: widget.member),
            const SizedBox(height: 12),
            StreamBuilder<List<Rating>>(
              stream: widget.ratingStore.ratingsFor(widget.member.uid),
              builder: (context, snapshot) {
                final ratings = snapshot.data;
                return _RatingCard(
                  summary: ratings == null
                      ? '★ — · no trades yet'
                      : ratingSummaryText(ratings),
                );
              },
            ),
            const SizedBox(height: 12),
            _MyListingsRow(
              listingsStream: widget.listingsStore.myListingsStream(
                widget.member.uid,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MyListingsScreen(
                    member: widget.member,
                    listingsStore: widget.listingsStore,
                    chatStore: widget.chatStore,
                    ratingStore: widget.ratingStore,
                    reportStore: widget.reportStore,
                    memberStore: widget.memberStore,
                    onSellRequested: widget.onSellRequested,
                  ),
                ),
              ),
            ),
            if (widget.member.isAdmin) ...[
              const SizedBox(height: 12),
              _AdminRow(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ModerationScreen(
                      memberStore: widget.memberStore,
                      listingsStore: widget.listingsStore,
                      reportStore: widget.reportStore,
                      chatStore: widget.chatStore,
                      ratingStore: widget.ratingStore,
                      viewerId: widget.member.uid,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _signingOut ? null : _signOut,
              child: Container(
                padding: const EdgeInsets.all(14),
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
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.logOut500,
                      size: 22,
                      color: UmColors.ink,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _signingOut ? 'Signing out…' : 'Sign out',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: UmColors.ink,
                        ),
                      ),
                    ),
                    if (_signingOut)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: UmColors.ink,
                        ),
                      )
                    else
                      const Icon(
                        LucideIcons.chevronRight500,
                        size: 18,
                        color: UmColors.ink,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.member});

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
          BoxShadow(color: UmColors.ink, offset: UmShadows.card, blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: UmColors.gold,
                child: Text(
                  member.displayName.isEmpty
                      ? '?'
                      : member.displayName[0].toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                    color: UmColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.email,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: UmColors.mutedForeground),
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

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          const Icon(
            LucideIcons.star500,
            size: 22,
            color: UmColors.mutedForeground,
          ),
          const SizedBox(width: 10),
          Text(
            summary,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _MyListingsRow extends StatelessWidget {
  const _MyListingsRow({required this.onTap, required this.listingsStream});

  final VoidCallback onTap;
  final Stream<List<Listing>> listingsStream;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
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
        child: Row(
          children: [
            const Icon(LucideIcons.package500, size: 22, color: UmColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My listings',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: UmColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  StreamBuilder<List<Listing>>(
                    stream: listingsStream,
                    builder: (context, snapshot) {
                      final listings = snapshot.data;
                      if (listings == null || listings.isEmpty) {
                        return Text(
                          'You haven\'t listed anything yet.',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: UmColors.mutedForeground,
                          ),
                        );
                      }
                      final activeCount = listings
                          .where(
                            (l) =>
                                l.status != 'sold' && l.status != 'cancelled',
                          )
                          .length;
                      return Text(
                        '$activeCount active · ${listings.length} total',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: UmColors.mutedForeground,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            StreamBuilder<List<Listing>>(
              stream: listingsStream,
              builder: (context, snapshot) {
                final listings = snapshot.data;
                final activeCount = listings == null
                    ? 0
                    : listings
                          .where(
                            (l) =>
                                l.status != 'sold' && l.status != 'cancelled',
                          )
                          .length;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: activeCount > 0 ? UmColors.gold : UmColors.muted,
                    border: Border.all(color: UmColors.ink, width: 1.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$activeCount active',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.2,
                      color: activeCount > 0
                          ? UmColors.ink
                          : UmColors.mutedForeground,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight500,
              size: 18,
              color: UmColors.ink,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminRow extends StatelessWidget {
  const _AdminRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: UmColors.gold,
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
        child: Row(
          children: [
            const Icon(
              LucideIcons.shieldCheck500,
              size: 22,
              color: UmColors.ink,
            ),
            const SizedBox(width: 10),
            Text(
              'Moderation',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 15),
            ),
            const Spacer(),
            const Icon(
              LucideIcons.chevronRight500,
              size: 22,
              color: UmColors.ink,
            ),
          ],
        ),
      ),
    );
  }
}
