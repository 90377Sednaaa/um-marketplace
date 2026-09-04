import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../data/report_store.dart';
import '../home/browse_screen.dart';
import '../home/relative_time.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal_shimmer.dart';
import '../widgets/nbr_button.dart';
import 'chat_thread_screen.dart';

/// Conversation list (DESIGN.md screen 6): the shell's brand
/// band serves as the header; the body starts with a 'Conversations'
/// section title. Empty state is brutal with CTA to Browse.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({
    super.key,
    required this.viewerUid,
    required this.chatStore,
    required this.memberStore,
    required this.listingsStore,
    required this.ratingStore,
    required this.reportStore,
  });

  final String viewerUid;
  final ChatStore chatStore;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final RatingStore ratingStore;
  final ReportStore reportStore;

  void _openBrowse(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrowseScreen(
          viewerUid: viewerUid,
          memberStore: memberStore,
          listingsStore: listingsStore,
          chatStore: chatStore,
          ratingStore: ratingStore,
          reportStore: reportStore,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Chat>>(
          stream: chatStore.myChatsStream(viewerUid),
          builder: (context, snapshot) {
            final chats = snapshot.data;
            if (chats == null) return const _ChatsSkeleton();
            if (chats.isEmpty) {
              return _ChatsEmpty(onBrowse: () => _openBrowse(context));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Conversations',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                for (final chat in chats)
                  _ChatRow(
                    chat: chat,
                    viewerUid: viewerUid,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChatThreadScreen(
                          chat: chat,
                          viewerUid: viewerUid,
                          chatStore: chatStore,
                          memberStore: memberStore,
                          listingsStore: listingsStore,
                          ratingStore: ratingStore,
                          reportStore: reportStore,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.chat,
    required this.viewerUid,
    required this.onTap,
  });

  final Chat chat;
  final String viewerUid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final otherName =
        viewerUid == chat.buyerId ? chat.sellerName : chat.buyerName;
    final shownName = otherName.isEmpty ? 'UM student' : otherName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
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
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    otherName.isEmpty ? UmColors.muted : UmColors.gold,
                child: Text(
                  otherName.isEmpty ? '?' : otherName[0].toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: otherName.isEmpty
                        ? UmColors.mutedForeground
                        : UmColors.ink,
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
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      chat.lastMessagePreview.isEmpty
                          ? 'No messages yet'
                          : chat.lastMessagePreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: UmColors.mutedForeground,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                chat.lastMessageAt == null
                    ? ''
                    : formatRelativeTime(chat.lastMessageAt!),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: UmColors.mutedForeground,
                      fontSize: 11.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatsSkeleton extends StatelessWidget {
  const _ChatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Conversations',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        BrutalShimmer(
          child: Column(
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                        const BrutalSkeletonBox(
                          width: 44,
                          height: 44,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                          hasBorder: true,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BrutalSkeletonBox(
                                height: 14,
                                width: 110,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(4)),
                              ),
                              SizedBox(height: 6),
                              BrutalSkeletonBox(
                                height: 11,
                                width: 180,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(4)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const BrutalSkeletonBox(
                          height: 12,
                          width: 36,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatsEmpty extends StatelessWidget {
  const _ChatsEmpty({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Conversations',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
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
                  LucideIcons.messagesSquare500,
                  size: 28,
                  color: UmColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'NO CONVERSATIONS',
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
                'No conversations yet — tap Chat on a listing to start one.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: UmColors.mutedForeground,
                    ),
              ),
              const SizedBox(height: 16),
              NbrButton(
                label: 'Browse listings',
                icon: const Icon(LucideIcons.search500, size: 18, color: UmColors.ink),
                fill: UmColors.gold,
                labelColor: UmColors.ink,
                onPressed: onBrowse,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
