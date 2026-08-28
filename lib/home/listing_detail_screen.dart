import 'package:flutter/material.dart';

import '../chats/chat_thread_screen.dart';
import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../theme/app_theme.dart';
import '../widgets/nbr_button.dart';
import '../widgets/offer_price_dialog.dart';
import '../widgets/photo_placeholder.dart';
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
    required this.viewerId,
  });

  final Listing listing;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final RatingStore ratingStore;

  /// The signed-in member's uid — the bar becomes a "this is your
  /// listing" note instead of chat/offer when it equals [Listing.sellerId].
  final String viewerId;

  Future<void> _openChat(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final me = await memberStore.fetchMember(viewerId);
    final Chat chat;
    try {
      chat = await chatStore.openChatWithBuyer(
        listing: listing,
        buyerUid: viewerId,
        buyerDisplayName: me?.displayName ?? '',
      );
    } on ChatOpenException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(e.reason == ChatOpenFailure.listingInactive
                ? 'This listing is no longer available'
                : "You can't start a chat with this member right now")));
      return;
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Couldn\'t start the chat — try again.')));
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
      ),
    ));
  }

  Future<void> _makeOffer(BuildContext context) async {
    final price = await showOfferPriceDialog(context);
    if (!context.mounted || price == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final me = await memberStore.fetchMember(viewerId);
    final Chat chat;
    try {
      chat = await chatStore.openChatWithBuyer(
        listing: listing,
        buyerUid: viewerId,
        buyerDisplayName: me?.displayName ?? '',
      );
    } on ChatOpenException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(e.reason == ChatOpenFailure.listingInactive
                ? 'This listing is no longer available'
                : "You can't start a chat with this member right now")));
      return;
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Couldn\'t start the chat — try again.')));
      return;
    }
    try {
      await chatStore.sendOffer(chat, senderId: viewerId, price: price);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Couldn\'t send the offer — try again.')));
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
            const _DetailHeader(),
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

class _DetailHeader extends StatelessWidget {
  const _DetailHeader();

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
        ],
      ),
    );
  }
}

class _PhotoHero extends StatelessWidget {
  const _PhotoHero({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
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
            if (listing.photos.isEmpty)
              const PhotoPlaceholder()
            else
              Image.memory(
                listing.photos.first,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const PhotoPlaceholder(),
              ),
            // Single hero photo with a count chip in v1 (DESIGN.md
            // screen 3); the carousel is deferred. ADR 0006 caps listings
            // at 2 photos, so the chip shows the real count.
            if (listing.photos.length > 1)
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
                    '1/${listing.photos.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: UmColors.ink,
                    ),
                  ),
                ),
              ),
            // Sold is a terminal seller state (ADR 0007) — the feed only
            // streams active listings, but a stale open detail still
            // announces it with a slapped-on sticker (DESIGN.md §4).
            if (listing.status == 'sold')
              Positioned(
                top: 12,
                left: 12,
                child: Transform.rotate(
                  angle: -0.035, // ≈ −2° sticker energy
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

class _ListingBody extends StatelessWidget {
  const _ListingBody({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatPesos(listing.price),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 30,
            color: UmColors.success,
          ),
        ),
        const SizedBox(height: 4),
        Text(listing.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Pill(text: listing.category, fill: UmColors.goldSoft),
            if (listing.condition.isNotEmpty)
              _Pill(text: listing.condition, fill: UmColors.surface),
            if (listing.location?.isNotEmpty ?? false)
              Text(
                listing.location!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: UmColors.mutedForeground,
                    ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          listing.description.isEmpty
              ? 'No description provided.'
              : listing.description,
          style: Theme.of(context).textTheme.bodyMedium,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: UmColors.ink,
            ),
      ),
    );
  }
}

/// The seller strip (DESIGN.md screen 3): avatar, display name, the
/// verified-student badge (a platform marker — every member passed the UM
/// email gate, ADR 0001) and the live rating line (average + trade count,
/// ADR 0004). The name is the listing's denormalized public name (ADR
/// 0007) — no cross-member read, which the rules deny by design.
class _SellerStrip extends StatelessWidget {
  const _SellerStrip({required this.listing, required this.ratingStore});

  final Listing listing;
  final RatingStore ratingStore;

  @override
  Widget build(BuildContext context) {
    final name = listing.sellerDisplayName;
    final shownName = name.isEmpty ? 'UM student' : name;
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: name.isEmpty ? UmColors.muted : UmColors.gold,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: name.isEmpty ? UmColors.mutedForeground : UmColors.ink,
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
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                StreamBuilder<List<Rating>>(
                  stream: ratingStore.ratingsFor(listing.sellerId),
                  builder: (context, snapshot) {
                    final ratings = snapshot.data;
                    return Text(
                      ratings == null
                          ? '★ — · no trades yet'
                          : ratingSummaryText(ratings),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: UmColors.mutedForeground,
                          ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: UmColors.goldSoft,
              border: Border.all(color: UmColors.ink, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, size: 14, color: UmColors.ink),
                SizedBox(width: 5),
                Text(
                  'Verified UM student',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
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
              const Icon(Icons.shield_outlined, size: 20, color: UmColors.ink),
              const SizedBox(width: 8),
              Text('Safety tips', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          _tip(
            context,
            Icons.location_on_outlined,
            'Meet in public campus spots — library, cafeterias, guarded gates.',
          ),
          const SizedBox(height: 8),
          _tip(
            context,
            Icons.visibility_outlined,
            'Inspect the item before handing anything over.',
          ),
          const SizedBox(height: 8),
          _tip(
            context,
            Icons.payments_outlined,
            'No payments happen inside the app (ADR 0002).',
          ),
        ],
      ),
    );
  }

  Widget _tip(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: UmColors.mutedForeground),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
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