import 'package:flutter/material.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../home/listing_detail_screen.dart';
import '../home/money_format.dart';
import '../theme/app_theme.dart';
import '../widgets/member_badges.dart';
import '../widgets/photo_placeholder.dart';

/// Profile (DESIGN.md screen 7): member identity with the trust badges,
/// the rating placeholder (ADR 0004 data arrives with the ratings stage),
/// my listings with the terminal mark-Sold, and — for the Admin only —
/// the gate to Moderation (ADR 0003; the screen itself lands with the
/// Moderation stage). Settings land with the notification stage.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.member,
    required this.memberStore,
    required this.listingsStore,
    required this.chatStore,
  });

  final Member member;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;

  void _openDetail(BuildContext context, Listing listing) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListingDetailScreen(
          listing: listing,
          memberStore: memberStore,
          listingsStore: listingsStore,
          chatStore: chatStore,
          viewerId: member.uid,
        ),
      ),
    );
  }

  Future<void> _confirmMarkSold(BuildContext context, Listing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: UmColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: UmColors.ink, width: 2),
        ),
        title: const Text(
          'Mark as sold?',
          style: TextStyle(fontWeight: FontWeight.w800, color: UmColors.onSurface),
        ),
        content: Text(
          '"${listing.title}" leaves the marketplace, stops appearing in '
          'search, and its chats close to new messages (ADR 0002 — the '
          'deal already happened in person). This cannot be undone.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: UmColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Mark as sold',
              style: TextStyle(
                color: UmColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await listingsStore.markSold(listing.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Couldn\'t update the listing — try again.')));
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
            _IdentityCard(member: member),
            const SizedBox(height: 12),
            const _RatingCard(),
            if (member.isAdmin) ...[
              const SizedBox(height: 12),
              _AdminRow(
                onTap: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                        content: Text('Moderation is coming soon')));
                },
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'My listings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Listing>>(
              stream: listingsStore.myListingsStream(member.uid),
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
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.sell_outlined,
                          size: 48,
                          color: UmColors.mutedForeground,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You haven\'t listed anything yet — tap Sell to '
                          'post your first item!',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
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
                          onMarkSold:
                              listing.status == 'active'
                                  ? () => _confirmMarkSold(context, listing)
                                  : null,
                        ),
                      ),
                  ],
                );
              },
            ),
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
          BoxShadow(color: UmColors.ink, offset: Offset(4, 4), blurRadius: 0),
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
                  style: const TextStyle(
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

/// The rating summary placeholder: ratings are locked to completed deals
/// (ADR 0004) and land with the ratings stage.
class _RatingCard extends StatelessWidget {
  const _RatingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star_outline,
            size: 22,
            color: UmColors.mutedForeground,
          ),
          const SizedBox(width: 10),
          Text(
            '★ — · no trades yet',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontSize: 15),
          ),
          const Spacer(),
          Text(
            'Ratings open once deals complete',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontSize: 11, color: UmColors.mutedForeground),
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
            BoxShadow(color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings_outlined,
                size: 22, color: UmColors.ink),
            const SizedBox(width: 10),
            Text(
              'Moderation',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 15),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 22, color: UmColors.ink),
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
  });

  final Listing listing;
  final VoidCallback onTap;
  final VoidCallback? onMarkSold;

  @override
  Widget build(BuildContext context) {
    final sold = listing.status == 'sold';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: UmColors.surface,
          border: Border.all(color: UmColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
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
                    style:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 15,
                            ),
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
                    style: const TextStyle(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: UmColors.gold,
                  border: Border.all(color: UmColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'SOLD',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1,
                    color: UmColors.ink,
                  ),
                ),
              )
            else
              _MarkSoldButton(onPressed: onMarkSold),
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
              _pressed ? 0 : 3,
              _pressed ? 0 : 3,
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
              style: TextStyle(
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

class _MyListingsSkeleton extends StatelessWidget {
  const _MyListingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 76,
              decoration: BoxDecoration(
                color: UmColors.muted,
                border: Border.all(color: UmColors.ink, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }
}