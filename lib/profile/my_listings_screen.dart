import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../data/report_store.dart';
import '../home/listing_detail_screen.dart';
import '../home/money_format.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal_app_bar.dart';
import '../widgets/brutal_confirm_dialog.dart';
import '../widgets/brutal_dialog.dart';
import '../widgets/brutal_shimmer.dart';
import '../widgets/nbr_button.dart';
import '../widgets/photo_placeholder.dart';

enum MyListingFilter { all, active, sold, cancelled }

/// Dedicated My Listings screen for managing items on sale, sold, or cancelled.
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({
    super.key,
    required this.member,
    required this.listingsStore,
    required this.chatStore,
    required this.ratingStore,
    required this.reportStore,
    required this.memberStore,
    this.onSellRequested,
  });

  final Member member;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final RatingStore ratingStore;
  final ReportStore reportStore;
  final MemberStore memberStore;
  final VoidCallback? onSellRequested;

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  MyListingFilter _filter = MyListingFilter.all;

  Future<void> _openListing(Listing listing) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListingDetailScreen(
          listing: listing,
          listingsStore: widget.listingsStore,
          chatStore: widget.chatStore,
          ratingStore: widget.ratingStore,
          reportStore: widget.reportStore,
          memberStore: widget.memberStore,
          viewerId: widget.member.uid,
        ),
      ),
    );
  }

  Future<void> _confirmMarkSold(Listing listing) async {
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
    if (confirmed != true || !mounted) return;
    try {
      await widget.listingsStore.markSold(listing.id);
    } catch (_) {
      if (mounted) {
        await showBrutalErrorDialog(
          context,
          title: 'Update failed',
          message: 'Couldn\'t update the listing — try again.',
        );
      }
    }
  }

  Future<void> _confirmCancelListing(Listing listing) async {
    final confirmed = await showBrutalConfirmDialog(
      context,
      title: 'Cancel this listing?',
      body:
          '"${listing.title}" leaves the marketplace right away, its chats '
          'close to new messages, and this cannot be undone.',
      confirmLabel: 'Cancel listing',
      cancelLabel: 'Keep it',
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.listingsStore.cancelListing(listing.id);
    } catch (_) {
      if (mounted) {
        await showBrutalErrorDialog(
          context,
          title: 'Update failed',
          message: 'Couldn\'t update the listing — try again.',
        );
      }
    }
  }

  List<Listing> _filterListings(List<Listing> listings) {
    switch (_filter) {
      case MyListingFilter.all:
        return listings;
      case MyListingFilter.active:
        return listings
            .where((l) => l.status != 'sold' && l.status != 'cancelled')
            .toList();
      case MyListingFilter.sold:
        return listings.where((l) => l.status == 'sold').toList();
      case MyListingFilter.cancelled:
        return listings.where((l) => l.status == 'cancelled').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UmColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const BrutalAppBar(
              title: 'MY LISTINGS',
              leadingIcon: LucideIcons.package500,
            ),
            _FilterBar(
              selected: _filter,
              onSelect: (filter) => setState(() => _filter = filter),
            ),
            Expanded(
              child: StreamBuilder<List<Listing>>(
                stream: widget.listingsStore.myListingsStream(
                  widget.member.uid,
                ),
                builder: (context, snapshot) {
                  final listings = snapshot.data;
                  if (listings == null) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: _MyListingsSkeleton(),
                    );
                  }
                  if (listings.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _EmptyListingsBox(
                          onSellRequested: widget.onSellRequested == null
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  widget.onSellRequested!();
                                },
                        ),
                      ],
                    );
                  }

                  final filtered = _filterListings(listings);
                  if (filtered.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 24),
                        Container(
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
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: UmColors.goldSoft,
                                  border: Border.all(
                                    color: UmColors.ink,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  LucideIcons.filter500,
                                  size: 26,
                                  color: UmColors.ink,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No ${_filter.name} listings.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: UmColors.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try selecting another tab above.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: UmColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isActive =
                          item.status != 'sold' && item.status != 'cancelled';
                      return _MyListingRow(
                        listing: item,
                        onTap: () => _openListing(item),
                        onMarkSold: isActive
                            ? () => _confirmMarkSold(item)
                            : null,
                        onCancel: isActive
                            ? () => _confirmCancelListing(item)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelect});

  final MyListingFilter selected;
  final ValueChanged<MyListingFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          for (final filter in MyListingFilter.values)
            Expanded(
              child: _FilterSegment(
                label: filter.name.toUpperCase(),
                selected: filter == selected,
                onTap: () => onSelect(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterSegment extends StatefulWidget {
  const _FilterSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FilterSegment> createState() => _FilterSegmentState();
}

class _FilterSegmentState extends State<_FilterSegment> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          _pressed && widget.selected ? 1 : 0,
          _pressed && widget.selected ? 1 : 0,
          0,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.selected ? UmColors.gold : Colors.transparent,
          border: Border.all(
            color: widget.selected ? UmColors.ink : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(7),
          boxShadow: [
            if (widget.selected)
              BoxShadow(
                color: UmColors.ink,
                offset: _pressed
                    ? const Offset(0.5, 0.5)
                    : const Offset(1.5, 1.5),
                blurRadius: 0,
              ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              widget.label,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: widget.selected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 0.5,
                color: widget.selected
                    ? UmColors.ink
                    : UmColors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyListingsBox extends StatelessWidget {
  const _EmptyListingsBox({this.onSellRequested});

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
          if (onSellRequested != null) ...[
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
              onPressed: onSellRequested,
            ),
          ],
        ],
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
                child: const Row(
                  children: [
                    BrutalSkeletonBox(
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
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
                            width: 70,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                          SizedBox(height: 6),
                          BrutalSkeletonBox(
                            height: 14,
                            width: 60,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                        ],
                      ),
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
