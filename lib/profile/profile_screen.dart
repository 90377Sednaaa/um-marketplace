import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../data/report_store.dart';
import '../home/listing_detail_screen.dart';
import '../home/money_format.dart';
import '../moderation/moderation_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal_confirm_dialog.dart';
import '../widgets/brutal_dialog.dart';
import '../widgets/brutal_shimmer.dart';
import '../widgets/member_badges.dart';
import '../widgets/nbr_button.dart';
import '../widgets/photo_placeholder.dart';

/// Profile (DESIGN.md screen 7): member identity with the trust badges,
/// the live rating summary (average + trade count, ADR 0004), my listings
/// with the terminal mark-Sold, and — for the Admin only — the gate to
/// Moderation (ADR 0003). Sign out lives here only (brutal declutter).
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

  void _openDetail(BuildContext context, Listing listing) {
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

  Future<void> _confirmMarkSold(BuildContext context, Listing listing) async {
    final confirmed = await showBrutalConfirmDialog(
      context,
      title: 'Mark as sold?',
      body:
          '"${listing.title}" leaves the marketplace, stops appearing in '
          'search, and its chats close to new messages — the '
          'deal already happened in person. This cannot be undone.',
      confirmLabel: 'Mark as sold',
      cancelLabel: 'Cancel',
      isDestructive: false,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await widget.listingsStore.markSold(listing.id);
    } catch (_) {
      if (context.mounted) {
        await showBrutalErrorDialog(
          context,
          title: 'Update failed',
          message: 'Couldn\'t update the listing — try again.',
        );
      }
    }
  }

  /// Seller-initiated retract: the listing leaves every feed and its
  /// chats close to new messages. Terminal — no undo (mirrors mark-Sold).
  Future<void> _confirmCancelListing(
    BuildContext context,
    Listing listing,
  ) async {
    final confirmed = await showBrutalConfirmDialog(
      context,
      title: 'Cancel this listing?',
      body:
          '"${listing.title}" leaves the marketplace right away, its chats '
          'close to new messages, and this cannot be undone.',
      confirmLabel: 'Cancel listing',
      cancelLabel: 'Keep it',
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await widget.listingsStore.cancelListing(listing.id);
    } catch (_) {
      if (context.mounted) {
        await showBrutalErrorDialog(
          context,
          title: 'Update failed',
          message: 'Couldn\'t update the listing — try again.',
        );
      }
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
            const SizedBox(height: 24),
            Text(
              'My listings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Listing>>(
              stream: widget.listingsStore.myListingsStream(widget.member.uid),
              builder: (context, snapshot) {
                final listings = snapshot.data;
                if (listings == null) return const _MyListingsSkeleton();
                if (listings.isEmpty) {
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
                            LucideIcons.tag500,
                            size: 28,
                            color: UmColors.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'NO LISTINGS',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.8,
                            color: UmColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You haven\'t listed anything yet.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: UmColors.mutedForeground),
                        ),
                        const SizedBox(height: 16),
                        NbrButton(
                          label: 'Sell something',
                          icon: const Icon(
                            LucideIcons.plus500,
                            size: 18,
                            color: UmColors.ink,
                          ),
                          fill: UmColors.gold,
                          labelColor: UmColors.ink,
                          onPressed: widget.onSellRequested,
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final listing in listings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MyListingRow(
                          listing: listing,
                          onTap: () => _openDetail(context, listing),
                          onMarkSold: listing.status == 'active'
                              ? () => _confirmMarkSold(context, listing)
                              : null,
                          onCancel: listing.status == 'active'
                              ? () => _confirmCancelListing(context, listing)
                              : null,
                        ),
                      ),
                  ],
                );
              },
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

/// The rating summary card: average + trade count from the public
/// ratings stream (ADR 0004), with the placeholder until the first
/// completed-deal rating arrives.
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

/// The Admin-only gate to screen 9 (ADR 0003) — every user is an ordinary
/// member first; the row appears only on the Admin's own profile.
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

class _MyListingRow extends StatelessWidget {
  const _MyListingRow({
    required this.listing,
    required this.onTap,
    required this.onMarkSold,
    required this.onCancel,
  });

  final Listing listing;
  final VoidCallback onTap;
  final VoidCallback? onMarkSold;

  /// Active-only cancel affordance; null hides the destructive pill.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final sold = listing.status == 'sold';
    final cancelled = listing.status == 'cancelled';
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: listing.photos.isEmpty
                    ? const PhotoPlaceholder()
                    : Image.memory(
                        listing.photos.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const PhotoPlaceholder(),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    listing.condition,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: 11.5,
                      color: UmColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatPesos(listing.price),
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: UmColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (sold)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: UmColors.gold,
                  border: Border.all(color: UmColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'SOLD',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1,
                    color: UmColors.ink,
                  ),
                ),
              )
            else if (cancelled)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: UmColors.muted,
                  border: Border.all(color: UmColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'CANCELLED',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1,
                    color: UmColors.mutedForeground,
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MarkSoldButton(onPressed: onMarkSold),
                  const SizedBox(height: 6),
                  _CancelListingButton(onPressed: onCancel),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MarkSoldButton extends StatefulWidget {
  const _MarkSoldButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_MarkSoldButton> createState() => _MarkSoldButtonState();
}

class _MarkSoldButtonState extends State<_MarkSoldButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: Stack(
        children: [
          if (enabled)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: UmColors.ink,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            curve: Curves.linear,
            transform: Matrix4.translationValues(
              _pressed ? 0 : UmShadows.card.dx,
              _pressed ? 0 : UmShadows.card.dy,
              0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: UmColors.surface,
              border: Border.all(color: UmColors.ink, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Mark as sold',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: enabled ? UmColors.ink : UmColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelListingButton extends StatefulWidget {
  const _CancelListingButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_CancelListingButton> createState() => _CancelListingButtonState();
}

class _CancelListingButtonState extends State<_CancelListingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: Stack(
        children: [
          if (enabled)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: UmColors.ink,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            curve: Curves.linear,
            transform: Matrix4.translationValues(
              _pressed ? 0 : UmShadows.card.dx,
              _pressed ? 0 : UmShadows.card.dy,
              0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: UmColors.surface,
              border: Border.all(color: UmColors.ink, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Cancel listing',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: enabled
                    ? UmColors.destructive
                    : UmColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyListingsSkeleton extends StatelessWidget {
  const _MyListingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return BrutalShimmer(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
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
                child: Row(
                  children: [
                    const BrutalSkeletonBox(
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BrutalSkeletonBox(
                            height: 14,
                            width: 130,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                          SizedBox(height: 6),
                          BrutalSkeletonBox(
                            height: 11,
                            width: 64,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                          SizedBox(height: 6),
                          BrutalSkeletonBox(
                            height: 14,
                            width: 80,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                            color: Color(0xFFDCFCE7),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const BrutalSkeletonBox(
                      height: 28,
                      width: 80,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      hasBorder: true,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
