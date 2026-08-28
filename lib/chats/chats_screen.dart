import 'package:flutter/material.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../home/relative_time.dart';
import '../theme/app_theme.dart';
import 'chat_thread_screen.dart';

/// Conversation list (DESIGN.md screen 6, first half): the shell's brand
/// band serves as the header; the body starts with a 'Conversations'
/// section title. No unread markers in v1 (deferred to the notification
/// stage, ADR 0005).
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({
    super.key,
    required this.viewerUid,
    required this.chatStore,
    required this.memberStore,
    required this.listingsStore,
    required this.ratingStore,
  });

  final String viewerUid;
  final ChatStore chatStore;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final RatingStore ratingStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Chat>>(
          stream: chatStore.myChatsStream(viewerUid),
          builder: (context, snapshot) {
            final chats = snapshot.data;
            if (chats == null) return const _ChatsSkeleton();
            if (chats.isEmpty) return const _ChatsEmpty();
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
                    memberStore: memberStore,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChatThreadScreen(
                          chat: chat,
                          viewerUid: viewerUid,
                          chatStore: chatStore,
                          memberStore: memberStore,
                          listingsStore: listingsStore,
                          ratingStore: ratingStore,
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
    required this.memberStore,
    required this.onTap,
  });

  final Chat chat;
  final String viewerUid;
  final MemberStore memberStore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final otherUid = chat.participants.firstWhere((uid) => uid != viewerUid);
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
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              StreamBuilder<Member?>(
                stream: memberStore.memberChanges(otherUid),
                builder: (context, snapshot) {
                  final member = snapshot.data;
                  return CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        member == null ? UmColors.muted : UmColors.gold,
                    child: Text(
                      member == null || member.displayName.isEmpty
                          ? '?'
                          : member.displayName[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: member == null
                            ? UmColors.mutedForeground
                            : UmColors.ink,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreamBuilder<Member?>(
                      stream: memberStore.memberChanges(otherUid),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data?.displayName ?? 'UM student',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        );
                      },
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
        for (var i = 0; i < 4; i++)
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

class _ChatsEmpty extends StatelessWidget {
  const _ChatsEmpty();

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
          ),
          child: Column(
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 48,
                color: UmColors.mutedForeground,
              ),
              const SizedBox(height: 12),
              Text(
                'No conversations yet — tap Chat on a listing to start one.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}