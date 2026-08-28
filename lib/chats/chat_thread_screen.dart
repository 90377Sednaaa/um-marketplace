import 'package:flutter/material.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../home/listing_detail_screen.dart';
import '../home/money_format.dart';
import '../theme/app_theme.dart';
import '../widgets/offer_price_dialog.dart';
import '../widgets/photo_placeholder.dart';

/// Chat thread (DESIGN.md screen 6): pinned product snippet, message
/// list (text + offer blocks), composer. No money changes hands anywhere
/// (ADR 0002). Sending is fire-and-forget with a snackbar on refusal.
class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({
    super.key,
    required this.chat,
    required this.viewerUid,
    required this.chatStore,
    required this.memberStore,
    required this.listingsStore,
  });

  final Chat chat;
  final String viewerUid;
  final ChatStore chatStore;
  final MemberStore memberStore;
  final ListingStore listingsStore;

  void _send(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await chatStore.sendText(chat, senderId: viewerUid, text: text);
    } on ChatSendException {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text("You can't message this member right now")));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Couldn\'t send — try again.')));
    }
  }

  void _sendOffer(BuildContext context, double price) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await chatStore.sendOffer(chat, senderId: viewerUid, price: price);
    } on ChatSendException {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text("You can't message this member right now")));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Couldn\'t send — try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherUid = chat.participants.firstWhere((uid) => uid != viewerUid);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ThreadHeader(otherUid: otherUid, memberStore: memberStore),
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
                      ),
                      if (!active) const _InactiveBanner(),
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
                          if (text.trim().isNotEmpty) _send(context, text.trim());
                        },
                        onOffer: active && isBuyer
                            ? () async {
                                final price =
                                    await showOfferPriceDialog(context);
                                if (!context.mounted) return;
                                if (price != null) _sendOffer(context, price);
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
  const _ThreadHeader({required this.otherUid, required this.memberStore});

  final String otherUid;
  final MemberStore memberStore;

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
          Expanded(
            child: StreamBuilder<Member?>(
              stream: memberStore.memberChanges(otherUid),
              builder: (context, snapshot) {
                final name = snapshot.data?.displayName ?? 'Chat';
                return Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: UmColors.onPrimary,
                  ),
                );
              },
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
          Container(
            height: 96,
            decoration: BoxDecoration(
              color: UmColors.muted,
              border: Border.all(color: UmColors.ink, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: UmColors.muted,
                border: Border.all(color: UmColors.ink, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
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
  });

  final Listing listing;
  final ListingStore listingsStore;
  final MemberStore memberStore;
  final ChatStore chatStore;
  final String viewerUid;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onTap = listing.status != 'active'
        ? null
        : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ListingDetailScreen(
                  listing: listing,
                  memberStore: memberStore,
                  listingsStore: listingsStore,
                  chatStore: chatStore,
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
          Icon(Icons.lock_outline, size: 18, color: UmColors.ink),
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
          return const SizedBox.shrink();
        }
        if (messages.isEmpty) {
          return Center(
            child: Text(
              'Say hi — or send an offer.',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
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
  const _Composer({
    required this.enabled,
    required this.onSend,
    this.onOffer,
  });

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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      color: UmColors.mutedForeground, width: 2),
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
                  child: const Icon(Icons.request_quote_outlined,
                      size: 24, color: UmColors.ink),
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
          Icons.send,
          size: 22,
          color: enabled ? UmColors.onPrimary : UmColors.mutedForeground,
        ),
      ),
    );
  }
}