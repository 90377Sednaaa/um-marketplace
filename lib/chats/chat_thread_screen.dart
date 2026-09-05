import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../data/report_store.dart';
import '../home/listing_detail_screen.dart';
import '../home/money_format.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal_dialog.dart';
import '../widgets/brutal_page_route.dart';
import '../widgets/brutal_shimmer.dart';
import '../widgets/nbr_button.dart';
import '../widgets/offer_price_dialog.dart';
import '../widgets/photo_placeholder.dart';
import '../widgets/report_dialog.dart';

/// Chat thread (DESIGN.md screen 6): pinned product snippet, message
/// list (text + offer blocks), composer, and — once the listing is sold —
/// the rate-the-deal prompt (ADR 0004). No money changes hands anywhere
/// (ADR 0002). Sending is fire-and-forget with a snackbar on refusal.
class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({
    super.key,
    required this.chat,
    required this.viewerUid,
    required this.chatStore,
    required this.memberStore,
    required this.listingsStore,
    required this.ratingStore,
    required this.reportStore,
  });

  final Chat chat;
  final String viewerUid;
  final ChatStore chatStore;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final RatingStore ratingStore;
  final ReportStore reportStore;

  void _send(BuildContext context, String text) async {
    try {
      await chatStore.sendText(chat, senderId: viewerUid, text: text);
    } on ChatSendException {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Can\'t message',
        message: "You can't message this member right now",
      );
    } catch (_) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Send failed',
        message: 'Couldn\'t send — try again.',
      );
    }
  }

  void _sendOffer(BuildContext context, double price) async {
    try {
      await chatStore.sendOffer(chat, senderId: viewerUid, price: price);
    } on ChatSendException {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Can\'t message',
        message: "You can't message this member right now",
      );
    } catch (_) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Send failed',
        message: 'Couldn\'t send — try again.',
      );
    }
  }

  Future<void> _reportChat(BuildContext context) async {
    final otherUid = chat.participants.firstWhere((u) => u != viewerUid);
    final reason = await showReportDialog(
      context,
      title: 'Report this chat',
      description:
          'This flags the conversation for the Admin. The '
          'reporter is your verified account.',
    );
    if (reason == null || !context.mounted) return;
    try {
      await reportStore.submitReport(
        reporterId: viewerUid,
        reason: reason,
        chatId: chat.id,
        reportedUid: otherUid,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ThreadHeader(
              chat: chat,
              viewerUid: viewerUid,
              onReport: () => _reportChat(context),
            ),
            Expanded(
              child: StreamBuilder<Listing?>(
                stream: listingsStore.listingChanges(chat.listingId),
                builder: (context, snapshot) {
                  final listing = snapshot.data;
                  if (listing == null) {
                    return const _ThreadSkeleton();
                  }
                  final active = listing.status == 'active';
                  final isBuyer = viewerUid == chat.buyerId;
                  return Column(
                    children: [
                      _PinnedListing(
                        listing: listing,
                        listingsStore: listingsStore,
                        memberStore: memberStore,
                        chatStore: chatStore,
                        viewerUid: viewerUid,
                        ratingStore: ratingStore,
                        reportStore: reportStore,
                      ),
                      if (!active) ...[
                        const _InactiveBanner(),
                        if (listing.status == 'sold')
                          _RatingPrompt(
                            listing: listing,
                            chat: chat,
                            viewerUid: viewerUid,
                            ratingStore: ratingStore,
                          ),
                      ],
                      Expanded(
                        child: _MessageList(
                          chat: chat,
                          chatStore: chatStore,
                          viewerUid: viewerUid,
                        ),
                      ),
                      _Composer(
                        enabled: active,
                        onSend: (text) {
                          if (text.trim().isNotEmpty) {
                            _send(context, text.trim());
                          }
                        },
                        onOffer: active && isBuyer
                            ? () async {
                                final price = await showOfferPriceDialog(
                                  context,
                                );
                                if (!context.mounted) return;
                                if (price != null) {
                                  _sendOffer(context, price);
                                }
                              }
                            : null,
                      ),
                    ],
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

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.chat,
    required this.viewerUid,
    required this.onReport,
  });

  final Chat chat;
  final String viewerUid;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final otherName = viewerUid == chat.buyerId
        ? chat.sellerName
        : chat.buyerName;
    final shownName = otherName.isEmpty ? 'Chat' : otherName;
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
              LucideIcons.arrowLeft500,
              size: 24,
              color: UmColors.onPrimary,
            ),
          ),
          Expanded(
            child: Text(
              shownName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: UmColors.onPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onReport,
            tooltip: 'Report this chat',
            icon: const Icon(
              LucideIcons.flag500,
              size: 22,
              color: UmColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadSkeleton extends StatelessWidget {
  const _ThreadSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pinned listing placeholder
          BrutalShimmer(
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
                          width: 140,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        SizedBox(height: 6),
                        BrutalSkeletonBox(
                          height: 12,
                          width: 70,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Expanded(child: _MessagesSkeleton()),
        ],
      ),
    );
  }
}

/// Message-bubble placeholders (alternating incoming & outgoing) shown
/// while the pinned listing is resolved and while the message stream is
/// still pending.
class _MessagesSkeleton extends StatelessWidget {
  const _MessagesSkeleton();

  @override
  Widget build(BuildContext context) {
    return BrutalShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _MessageBubbleSkeleton(
            width: 180,
            height: 48,
            color: UmColors.surface,
            mine: false,
          ),
          _MessageBubbleSkeleton(
            width: 150,
            height: 48,
            color: UmColors.primary.withValues(alpha: 0.3),
            mine: true,
          ),
          _MessageBubbleSkeleton(
            width: 220,
            height: 56,
            color: UmColors.gold.withValues(alpha: 0.35),
            mine: false,
          ),
        ],
      ),
    );
  }
}

class _MessageBubbleSkeleton extends StatelessWidget {
  const _MessageBubbleSkeleton({
    required this.width,
    required this.height,
    required this.color,
    required this.mine,
  });

  final double width;
  final double height;
  final Color color;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color,
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
      ),
    );
  }
}

/// The pinned product card (DESIGN.md screen 6) — tappable to the listing
/// detail while the listing is active.
class _PinnedListing extends StatelessWidget {
  const _PinnedListing({
    required this.listing,
    required this.listingsStore,
    required this.memberStore,
    required this.chatStore,
    required this.viewerUid,
    required this.ratingStore,
    required this.reportStore,
  });

  final Listing listing;
  final ListingStore listingsStore;
  final MemberStore memberStore;
  final ChatStore chatStore;
  final String viewerUid;
  final RatingStore ratingStore;
  final ReportStore reportStore;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onTap = listing.status != 'active'
        ? null
        : () => Navigator.of(context).push(
            BrutalPageRoute<void>(
              builder: (_) => ListingDetailScreen(
                listing: listing,
                memberStore: memberStore,
                listingsStore: listingsStore,
                chatStore: chatStore,
                ratingStore: ratingStore,
                reportStore: reportStore,
                viewerId: viewerUid,
              ),
            ),
          );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: UmColors.surface,
          border: Border.all(color: UmColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: UmColors.ink, offset: Offset(4, 4), blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
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
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPesos(listing.price),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: UmColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InactiveBanner extends StatelessWidget {
  const _InactiveBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: UmColors.goldSoft,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.lock500, size: 18, color: UmColors.ink),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This listing is no longer active',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: UmColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.chat,
    required this.chatStore,
    required this.viewerUid,
  });

  final Chat chat;
  final ChatStore chatStore;
  final String viewerUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatMessage>>(
      stream: chatStore.chatMessagesStream(chat.id),
      builder: (context, snapshot) {
        final messages = snapshot.data;
        if (messages == null) {
          return const _MessagesSkeleton();
        }
        if (messages.isEmpty) {
          return Center(
            child: Text(
              'Say hi — or send an offer.',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: UmColors.mutedForeground),
            ),
          );
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            return _MessageBubble(
              message: message,
              isMine: message.senderId == viewerUid,
            );
          },
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final offer = message.type == 'offer';
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: offer
              ? UmColors.gold
              : (isMine ? UmColors.primary : UmColors.surface),
          border: Border.all(color: UmColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child: Column(
          crossAxisAlignment: align,
          children: [
            if (offer) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: UmColors.surface,
                  border: Border.all(color: UmColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'OFFER',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1,
                    color: UmColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (message.price != null)
                Text(
                  formatPesos(message.price!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: UmColors.ink, // gold carries black ink (§2)
                  ),
                ),
            ],
            if (message.text.isNotEmpty) ...[
              if (offer) const SizedBox(height: 4),
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  // Maroon bubbles carry white, white bubbles carry ink
                  // text; gold (offers) carries black ink (§2 contrast).
                  color: offer
                      ? UmColors.ink
                      : (isMine ? UmColors.onPrimary : UmColors.onSurface),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.enabled, required this.onSend, this.onOffer});

  final bool enabled;
  final ValueChanged<String> onSend;

  /// Buyer-only offer affordance; null hides the gold button.
  final VoidCallback? onOffer;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: UmColors.surface,
        border: Border(top: BorderSide(color: UmColors.ink, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.enabled,
              onSubmitted: (text) => _submit(text),
              decoration: InputDecoration(
                hintText: widget.enabled ? 'Message…' : 'Messages are closed',
                hintStyle: TextStyle(
                  color: widget.enabled
                      ? UmColors.mutedForeground
                      : UmColors.muted,
                ),
                filled: true,
                fillColor: UmColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: UmColors.ink, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: UmColors.ink, width: 2),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: UmColors.mutedForeground,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.onOffer != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: widget.enabled ? widget.onOffer : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: UmColors.gold,
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
                  child: const Icon(
                    LucideIcons.handCoins500,
                    size: 24,
                    color: UmColors.ink,
                  ),
                ),
              ),
            ),
          _SendButton(
            enabled: widget.enabled,
            onPressed: () => _submit(_controller.text),
          ),
        ],
      ),
    );
  }

  void _submit(String text) {
    if (!widget.enabled || text.trim().isEmpty) return;
    _controller.clear();
    widget.onSend(text);
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled ? UmColors.primary : UmColors.muted,
          border: Border.all(
            color: enabled ? UmColors.ink : UmColors.mutedForeground,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: UmColors.ink,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Icon(
          LucideIcons.send500,
          size: 22,
          color: enabled ? UmColors.onPrimary : UmColors.mutedForeground,
        ),
      ),
    );
  }
}

/// The rate-the-deal prompt (DESIGN.md screen 6 stretch, unlocked by
/// mark-Sold): when the listing is sold, each party of the chat rates the
/// other exactly once (the deterministic rating doc id enforces it).
class _RatingPrompt extends StatefulWidget {
  const _RatingPrompt({
    required this.listing,
    required this.chat,
    required this.viewerUid,
    required this.ratingStore,
  });

  final Listing listing;
  final Chat chat;
  final String viewerUid;
  final RatingStore ratingStore;

  @override
  State<_RatingPrompt> createState() => _RatingPromptState();
}

class _RatingPromptState extends State<_RatingPrompt> {
  Rating? _myRating;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mine = await widget.ratingStore.myRatingFor(
      widget.listing.id,
      widget.viewerUid,
    );
    if (mounted) {
      setState(() {
        _myRating = mine;
        _loaded = true;
      });
    }
  }

  Future<void> _openDialog() async {
    final stars = await showDialog<int>(
      context: context,
      builder: (_) => const _RateDialog(),
    );
    if (stars == null || !mounted) return;
    final otherUid = widget.chat.participants.firstWhere(
      (u) => u != widget.viewerUid,
    );
    try {
      await widget.ratingStore.rate(
        listingId: widget.listing.id,
        chatId: widget.chat.id,
        raterId: widget.viewerUid,
        rateeId: otherUid,
        stars: stars,
      );
    } catch (_) {
      if (mounted) {
        await showBrutalErrorDialog(
          context,
          title: 'Rating failed',
          message: 'Couldn\'t save your rating — try again.',
        );
      }
      return;
    }
    await _load();
    if (!mounted) return;
    await showBrutalSuccessDialog(
      context,
      title: 'Rating saved',
      message: 'Rating saved — thanks!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final alreadyRated = _loaded && _myRating != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: UmColors.goldSoft,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.star500,
            size: 20,
            color: alreadyRated ? UmColors.mutedForeground : UmColors.ink,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alreadyRated
                  ? 'You rated this deal ★${_myRating!.stars}'
                  : 'How was the deal?',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                color: UmColors.ink,
              ),
            ),
          ),
          if (!alreadyRated)
            GestureDetector(
              onTap: _openDialog,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: UmColors.gold,
                  border: Border.all(color: UmColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: UmColors.ink,
                      offset: Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Text(
                  'Rate deal',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: UmColors.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RateDialog extends StatefulWidget {
  const _RateDialog();

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  int _stars = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: UmColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: UmColors.ink, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Rate this deal',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: UmColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'One honest score for a deal that already happened in person. '
              'It becomes part of their public ★ average.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: UmColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var star = 1; star <= 5; star++)
                  IconButton(
                    key: Key('rate-star-$star'),
                    onPressed: () => setState(() => _stars = star),
                    icon: Icon(
                      star <= _stars
                          ? LucideIcons.star500
                          : LucideIcons.star500,
                      size: 34,
                      color: star <= _stars
                          ? UmColors.gold
                          : UmColors.mutedForeground,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: NbrButton(
                    label: 'Cancel',
                    fill: UmColors.surface,
                    labelColor: UmColors.ink,
                    stretch: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NbrButton(
                    label: 'Rate',
                    fill: UmColors.gold,
                    labelColor: UmColors.ink,
                    stretch: true,
                    onPressed: _stars == 0
                        ? null
                        : () => Navigator.of(context).pop(_stars),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
