import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../chats/chat_thread_screen.dart';
import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../data/report_store.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal_dialog.dart';
import '../widgets/nbr_button.dart';
import '../widgets/offer_price_dialog.dart';
import '../widgets/photo_placeholder.dart';
import '../widgets/report_dialog.dart';
import 'money_format.dart';

/// Product detail (DESIGN.md screen 3): hero photo with a count chip,
/// price block, description, the seller strip (avatar, name, verified
/// student badge, live rating average), a safety-notes footer and a
/// sticky Chat + Make an offer bar. Chat/offers open the listing's chat
/// (DESIGN.md screen 6). There is no Buy action anywhere: the app never
/// handles money (ADR 0002).
class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen({
    super.key,
    required this.listing,
    required this.memberStore,
    required this.listingsStore,
    required this.chatStore,
    required this.ratingStore,
    required this.reportStore,
    required this.viewerId,
  });

  final Listing listing;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final RatingStore ratingStore;
  final ReportStore reportStore;

  /// The signed-in member's uid — the bar becomes a "this is your
  /// listing" note instead of chat/offer when it equals [Listing.sellerId].
  final String viewerId;

  Future<void> _reportListing(BuildContext context) async {
    final reason = await showReportDialog(
      context,
      title: 'Report listing',
      description:
          'This flags the listing for the Admin. The reporter '
          'is your verified account.',
    );
    if (reason == null || !context.mounted) return;
    try {
      await reportStore.submitReport(
        reporterId: viewerId,
        reason: reason,
        listingId: listing.id,
        reportedUid: listing.sellerId,
      );
      if (!context.mounted) return;
      await showBrutalSuccessDialog(
        context,
        title: 'Report sent',
        message: 'Report submitted — thanks for keeping the marketplace safe.',
      );
    } catch (_) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Report failed',
        message: 'Couldn\'t submit the report — try again.',
      );
    }
  }

  Future<void> _openChat(BuildContext context) async {
    final me = await memberStore.fetchMember(viewerId);
    final Chat chat;
    try {
      chat = await chatStore.openChatWithBuyer(
        listing: listing,
        buyerUid: viewerId,
        buyerDisplayName: me?.displayName ?? '',
      );
    } on ChatOpenException catch (e) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Can\'t start chat',
        message: e.reason == ChatOpenFailure.listingInactive
            ? 'This listing is no longer available'
            : "You can't start a chat with this member right now",
      );
      return;
    } catch (_) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Chat failed',
        message: 'Couldn\'t start the chat — try again.',
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatThreadScreen(
        chat: chat,
        viewerUid: viewerId,
        chatStore: chatStore,
        memberStore: memberStore,
        listingsStore: listingsStore,
        ratingStore: ratingStore,
        reportStore: reportStore,
      ),
    ));
  }

  Future<void> _makeOffer(BuildContext context) async {
    final price = await showOfferPriceDialog(context);
    if (!context.mounted || price == null) return;
    final me = await memberStore.fetchMember(viewerId);
    final Chat chat;
    try {
      chat = await chatStore.openChatWithBuyer(
        listing: listing,
        buyerUid: viewerId,
        buyerDisplayName: me?.displayName ?? '',
      );
    } on ChatOpenException catch (e) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Can\'t start chat',
        message: e.reason == ChatOpenFailure.listingInactive
            ? 'This listing is no longer available'
            : "You can't start a chat with this member right now",
      );
      return;
    } catch (_) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Chat failed',
        message: 'Couldn\'t start the chat — try again.',
      );
      return;
    }
    try {
      await chatStore.sendOffer(chat, senderId: viewerId, price: price);
    } catch (_) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Offer failed',
        message: 'Couldn\'t send the offer — try again.',
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatThreadScreen(
        chat: chat,
        viewerUid: viewerId,
        chatStore: chatStore,
        memberStore: memberStore,
        listingsStore: listingsStore,
        ratingStore: ratingStore,
        reportStore: reportStore,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isOwn = listing.sellerId == viewerId;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _DetailHeader(onReport: () => _reportListing(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PhotoHero(listing: listing),
                  const SizedBox(height: 16),
                  _ListingBody(listing: listing),
                  const SizedBox(height: 16),
                  _SellerStrip(
                    listing: listing,
                    ratingStore: ratingStore,
                  ),
                  const SizedBox(height: 16),
                  const _SafetyTips(),
                ],
              ),
            ),
            if (isOwn)
              const _OwnListingBar()
            else
              _ActionBar(
                onChat: () => _openChat(context),
                onOffer: () => _makeOffer(context),
              ),
          ],
        ),
      ),
    );
  }
}

/// The shared neubrutalist header band for pushed screens: back arrow and
/// an optional trailing action (the listing report flag).
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.onReport});

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: UmColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
            icon: const Icon(
              Icons.arrow_back,
              size: 24,
              color: UmColors.onPrimary,
            ),
          ),
          const Text(
            'LISTING',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 1.2,
              color: UmColors.onPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onReport,
            tooltip: 'Report listing',
            icon: const Icon(
              Icons.flag_outlined,
              size: 22,
              color: UmColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoHero extends StatefulWidget {
  const _PhotoHero({required this.listing});

  final Listing listing;

  @override
  State<_PhotoHero> createState() => _PhotoHeroState();
}

class _PhotoHeroState extends State<_PhotoHero> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullscreen(int initial) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _FullscreenGallery(
        photos: widget.listing.photos,
        initialIndex: initial,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.listing.photos;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: UmColors.muted,
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photos.isEmpty)
              const PhotoPlaceholder()
            else ...[
              // Stacked peek for 2 photos — behind card offset so the
              // stack reads as "cards piled like a dating deck".
              if (photos.length == 2)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, left: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: UmColors.ink, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Opacity(
                        opacity: 0.88,
                        child: Image.memory(
                          photos[1 - _index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const PhotoPlaceholder(),
                        ),
                      ),
                    ),
                  ),
                ),
              PageView.builder(
                controller: _controller,
                itemCount: photos.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  return GestureDetector(
                    onTap: () => _openFullscreen(i),
                    child: Image.memory(
                      photos[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const PhotoPlaceholder(),
                    ),
                  );
                },
              ),
              if (photos.length > 1)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < photos.length; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? UmColors.gold
                                : UmColors.surface,
                            border: Border.all(
                                color: UmColors.ink, width: 1.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: UmColors.surface,
                    border: Border.all(color: UmColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_index + 1}/${photos.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: UmColors.ink,
                    ),
                  ),
                ),
              ),
            ],
            if (widget.listing.status == 'sold')
              Positioned(
                top: 12,
                left: 12,
                child: Transform.rotate(
                  angle: -0.035,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: UmColors.gold,
                      border: Border.all(color: UmColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'SOLD',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1,
                        color: UmColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenGallery extends StatefulWidget {
  const _FullscreenGallery(
      {required this.photos, required this.initialIndex});

  final List<Uint8List> photos;
  final int initialIndex;

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.memory(
                  widget.photos[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const PhotoPlaceholder(),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: UmColors.surface,
                  border: Border.all(color: UmColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.close, color: UmColors.ink),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: UmColors.ink,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_index + 1}/${widget.photos.length}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < widget.photos.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? UmColors.gold : Colors.white70,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingBody extends StatelessWidget {
  const _ListingBody({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Price + title + meta as a brutal card.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: UmColors.surface,
            border: Border.all(color: UmColors.ink, width: 2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                  color: UmColors.ink, offset: Offset(4, 4), blurRadius: 0),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      formatPesos(listing.price),
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w800,
                        fontSize: 32,
                        height: 1,
                        letterSpacing: -0.5,
                        color: UmColors.success,
                      ),
                    ),
                  ),
                  if (listing.condition.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 8, bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: UmColors.goldSoft,
                        border: Border.all(color: UmColors.ink, width: 1.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        listing.condition.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.8,
                          color: UmColors.ink,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                listing.title,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  height: 1.25,
                  color: UmColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Pill(text: listing.category, fill: UmColors.goldSoft),
                  if (listing.location?.isNotEmpty ?? false)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: UmColors.surface,
                        border: Border.all(
                            color: UmColors.ink.withValues(alpha: 0.6), width: 1.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 12, color: UmColors.mutedForeground),
                          const SizedBox(width: 4),
                          Text(
                            listing.location!,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: UmColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: UmColors.surface,
            border: Border.all(color: UmColors.ink, width: 2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                  color: UmColors.ink, offset: Offset(4, 4), blurRadius: 0),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: UmColors.gold,
                      border: Border.all(color: UmColors.ink, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.notes_outlined,
                        size: 16, color: UmColors.ink),
                  ),
                  const SizedBox(width: 8),
                  Text('Details',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: UmColors.onSurface,
                      )),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                listing.description.isEmpty
                    ? 'No description provided.'
                    : listing.description,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w400,
                  fontSize: 14.5,
                  height: 1.55,
                  color: UmColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.fill});

  final String text;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: UmColors.ink, width: 1.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: UmColors.ink,
        ),
      ),
    );
  }
}

/// The seller strip (DESIGN.md screen 3): avatar, full display name,
/// verified-student badge and live rating line. Shows the denormalized
/// public name (ADR 0007) — no cross-member read.
class _SellerStrip extends StatelessWidget {
  const _SellerStrip({required this.listing, required this.ratingStore});

  final Listing listing;
  final RatingStore ratingStore;

  String _avatarLetters(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = listing.sellerDisplayName;
    final shownName = name.isEmpty ? 'UM student' : name;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(12),
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: name.isEmpty ? UmColors.muted : UmColors.gold,
                  border: Border.all(color: UmColors.ink, width: 2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _avatarLetters(shownName == 'UM student' ? '' : shownName),
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color:
                        name.isEmpty ? UmColors.mutedForeground : UmColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shownName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: UmColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    StreamBuilder<List<Rating>>(
                      stream: ratingStore.ratingsFor(listing.sellerId),
                      builder: (context, snapshot) {
                        final ratings = snapshot.data;
                        final text = ratings == null
                            ? '★ — · no trades yet'
                            : ratingSummaryText(ratings);
                        final hasRatings =
                            ratings != null && ratings.isNotEmpty;
                        return Row(
                          children: [
                            Icon(
                              hasRatings ? Icons.star : Icons.star_outline,
                              size: 13,
                              color: hasRatings
                                  ? UmColors.gold
                                  : UmColors.mutedForeground,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: UmColors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: UmColors.goldSoft,
              border: Border.all(color: UmColors.ink, width: 1.8),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: UmColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user,
                      size: 12, color: UmColors.ink),
                ),
                const SizedBox(width: 6),
                Text(
                  'Verified UM student',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: UmColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyTips extends StatelessWidget {
  const _SafetyTips();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(12),
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
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: UmColors.primary,
                  border: Border.all(color: UmColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.shield_outlined,
                    size: 16, color: UmColors.onPrimary),
              ),
              const SizedBox(width: 8),
              Text(
                'Safety tips',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: UmColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _tip(
            context,
            Icons.location_on_outlined,
            'Meet in public campus spots — library, cafeterias, guarded gates.',
          ),
          const SizedBox(height: 10),
          _tip(
            context,
            Icons.visibility_outlined,
            'Inspect the item before handing anything over.',
          ),
          const SizedBox(height: 10),
          _tip(
            context,
            Icons.payments_outlined,
            'No payments happen inside the app.',
          ),
        ],
      ),
    );
  }

  Widget _tip(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: UmColors.goldSoft,
            border: Border.all(color: UmColors.ink, width: 1.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: UmColors.ink),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
                height: 1.4,
                color: UmColors.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnListingBar extends StatelessWidget {
  const _OwnListingBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: UmColors.surface,
        border: Border(top: BorderSide(color: UmColors.ink, width: 2)),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: UmColors.goldSoft,
            border: Border.all(color: UmColors.ink, width: 2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 18, color: UmColors.ink),
              SizedBox(width: 6),
              Text(
                'This is your listing',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: UmColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sticky bottom bar (DESIGN.md screen 3): Chat + Make an offer. There is
/// no Buy action — the app never handles money (ADR 0002), and offers
/// land as offer-typed chat messages with the Chats screen.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onChat, required this.onOffer});

  final VoidCallback onChat;
  final VoidCallback onOffer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: UmColors.surface,
        border: Border(top: BorderSide(color: UmColors.ink, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: NbrButton(
              label: 'Chat',
              icon: const Icon(
                Icons.chat_bubble_outline,
                size: 20,
                color: UmColors.ink,
              ),
              fill: UmColors.surface,
              labelColor: UmColors.ink,
              stretch: true,
              onPressed: onChat,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: NbrButton(
              label: 'Make an offer',
              icon: const Icon(
                Icons.request_quote_outlined,
                size: 20,
                color: UmColors.ink,
              ),
              fill: UmColors.gold,
              labelColor: UmColors.ink,
              stretch: true,
              onPressed: onOffer,
            ),
          ),
        ],
      ),
    );
  }
}