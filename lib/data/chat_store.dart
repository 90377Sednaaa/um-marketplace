import 'package:cloud_firestore/cloud_firestore.dart';

import '../home/money_format.dart';
import 'listing_store.dart';

/// Chat doc id: one chat per (listing, buyer) pair, deterministic so
/// find-or-create is idempotent (ADR 0009).
String chatIdFor(String listingId, String buyerId) => '${listingId}_$buyerId';

/// Truncation length for the conversation-list preview.
const int kChatPreviewLength = 60;

/// A chat document — `chats/{listingId}_{buyerId}` (ADR 0007/0009).
class Chat {
  const Chat({
    required this.id,
    required this.listingId,
    required this.sellerId,
    required this.buyerId,
    this.participants = const {},
    this.lastMessagePreview = '',
    this.lastMessageAt,
  });

  final String id;
  final String listingId;
  final String sellerId;
  final String buyerId;

  /// Exactly `{sellerId, buyerId}` — the rules require a 2-entry map with
  /// both values true, and every message copies this map verbatim.
  final Set<String> participants;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;

  factory Chat.fromDoc(String id, Map<String, dynamic> data) {
    final participantsData = data['participants'];
    return Chat(
      id: id,
      listingId: data['listingId'] as String? ?? '',
      sellerId: data['sellerId'] as String? ?? '',
      buyerId: data['buyerId'] as String? ?? '',
      participants: participantsData is Map
          ? participantsData.keys.whereType<String>().toSet()
          : const {},
      lastMessagePreview: data['lastMessagePreview'] as String? ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// A message under `chats/{chatId}/messages/{msgId}` (ADR 0007).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.text,
    this.price,
    this.createdAt,
  });

  final String id;
  final String senderId;

  /// 'text' | 'offer' — the rules reject anything else; offers carry a
  /// price greater than zero.
  final String type;
  final String text;
  final double? price;
  final DateTime? createdAt;

  factory ChatMessage.fromDoc(String id, Map<String, dynamic> data) {
    return ChatMessage(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      type: data['type'] as String? ?? 'text',
      text: data['text'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// List preview for a message: offers are money-formatted, text is
/// truncated (matches what the chat doc's `lastMessagePreview` holds).
String chatPreview(ChatMessage message) {
  if (message.type == 'offer' && message.price != null) {
    return 'Offer: ${formatPesos(message.price!)}';
  }
  final text = message.text.trim();
  if (text.length <= kChatPreviewLength) return text;
  return '${text.substring(0, kChatPreviewLength)}…';
}

/// Merges the buyer-side and seller-side "my conversations" query results
/// into one list: dedupe by id, most recent activity first, capped at 50.
/// A chat belongs to exactly one side (buyerId != sellerId per the rules),
/// so duplicates only occur across a re-fetch window.
List<Chat> mergeChatStreams(List<Chat> a, List<Chat> b) {
  final byId = <String, Chat>{};
  for (final chat in [...a, ...b]) {
    byId[chat.id] = chat;
  }
  final chats = byId.values.toList()
    ..sort((x, y) {
      final xAt = x.lastMessageAt;
      final yAt = y.lastMessageAt;
      if (xAt == null && yAt == null) return 0;
      if (xAt == null) return 1; // chats with no activity last
      if (yAt == null) return -1;
      return yAt.compareTo(xAt);
    });
  return chats.take(50).toList();
}

/// Why opening a chat failed — the UI maps these to snackbar copy.
enum ChatOpenFailure { listingInactive, rejected }

class ChatOpenException implements Exception {
  const ChatOpenException(this.reason);

  final ChatOpenFailure reason;
}

/// A message send was refused (blocked pair or rules rejection).
class ChatSendException implements Exception {
  const ChatSendException();
}

/// The chat surface the UI depends on (injected, fake-able in tests).
abstract interface class ChatStore {
  /// My conversations, most recent activity first (merged buyer/seller
  /// queries, limit 50) — realtime.
  Stream<List<Chat>> myChatsStream(String uid);

  /// All messages of a chat, oldest first — realtime.
  Stream<List<ChatMessage>> chatMessagesStream(String chatId);

  /// Find-or-create (deterministic id). Throws [ChatOpenException].
  Future<Chat> openChatWithBuyer({
    required Listing listing,
    required String buyerUid,
  });

  /// Sends a text message; atomic with chat-doc bookkeeping. Throws
  /// [ChatSendException] when the rules refuse the write.
  Future<void> sendText(
    Chat chat, {
    required String senderId,
    required String text,
  });

  /// Sends an offer-typed message with a price; atomic with bookkeeping.
  Future<void> sendOffer(
    Chat chat, {
    required String senderId,
    required double price,
    String text = '',
  });
}