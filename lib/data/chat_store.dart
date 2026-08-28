import 'dart:async';

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

class FirestoreChatStore implements ChatStore {
  FirestoreChatStore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Chat>> myChatsStream(String uid) {
    final buyerSide = _firestore
        .collection('chats')
        .where('buyerId', isEqualTo: uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots()
        .map(_chatsFrom);
    final sellerSide = _firestore
        .collection('chats')
        .where('sellerId', isEqualTo: uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots()
        .map(_chatsFrom);
    return _mergeSides(buyerSide, sellerSide);
  }

  List<Chat> _chatsFrom(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs.map((doc) => Chat.fromDoc(doc.id, doc.data())).toList();

  /// Two-query merge (spec §2.4): a chat belongs to exactly one side, so
  /// the latest of either side re-sorts the merged list.
  Stream<List<Chat>> _mergeSides(Stream<List<Chat>> a, Stream<List<Chat>> b) {
    late StreamSubscription<List<Chat>> subA;
    late StreamSubscription<List<Chat>> subB;
    List<Chat>? latestA;
    List<Chat>? latestB;
    final controller = StreamController<List<Chat>>.broadcast();
    void emit() {
      if (latestA == null || latestB == null) return;
      controller.add(mergeChatStreams(latestA!, latestB!));
    }

    subA = a.listen((chats) {
      latestA = chats;
      emit();
    }, onError: controller.addError);
    subB = b.listen((chats) {
      latestB = chats;
      emit();
    }, onError: controller.addError);
    controller.onCancel = () async {
      await subA.cancel();
      await subB.cancel();
    };
    return controller.stream;
  }

  @override
  Stream<List<ChatMessage>> chatMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromDoc(doc.id, doc.data()))
            .toList());
  }

  @override
  Future<Chat> openChatWithBuyer({
    required Listing listing,
    required String buyerUid,
  }) async {
    final id = chatIdFor(listing.id, buyerUid);
    final doc = _firestore.collection('chats').doc(id);
    final existing = await doc.get();
    if (existing.exists) return Chat.fromDoc(id, existing.data()!);

    try {
      await doc.set({
        'listingId': listing.id,
        'sellerId': listing.sellerId,
        'buyerId': buyerUid,
        'participants': {listing.sellerId: true, buyerUid: true},
        'lastMessagePreview': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Rules see a blocked pair or a non-active listing. Distinguish
        // deterministically (spec §2.4): re-read the listing.
        final listingSnap =
            await _firestore.collection('listings').doc(listing.id).get();
        final status = listingSnap.data()?['status'];
        if (status != null && status != 'active') {
          throw const ChatOpenException(ChatOpenFailure.listingInactive);
        }
      }
      throw const ChatOpenException(ChatOpenFailure.rejected);
    }
    return Chat.fromDoc(id, (await doc.get()).data()!);
  }

  @override
  Future<void> sendText(
    Chat chat, {
    required String senderId,
    required String text,
  }) async {
    await _send(chat, senderId, 'text', text);
  }

  @override
  Future<void> sendOffer(
    Chat chat, {
    required String senderId,
    required double price,
    String text = '',
  }) async {
    await _send(chat, senderId, 'offer', text, price: price);
  }

  /// Batch: message doc + chat-doc bookkeeping, both-or-neither. The
  /// participants map is copied exactly from [chat] (rule line 201).
  Future<void> _send(Chat chat, String senderId, String type, String text,
      {double? price}) async {
    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('chats').doc(chat.id).collection('messages').doc(),
      {
        'senderId': senderId,
        'type': type,
        'text': text,
        'price': ?price,
        'participants': {
          for (final uid in chat.participants) uid: true,
        },
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    batch.update(
      _firestore.collection('chats').doc(chat.id),
      {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessagePreview': chatPreview(ChatMessage(
          id: '',
          senderId: senderId,
          type: type,
          text: text,
          price: price,
        )),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    try {
      await batch.commit();
    } on FirebaseException {
      throw const ChatSendException();
    }
  }
}