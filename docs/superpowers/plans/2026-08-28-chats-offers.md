# Chats + Offers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Chats + offers subsystem — bottom-nav shell, conversation list, chat thread with offer-typed messages — over the already-drafted Firestore rules, reactivating the detail screen's Chat/Make-an-offer bar.

**Architecture:** Store-interface pattern exactly like `ListingStore`/`MemberStore`: a `ChatStore` abstract interface injected at the root and fake-able in widget tests; deterministic chat ids (`{listingId}_{buyerId}`) for idempotent find-or-create; batch writes for message + chat-doc bookkeeping; "my conversations" = two plain-field queries (`buyerId`, `sellerId`) merged client-side (map-key equality cannot be indexed per user). App shell restructures into a 3-tab bottom nav (Home, Sell, Chats) with `IndexedStack`.

**Tech Stack:** Flutter/Dart, `cloud_firestore` (already in `pubspec.yaml` — no new dependencies), existing neubrutalist design tokens (`lib/theme/app_theme.dart`), `NbrButton` component.

**Spec:** `docs/superpowers/specs/2026-08-28-chats-offers-design.md` (approved 2026-08-28).

## Global Constraints

- **TDD:** write the failing test first, watch it fail, then implement; every task ends with `flutter analyze` clean + `flutter test` green.
- **Commit per task** with a conventional message; push after all tasks (AGENTS.md: verify before committing, never a broken tree).
- **No new pub dependencies.**
- **Widget tests never touch Firebase** — always via fakes; broadcast streams drop events with no replay, so tests must **settle-then-emit** (pump `pumpAndSettle()` after signing in and AFTER switching to the tab whose screen subscribes to a fake stream, before `emit*`).
- **Snackbar timers:** any test that shows a `SnackBar` must pump `const Duration(seconds: 5)` + `pumpAndSettle()` before ending, or the test fails on a pending timer.
- **Tall-portrait viewport for full-screen tests:** reuse the existing `usePortraitPhone(tester)` helper (`Size(1080, 2400)`, dpr 1.0) for any screen taller than the default 800×600.
- **No leading underscores on local identifiers** (lint `no_leading_underscores_for_local_identifiers`).
- Existing tests that must keep passing: sign-in gate, member creation, banned screen, feed, detail screen (7 tests), sell flow, sign-out, data units (34 total before this plan).
- Design-token rules (DESIGN.md §2): gold fills carry black ink only; prices green w800; ink borders 2 dp; hard shadows `Offset(4,4)` blur 0.

---

### Task 1: Chat data models, helpers, and the `ChatStore` interface

**Files:**
- Create: `lib/data/chat_store.dart`
- Modify: `test/data_test.dart`

**Interfaces:**
- Produces (everything later tasks rely on):
  - `class Chat { final String id; final String listingId; final String sellerId; final String buyerId; final Set<String> participants; final String lastMessagePreview; final DateTime? lastMessageAt; Chat.fromDoc(String id, Map<String, dynamic> data); }`
  - `class ChatMessage { final String id; final String senderId; final String type; final String text; final double? price; final DateTime? createdAt; ChatMessage.fromDoc(String id, Map<String, dynamic> data); }`
  - `String chatIdFor(String listingId, String buyerId)` → `'${listingId}_${buyerId}'`
  - `String chatPreview(ChatMessage message)` → text truncated to 60 chars + `…`, or `'Offer: ₱250'` (via `formatPesos` from `lib/home/money_format.dart`)
  - `List<Chat> mergeChatStreams(List<Chat> a, List<Chat> b)` → dedupe by id, sort by `lastMessageAt` descending (nulls last), cap 50
  - `enum ChatOpenFailure { listingInactive, rejected }` + `class ChatOpenException implements Exception { final ChatOpenFailure reason; }`
  - `class ChatSendException implements Exception {}`
  - `abstract interface class ChatStore { Stream<List<Chat>> myChatsStream(String uid); Stream<List<ChatMessage>> chatMessagesStream(String chatId); Future<Chat> openChatWithBuyer({required Listing listing, required String buyerUid}); Future<void> sendText(Chat chat, {required String senderId, required String text}); Future<void> sendOffer(Chat chat, {required String senderId, required double price, String text = ''}); }`
  - Also export a `const int kChatPreviewLength = 60;`

**Fixtures:** `test/data_test.dart` already imports `dart:typed_data`, `cloud_firestore` (for `Timestamp`), and the store/format files; check its existing imports when editing and add `package:um_marketplace/data/chat_store.dart`.

- [ ] **Step 1: Write the failing unit tests**

Append to `test/data_test.dart` (`main()`, before the closing `}`):

```dart
  test('chatIdFor joins listing and buyer with an underscore', () {
    expect(chatIdFor('abc123', 'buyer1'), 'abc123_buyer1');
  });

  test('Chat.fromDoc reads the chat fields and participants', () {
    final chat = Chat.fromDoc('abc_b1', {
      'listingId': 'abc',
      'sellerId': 's1',
      'buyerId': 'b1',
      'participants': {'s1': true, 'b1': true},
      'lastMessagePreview': 'Hey!',
      'lastMessageAt': Timestamp.fromDate(DateTime(2026, 8, 28, 12)),
    });
    expect(chat.id, 'abc_b1');
    expect(chat.listingId, 'abc');
    expect(chat.sellerId, 's1');
    expect(chat.buyerId, 'b1');
    expect(chat.participants, {'s1', 'b1'});
    expect(chat.lastMessagePreview, 'Hey!');
    expect(chat.lastMessageAt, DateTime(2026, 8, 28, 12));
  });

  test('Chat.fromDoc defaults a fresh chat with no preview yet', () {
    final chat = Chat.fromDoc('abc_b1', {
      'listingId': 'abc',
      'sellerId': 's1',
      'buyerId': 'b1',
      'participants': {'s1': true, 'b1': true},
    });
    expect(chat.lastMessagePreview, '');
    expect(chat.lastMessageAt, isNull);
  });

  test('ChatMessage.fromDoc reads text and offer messages', () {
    final text = ChatMessage.fromDoc('m1', {
      'senderId': 's1',
      'type': 'text',
      'text': 'Hello',
      'createdAt': Timestamp.fromDate(DateTime(2026, 8, 28, 12)),
    });
    expect(text.type, 'text');
    expect(text.text, 'Hello');
    expect(text.price, isNull);

    final offer = ChatMessage.fromDoc('m2', {
      'senderId': 'b1',
      'type': 'offer',
      'text': 'Would you take this?',
      'price': 250,
      'createdAt': Timestamp.fromDate(DateTime(2026, 8, 28, 13)),
    });
    expect(offer.type, 'offer');
    expect(offer.price, 250.0);
    expect(offer.createdAt, DateTime(2026, 8, 28, 13));
  });

  test('chatPreview truncates long text and formats offers', () {
    final long = ChatMessage.fromDoc('m1', {
      'senderId': 's1',
      'type': 'text',
      'text': List.filled(80, 'x').join(),
    });
    expect(chatPreview(long).length, kChatPreviewLength + 1); // + '…'
    expect(chatPreview(long).endsWith('…'), isTrue);

    final offer = ChatMessage.fromDoc('m2', {
      'senderId': 'b1',
      'type': 'offer',
      'text': '',
      'price': 250,
    });
    expect(chatPreview(offer), 'Offer: ₱250');
  });

  test('mergeChatStreams dedupes, sorts by activity desc, caps at 50', () {
    Chat chat(String id, DateTime? at) => Chat(
        id: id,
        listingId: 'l-$id',
        sellerId: 's-$id',
        buyerId: 'b-$id',
        participants: {'s-$id', 'b-$id'},
        lastMessagePreview: '',
        lastMessageAt: at);

    final a = [
      chat('1', DateTime(2026, 8, 28, 10)),
      chat('2', DateTime(2026, 8, 28, 9)),
    ];
    final b = [
      chat('3', DateTime(2026, 8, 28, 11)),
      chat('1', DateTime(2026, 8, 28, 10)), // duplicate across sides
      chat('4', null),
    ];
    final merged = mergeChatStreams(a, b);
    expect(merged.map((c) => c.id).toList(), ['3', '1', '2', '4']);
    expect(merged.length, 4);
  });

  test('chat open/send failures are typed exceptions', () {
    expect(ChatOpenException(ChatOpenFailure.listingInactive).reason,
        ChatOpenFailure.listingInactive);
    expect(ChatSendException(), isA<Exception>());
  });
```

`Chat` needs a public const constructor for the fake (used here); give it the same shape as `Listing` (positional-optional fields) so construction from tests is natural: `Chat({required this.id, required this.listingId, required this.sellerId, required this.buyerId, this.participants = const {}, this.lastMessagePreview = '', this.lastMessageAt})`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/data_test.dart`
Expected: FAIL — `chatIdFor`/`Chat`/`ChatMessage`/`chatPreview`/`mergeChatStreams` undefined.

- [ ] **Step 3: Implement `lib/data/chat_store.dart`**

```dart
import 'dart:typed_data'; // unused here — do NOT import; keep list minimal

import 'package:cloud_firestore/cloud_firestore.dart';

import '../home/money_format.dart';

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
  Future<void> sendText(Chat chat, {required String senderId, required String text});

  /// Sends an offer-typed message with a price; atomic with bookkeeping.
  Future<void> sendOffer(Chat chat, {required String senderId, required double price, String text = ''});
}
```

Do NOT write `FirestoreChatStore` in this task (it lands in Task 4, which also owns the merged-stream combiner) — the interface is the deliverable here.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/data_test.dart`
Expected: PASS (all tests, including the new ones).

- [ ] **Step 5: Static analysis + commit**

```bash
flutter analyze   # expect: No issues found
git add lib/data/chat_store.dart test/data_test.dart
git commit -m "feat(chat): Chat/ChatMessage models, preview + merge helpers, ChatStore interface
- Deterministic chat id scheme (ADR 0009), preview truncation + Offer formatting, merged two-query list logic, typed open/send exceptions"
```

---

### Task 2: `ListingStore.listingChanges` for live listing watches

**Files:**
- Modify: `lib/data/listing_store.dart`
- Modify: `test/widget_test.dart` (FakeListingsStore)

**Interfaces:**
- Consumes: existing `ListingStore` interface (`lib/data/listing_store.dart`), the `Listing` model.
- Produces: `Stream<Listing?> listingChanges(String id)` on `ListingStore` and on `FirestoreListingsStore`; `FakeListingsStore` (`test/widget_test.dart`) gains the method + `void emitListing(String id, Listing? listing)`.

- [ ] **Step 1: Add the interface method + Firestore implementation**

In `lib/data/listing_store.dart`, inside `abstract interface class ListingStore`, after `createListing`:

```dart
  /// Live single-listing watch (get-then-listen): the thread screen uses
  /// it for the pinned snippet and the status banner.
  Stream<Listing?> listingChanges(String id);
```

In `FirestoreListingsStore`:

```dart
  @override
  Stream<Listing?> listingChanges(String id) {
    return _firestore
        .collection('listings')
        .doc(id)
        .snapshots()
        .map((snapshot) =>
            snapshot.exists ? Listing.fromDoc(snapshot.id, snapshot.data()!) : null);
  }
```

- [ ] **Step 2: Extend the fake (this is the failing test — analyzer-enforced)**

In `test/widget_test.dart`, `FakeListingsStore`:

```dart
class FakeListingsStore implements ListingStore {
  final _controller = StreamController<List<Listing>>.broadcast();
  final _listingControllers = <String, StreamController<Listing?>>{};
  final drafts = <ListingDraft>[];
  List<Listing> listings = [];

  StreamController<Listing?> _listingFor(String id) =>
      _listingControllers.putIfAbsent(id, StreamController<Listing?>.broadcast);

  @override
  Stream<List<Listing>> activeListingsStream() => _controller.stream;

  @override
  Stream<Listing?> listingChanges(String id) => _listingFor(id).stream;

  void emitListing(String id, Listing? listing) =>
      _listingFor(id).add(listing);

  void emitListings() => _controller.add(List.of(listings));
  // ... createListing unchanged
}
```

- [ ] **Step 3: Verify RED → GREEN**

Run: `flutter analyze` — must FAIL first with `missing_override`/`missing_concrete_implementation` before Step 1's interface edit is applied if you did it after (order matters: run analyze with ONLY the fake change to see the failure, then apply Step 1); then with both changes: `flutter analyze` clean. Full run: `flutter test` — all 34 existing tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/data/listing_store.dart test/widget_test.dart
git commit -m "feat(listing): add listingChanges for live listing watches
- Thread screen and future screens watch listings/{id} for snippet + status; fake gains emitListing"
```

---

### Task 3: App shell, bottom nav, and constructor threading

**Files:**
- Create: `lib/home/app_shell.dart`
- Modify: `lib/home/home_screen.dart` (drop maroon band; CTA switches tab), `lib/home/sell_screen.dart` (drop band + back button; `onPublished` callback), `lib/members/member_gate.dart`, `lib/app.dart`
- Modify: `test/widget_test.dart` (FakeChatStore; new shell tests)

**Interfaces:**
- Consumes: `HomeScreen` (existing), `SellScreen` (existing), `ChatsScreen` (NOT yet — Task 5; Task 3 uses a private placeholder `_ComingSoonTab` for the Chats slot OR — better — accept an empty `ChatsScreen`-shaped placeholder widget defined privately in `app_shell.dart` until Task 5; simpler: Task 3 renders a plain placeholder container for the third tab, replaced in Task 5).
- Produces:
  - `class AppShell extends StatelessWidget { const AppShell({required this.member, required this.memberStore, required this.listingsStore, required this.chatStore, required this.onSignOut}); }`
  - `HomeScreen` signature gains `{required this.onSellRequested}` (`VoidCallback`) and `{required this.chatStore}`; loses its maroon band.
  - `SellScreen` signature gains `{required this.onPublished}` (`VoidCallback`); loses its maroon band + back button; publish success calls `onPublished` instead of `Navigator.pop`.
  - `FakeChatStore` (in `test/widget_test.dart`, full shape for all later tasks):

```dart
class FakeChatStore implements ChatStore {
  final chats = <String, Chat>{};
  final messages = <String, List<ChatMessage>>{};
  final _listController = StreamController<List<Chat>>.broadcast();
  final _messageControllers = <String, StreamController<List<ChatMessage>>>{};
  bool failOpen = false;
  ChatOpenFailure openFailure = ChatOpenFailure.rejected;
  bool failSend = false;
  int _messageSeq = 0;

  StreamController<List<ChatMessage>> _for(String chatId) =>
      _messageControllers.putIfAbsent(
          chatId, StreamController<List<ChatMessage>>.broadcast);

  @override
  Stream<List<Chat>> myChatsStream(String uid) => _listController.stream;

  @override
  Stream<List<ChatMessage>> chatMessagesStream(String chatId) =>
      _for(chatId).stream;

  void emitList() => _listController.add(chats.values.toList());

  void emitMessages(String chatId) =>
      _for(chatId).add(List.of(messages[chatId] ?? const []));

  @override
  Future<Chat> openChatWithBuyer({
    required Listing listing,
    required String buyerUid,
  }) async {
    if (failOpen) throw ChatOpenException(openFailure);
    final id = chatIdFor(listing.id, buyerUid);
    final existing = chats[id];
    if (existing != null) return existing;
    final chat = Chat(
      id: id,
      listingId: listing.id,
      sellerId: listing.sellerId,
      buyerId: buyerUid,
      participants: {listing.sellerId, buyerUid},
    );
    chats[id] = chat;
    emitList();
    return chat;
  }

  @override
  Future<void> sendText(Chat chat, {required String senderId, required String text}) async {
    if (failSend) throw ChatSendException();
    _append(ChatMessage(
      id: 'm${_messageSeq++}',
      senderId: senderId,
      type: 'text',
      text: text,
      createdAt: DateTime(2026, 8, 28, 12),
    ));
  }

  @override
  Future<void> sendOffer(Chat chat, {required String senderId, required double price, String text = ''}) async {
    if (failSend) throw ChatSendException();
    _append(ChatMessage(
      id: 'm${_messageSeq++}',
      senderId: senderId,
      type: 'offer',
      text: text,
      price: price,
      createdAt: DateTime(2026, 8, 28, 12),
    ));
  }

  void _append(Chat chat, ChatMessage message) {
    // Mirrors the Firestore batch: message appended and the chat doc's
    // preview/timestamp updated, then both streams emit.
    final list = messages.putIfAbsent(chat.id, () => []);
    list.add(message);
    chats[chat.id] = Chat(
      id: chat.id,
      listingId: chat.listingId,
      sellerId: chat.sellerId,
      buyerId: chat.buyerId,
      participants: chat.participants,
      lastMessagePreview: chatPreview(message),
      lastMessageAt: message.createdAt,
    );
    emitMessages(chat.id);
    emitList();
  }

- [ ] **Step 1: Write the failing shell tests** (append to `test/widget_test.dart` main)

```dart
  testWidgets('bottom nav shows 3 tabs and switches between them',
      (WidgetTester tester) async {
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(_app(
      auth: auth,
      members: members,
      listings: listings,
      chats: chats,
    ));
    auth.emit(_student);
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Sell'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Recent listings'), findsOneWidget);

    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('Recent listings'), findsNothing);

    await tester.tap(find.text('Sell'));
    await tester.pumpAndSettle();
    expect(find.text('Publish listing'), findsOneWidget);
  });

  testWidgets('the Sell CTA switches to the Sell tab', (WidgetTester tester) async {
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(_app(auth: auth, members: members, listings: listings, chats: chats));
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sell something'));
    await tester.pumpAndSettle();

    expect(find.text('Publish listing'), findsOneWidget);
  });

  testWidgets('the sell draft survives switching tabs (IndexedStack)',
      (WidgetTester tester) async {
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(_app(auth: auth, members: members, listings: listings, chats: chats));
    auth.emit(_student);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sell'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Half-finished draft');
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sell'));
    await tester.pumpAndSettle();

    expect(find.text('Half-finished draft'), findsOneWidget);
  });

  testWidgets('publishing from the Sell tab lands back on Home',
      (WidgetTester tester) async {
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(_app(auth: auth, members: members, listings: listings, chats: chats));
    auth.emit(_student);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sell'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField).at(0));
    await tester.enterText(find.byType(TextField).at(0), 'Tab publish');
    await tester.ensureVisible(find.byType(TextField).at(1));
    await tester.enterText(find.byType(TextField).at(1), '120');
    await tester.ensureVisible(find.text('textbooks'));
    await tester.tap(find.text('textbooks'));
    await tester.pump();
    await tester.ensureVisible(find.text('Publish listing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish listing'));
    await tester.pumpAndSettle();

    expect(find.text('Recent listings'), findsOneWidget); // back on Home tab
    expect(listings.drafts, hasLength(1));
  });
```

Also update the `_app` helper (add `chats`):

```dart
Widget _app({
  FakeAuthService? auth,
  FakeMemberStore? members,
  FakeListingsStore? listings,
  FakeChatStore? chats,
}) {
  return UmMarketplaceApp(
    authService: auth ?? FakeAuthService(),
    memberStore: members ?? FakeMemberStore(),
    listingsStore: listings ?? FakeListingsStore(),
    chatStore: chats ?? FakeChatStore(),
  );
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `UmMarketplaceApp` has no `chatStore` parameter (compile error).

- [ ] **Step 3: Implement the shell**

Create `lib/home/app_shell.dart`:

```dart
import 'package:flutter/material.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../theme/app_theme.dart';
import 'chats_placeholder.dart'; // placeholder Chats tab until Task 5
import 'home_screen.dart';
import 'sell_screen.dart';

/// The app shell (DESIGN.md §5): maroon brand band, an IndexedStack of the
/// three v1 tabs — Home, Sell, Chats — and the neubrutalist bottom nav.
/// Profile joins the nav with its own stage.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.member,
    required this.memberStore,
    required this.listingsStore,
    required this.chatStore,
    required this.onSignOut,
  });

  final Member member;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final Future<void> Function() onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _BrandBand(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  HomeScreen(
                    member: widget.member,
                    memberStore: widget.memberStore,
                    listingsStore: widget.listingsStore,
                    chatStore: widget.chatStore,
                    onSignOut: widget.onSignOut,
                    onSellRequested: () => setState(() => _index = 1),
                  ),
                  SellScreen(
                    sellerId: widget.member.uid,
                    listingsStore: widget.listingsStore,
                    onPublished: () => setState(() => _index = 0),
                  ),
                  const ChatPlaceholder(),
                ],
              ),
            ),
            _BottomNav(
              index: _index,
              onSelected: (i) => setState(() => _index = i),
            ),
          ],
        ),
      ),
    );
  }
}
```

  (The shell is stateful so `_index` drives both the `IndexedStack` and the `_BottomNav`; Home's CTA switches to the Sell tab, Sell's `onPublished` returns to Home.)

```dart
class _BrandBand extends StatelessWidget {
  const _BrandBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: UmColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: const Text(
        'UM MARKETPLACE',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          letterSpacing: 1.2,
          color: UmColors.onPrimary,
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      (label: 'Home', icon: Icons.home_outlined),
      (label: 'Sell', icon: Icons.add_box_outlined),
      (label: 'Chats', icon: Icons.chat_bubble_outline),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: UmColors.surface,
        border: Border(top: BorderSide(color: UmColors.ink, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _NavItem(
                label: items[i].label,
                icon: items[i].icon,
                active: i == index,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? UmColors.primary : UmColors.mutedForeground;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.linear,
        transform: Matrix4.translationValues(_pressed ? 2 : 0, _pressed ? 2 : 0, 0),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.active ? UmColors.goldSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: TextStyle(
                fontWeight: widget.active ? FontWeight.w700 : FontWeight.w600,
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Create `lib/home/chats_placeholder.dart` (stand-in until Task 5):

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Temporary Chats tab body — replaced by the real screen in the Chats
/// stage task 5.
class ChatPlaceholder extends StatelessWidget {
  const ChatPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Conversations',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: UmColors.mutedForeground,
        ),
      ),
    );
  }
}
```

  The shell test asserts `find.text('Conversations')` when the Chats tab is active — the placeholder satisfies it until Task 5 swaps in the real screen.

Modify `lib/home/home_screen.dart`:
- Add `required this.onSellRequested` (`VoidCallback`) and `required this.chatStore` (`ChatStore`) to the constructor + fields (import `../data/chat_store.dart`).
- Remove the maroon `Container` brand band (lines ~58-71 of the current file) — the shell owns it.
- `_openSell` becomes `widget.onSellRequested()` (no Navigator push). Delete the `_openSell` body/navigation and the now-unused `import 'sell_screen.dart'` if nothing else uses it.
- Keep `chatStore` field for Task 7 (unused-parameter lints do not fire on constructor fields; the field WILL be consumed in Task 7 — do not pass it onward yet).

Modify `lib/home/sell_screen.dart`:
- Constructor gains `required this.onPublished` (`VoidCallback`); add the field.
- `_publish()` success branch: `if (mounted) Navigator.of(context).pop();` → `widget.onPublished();`
- Remove the maroon band + back `IconButton` (lines ~147-168); the shell's band is the header. Remove the now-unused `Navigator.of(context).pop()` back button; keep everything else (Scaffold, SafeArea, form).
- Update the class doc comment to say it is hosted as a tab.

Modify `lib/members/member_gate.dart`: `HomeScreen(...)` → `AppShell(member: member, memberStore: widget.memberStore, listingsStore: widget.listingsStore, chatStore: widget.chatStore, onSignOut: widget.authService.signOut)`; `MemberGate` gains `required this.chatStore` field + constructor param (import `../data/chat_store.dart`, `../home/app_shell.dart`); delete the `../home/home_screen.dart` import if unused.

Modify `lib/app.dart`: `UmMarketplaceApp` gains `required this.chatStore` (`ChatStore`) + field; pass to `AuthGate(...)`; `AuthGate` gains the same param + field; pass to `MemberGate(...)`. Import `data/chat_store.dart`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/widget_test.dart`
Expected: PASS — including all existing tests (the existing sell-flow test now exercises the tab path: `Sell something` CTA switches tabs; `onPublished` returns to Home).

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze   # No issues found
git add lib/home/app_shell.dart lib/home/chats_placeholder.dart lib/home/home_screen.dart lib/home/sell_screen.dart lib/members/member_gate.dart lib/app.dart test/widget_test.dart
git commit -m "feat(shell): 3-tab bottom navigation (Home, Sell, Chats)
- AppShell with brand band, IndexedStack (draft survives tab switches), neubrutalist bottom nav per DESIGN.md §5; Sell becomes a tab (publish lands back on Home), Home CTA switches tabs; chatStore threaded from the root; FakeChatStore for tests"
```

---

### Task 4: `FirestoreChatStore` — real implementation over the drafted rules

**Files:**
- Modify: `lib/data/chat_store.dart` (add `FirestoreChatStore`)

**Interfaces:**
- Consumes: `ChatStore` (Task 1), `Chat`/`ChatMessage`/`chatIdFor`/`chatPreview`/`mergeChatStreams`/exceptions, `Listing` (existing).
- Produces: `class FirestoreChatStore implements ChatStore { FirestoreChatStore({FirebaseFirestore? firestore}); }` — the production implementation; the two-query merged stream; batch write sends; deterministic open mapping. No new widget tests in this task (the fake drives UI tests); verification = analyze + full suite. Optionally a pure-function unit test if any logic is extracted — keep all logic under the already-tested helpers.

- [ ] **Step 1: Implement**

Append to `lib/data/chat_store.dart`:

```dart
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
        .orderBy('createdAt', ascending: true)
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
  Future<void> sendText(Chat chat,
      {required String senderId, required String text}) async {
    await _send(chat, senderId, 'text', text);
  }

  @override
  Future<void> sendOffer(Chat chat,
      {required String senderId, required double price, String text = ''}) async {
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
        if (price != null) 'price': price,
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
```

  Add `import 'dart:async';` at the top of `chat_store.dart` (for `StreamSubscription`).

- [ ] **Step 2: Verify**

Run: `flutter analyze` — No issues found. Run: `flutter test` — full suite still green (34+ tests).

- [ ] **Step 3: Commit**

```bash
git add lib/data/chat_store.dart
git commit -m "feat(chat): FirestoreChatStore over the drafted rules
- Deterministic find-or-create with typed failure mapping (inactive listing vs rejected), batch message + bookkeeping writes, two-query merged 'my conversations' stream"
```

---

### Task 5: Relative time + chat thread screen

**Files:**
- Create: `lib/home/relative_time.dart`
- Create: `lib/chats/chat_thread_screen.dart`
- Modify: `test/data_test.dart` (relative-time units), `test/widget_test.dart` (thread widget tests)

**Interfaces:**
- Consumes: `Chat`, `ChatMessage`, `ChatStore`, `ChatOpenException`/`ChatSendException` (Task 1), `ListingStore.listingChanges` (Task 2), `MemberStore`, `usePortraitPhone` helper + `FakeChatStore`/`FakeListingsStore`/`FakeMemberStore` (existing tests).
- Produces:
  - `String formatRelativeTime(DateTime time, {DateTime? now})` in `lib/home/relative_time.dart` → `'now'` (<1 min), `'2m'`, `'3h'`, `'yesterday'` (1–2 days), `'Aug 12'` (same year), `'12 Aug 2024'` (older years).
  - `class ChatThreadScreen extends StatelessWidget { const ChatThreadScreen({required this.chat, required this.viewerUid, required this.chatStore, required this.memberStore, required this.listingsStore}); }`
  - `Future<void> showOfferPriceDialog(BuildContext context)` → returns `double?` via `Navigator.pop` — NO, this dialog lands in Task 6 (shared with the detail screen). Task 5's offer UIs are NOT included; the thread's offer affordance/block lands in Task 6 too. Scope Task 5 to text messaging only: render messages (including offer-typed ones as a plain gold block so existing data renders correctly — rendering is cheap; only the *composer affordance + dialog* wait for Task 6). Decision: render offer messages as gold blocks NOW (data may already contain them), but the "Make an offer" composer button + dialog land in Task 6.

- [ ] **Step 1: Write the failing unit tests** (append to `test/data_test.dart`; import `package:um_marketplace/home/relative_time.dart`)

```dart
  test('formatRelativeTime covers the buckets', () {
    final now = DateTime(2026, 8, 28, 12);
    expect(formatRelativeTime(DateTime(2026, 8, 28, 11, 59, 30), now: now),
        'now');
    expect(formatRelativeTime(DateTime(2026, 8, 28, 11, 58), now: now), '2m');
    expect(formatRelativeTime(DateTime(2026, 8, 28, 9), now: now), '3h');
    expect(formatRelativeTime(DateTime(2026, 8, 27, 10), now: now),
        'yesterday');
    expect(formatRelativeTime(DateTime(2026, 8, 1), now: now), 'Aug 1');
    expect(formatRelativeTime(DateTime(2024, 12, 25), now: now),
        '25 Dec 2024');
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/data_test.dart`
Expected: FAIL — function undefined.

- [ ] **Step 3: Implement `lib/home/relative_time.dart`**

```dart
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Compact relative timestamp for the conversation list: 'now', '2m',
/// '3h', 'yesterday', 'Aug 12', '12 Aug 2024'.
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 2) return 'yesterday';
  if (time.year == ref.year) return '${_months[time.month - 1]} ${time.day}';
  return '${time.day} ${_months[time.month - 1]} ${time.year}';
}
```

- [ ] **Step 4: Write the failing thread widget tests** (append to `test/widget_test.dart`; add `import 'package:um_marketplace/chats/chat_thread_screen.dart';` and `import 'package:um_marketplace/home/relative_time.dart';` at the top)

```dart
  Chat _sampleChat({String listingId = 'l1', String buyerId = 'buyer-1'}) =>
      Chat(
        id: chatIdFor(listingId, buyerId),
        listingId: listingId,
        sellerId: 'seller-1',
        buyerId: buyerId,
        participants: {'seller-1', buyerId},
        lastMessagePreview: 'Hi',
        lastMessageAt: DateTime(2026, 8, 28, 12),
      );

  Widget _threadApp(FakeChatStore chats, FakeListingsStore listings,
      FakeMemberStore members,
      {Chat? chat,
      String viewerUid = 'buyer-1'}) {
    return MaterialApp(
      theme: buildUmTheme(),
      home: ChatThreadScreen(
        chat: chat ?? _sampleChat(),
        viewerUid: viewerUid,
        chatStore: chats,
        memberStore: members,
        listingsStore: listings,
      ),
    );
  }
```

  (`buildUmTheme` — add `import 'package:um_marketplace/theme/app_theme.dart';`.)

```dart
  testWidgets('thread renders the pinned listing and messages',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Analytical Geometry notes',
      description: '',
      price: 180,
      category: 'textbooks',
      condition: 'good',
    );
    chats.messages['l1_buyer-1'] = [
      const ChatMessage(
          id: 'm1', senderId: 'seller-1', type: 'text', text: 'Hi there!'),
      const ChatMessage(
          id: 'm2', senderId: 'buyer-1', type: 'text', text: 'Still available?'),
    ];
    await tester.pumpWidget(
        _threadApp(chats, listings, members, chat: _sampleChat()));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    chats.emitMessages('l1_buyer-1');
    await tester.pumpAndSettle();

    expect(find.text('Analytical Geometry notes'), findsOneWidget); // snippet
    expect(find.text('₱180'), findsOneWidget);
    expect(find.text('Hi there!'), findsOneWidget);
    expect(find.text('Still available?'), findsOneWidget);
  });

  testWidgets('thread composer sends a text message', (WidgetTester tester) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
    );
    await tester.pumpWidget(_threadApp(chats, listings, members));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Tara, swap meet?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Tara, swap meet?'), findsOneWidget);
    expect(chats.messages['l1_buyer-1'], hasLength(1));
    expect(chats.messages['l1_buyer-1']!.single.senderId, 'buyer-1');
    expect(chats.chats['l1_buyer-1']!.lastMessagePreview, 'Tara, swap meet?');
  });

  testWidgets('a sold listing shows the banner and disables the composer',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
      status: 'sold',
    );
    await tester.pumpWidget(_threadApp(chats, listings, members));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    expect(find.text('This listing is no longer active'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.send));
    expect(chats.messages['l1_buyer-1'] ?? const [], isEmpty);
  });

  testWidgets('a blocked send surfaces a snackbar and keeps the thread open',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore()..failSend = true;
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
    );
    await tester.pumpWidget(_threadApp(chats, listings, members));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hello?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text("You can't message this member right now"), findsOneWidget);

    // Let the snackbar timer expire before the test ends.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
```

- [ ] **Step 5: Run to verify they fail**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `ChatThreadScreen` undefined (compile error).

- [ ] **Step 6: Implement `lib/chats/chat_thread_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../home/money_format.dart';
import '../theme/app_theme.dart';
import '../widgets/nbr_button.dart';
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

  @override
  Widget build(BuildContext context) {
    final otherUid =
        chat.participants.firstWhere((uid) => uid != viewerUid);
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
                      Expanded(child: _MessageList(chat: chat, chatStore: chatStore)),
                      _Composer(
                        enabled: active,
                        onSend: (text) {
                          if (text.trim().isNotEmpty) _send(context, text.trim());
                        },
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
            icon: const Icon(Icons.arrow_back, size: 24, color: UmColors.onPrimary),
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
    return GestureDetector(
      onTap: listing.status == 'active'
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ListingDetailScreen(
                listing: listing,
                memberStore: memberStore,
                listingsStore: listingsStore,
                chatStore: chatStore,
                viewerId: viewerUid,
              ),
            ))
          : null,
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
                    : Image.memory(listing.photos.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const PhotoPlaceholder()),
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
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: UmColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
```

  (Do not reference `ListingDetailScreen` until Task 7 — if it is not yet updated with `chatStore`, `_PinnedListing`'s push would not compile. **Task ordering fix:** the pinned-card push to the detail screen is deferred — Task 5's `_PinnedListing` has NO onTap; the tap-to-detail behavior is added in Task 7 when the detail screen gains `chatStore`.)

```dart
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
```

The `_MessageList` call site inside the listing `StreamBuilder` becomes
`_MessageList(chat: chat, chatStore: chatStore, viewerUid: viewerUid)`.

```dart
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
```

  (Contrast per DESIGN.md §2 is handled in `_MessageBubble` above: maroon carries white, white carries `onSurface`, gold carries black ink.)

```dart
class _Composer extends StatefulWidget {
  const _Composer({required this.enabled, required this.onSend});

  final bool enabled;
  final ValueChanged<String> onSend;

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
                        : UmColors.muted),
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
                  borderSide:
                      const BorderSide(color: UmColors.mutedForeground, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(enabled: widget.enabled, onPressed: () => _submit(_controller.text)),
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
              color: enabled ? UmColors.ink : UmColors.mutedForeground, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                      color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
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
```

  The test taps `find.byIcon(Icons.send)` — the icon exists even when disabled (tap does nothing; good, the sold test relies on the disabled tap being a no-op). The `TextField` in a sold thread is disabled but still present — `enterText` on a disabled field throws; the sold test does not enter text ✓. For the sold test's `tap` on send: GestureDetector with null onTap swallows ✓.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/data_test.dart test/widget_test.dart`
Expected: PASS (all old + new).

- [ ] **Step 8: Analyze + commit**

```bash
flutter analyze   # No issues found
git add lib/home/relative_time.dart lib/chats/chat_thread_screen.dart test/data_test.dart test/widget_test.dart
git commit -m "feat(chat): thread screen with pinned snippet, bubbles, composer
- Reversed message list, text + offer rendering (gold carries ink), sold-listing banner + disabled composer, blocked-send snackbar, relative time helper"
```

---

### Task 6: Offer dialog, thread offers, and failure snackbars

**Files:**
- Create: `lib/widgets/offer_price_dialog.dart`
- Modify: `lib/chats/chat_thread_screen.dart` (buyer offer affordance; `_Composer` gains the gold button; wire `showOfferPriceDialog` → `sendOffer`)
- Modify: `test/widget_test.dart`

**Interfaces:**
- Produces: `Future<double?> showOfferPriceDialog(BuildContext context)` in `lib/widgets/offer_price_dialog.dart` — shows the neubrutalist dialog (title 'Make an offer', whole-peso `TextField`, validation error under the field, `Cancel` + `Send offer` NbrButtons); pops with the parsed `double`, or `null` on cancel.
- Consumes: `ChatStore.sendOffer`, `ChatSendException`, `chat.buyerId` for the buyer-only affordance.

- [ ] **Step 1: Write the failing widget tests**

Append to `test/widget_test.dart`:

```dart
  testWidgets('buyer sees the offer affordance and sends a priced offer',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
    );
    await tester.pumpWidget(_threadApp(chats, listings, members));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.currency_peso));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '40');
    await tester.tap(find.text('Send offer'));
    await tester.pumpAndSettle();

    expect(chats.messages['l1_buyer-1'], hasLength(1));
    final offer = chats.messages['l1_buyer-1']!.single;
    expect(offer.type, 'offer');
    expect(offer.price, 40.0);
    expect(find.text('₱40'), findsOneWidget); // rendered offer block
  });

  testWidgets('offer dialog rejects zero and bad input',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    await tester.pumpWidget(_threadApp(chats, listings, members));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.currency_peso));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send offer'));
    await tester.pump();
    expect(find.text('Enter a price above zero.'), findsOneWidget);
    expect(chats.messages['l1_buyer-1'] ?? const [], isEmpty);

    await tester.enterText(find.byType(TextField).last, 'potato');
    await tester.tap(find.text('Send offer'));
    await tester.pump();
    expect(find.text('Enter a price above zero.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '25.5');
    await tester.tap(find.text('Send offer'));
    await tester.pump();
    expect(find.text('Use whole pesos only.'), findsOneWidget);
  });

  testWidgets('the seller has no offer affordance', (WidgetTester tester) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
    );
    await tester.pumpWidget(
        _threadApp(chats, listings, members, viewerUid: 'seller-1'));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.currency_peso), findsNothing);
  });
```

  (`_threadApp` already accepts `viewerUid`; note the sold-thread test in Task 5 asserts a disabled send — unchanged.)

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `Icons.currency_peso` not found (no affordance yet).

- [ ] **Step 3: Implement the dialog**

Create `lib/widgets/offer_price_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'nbr_button.dart';

/// Neubrutalist offer dialog (DESIGN.md screen 3/6): whole pesos only,
/// validation inline. Pops with the offered price, or null on cancel.
Future<double?> showOfferPriceDialog(BuildContext context) {
  return showDialog<double>(
    context: context,
    builder: (_) => const _OfferPriceDialog(),
  );
}

class _OfferPriceDialog extends StatefulWidget {
  const _OfferPriceDialog();

  @override
  State<_OfferPriceDialog> createState() => _OfferPriceDialogState();
}

class _OfferPriceDialogState extends State<_OfferPriceDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    final price = double.tryParse(raw);
    String? problem;
    if (price == null || price <= 0) {
      problem = 'Enter a price above zero.';
    } else if (price != price.roundToDouble()) {
      problem = 'Use whole pesos only.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(price!.roundToDouble());
  }

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
              'Make an offer',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: UmColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your offer lands on the thread as an offer message. No money moves in the app (ADR 0002).',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: UmColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'e.g. 250',
                errorText: _error,
                filled: true,
                fillColor: UmColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _error == null ? UmColors.ink : UmColors.destructive,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _error == null ? UmColors.ink : UmColors.destructive,
                    width: 2,
                  ),
                ),
              ),
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
                    label: 'Send offer',
                    fill: UmColors.gold,
                    labelColor: UmColors.ink,
                    stretch: true,
                    onPressed: _submit,
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
```

  (First `tap(find.text('Send offer'))` with an empty field: `_error` set, no pop ✓.)

- [ ] **Step 4: Wire the offer affordance into the thread**

In `lib/chats/chat_thread_screen.dart`:
- `ChatThreadScreen` gains a `_sendOffer(BuildContext context, double price) async` mirroring `_send` (try `chatStore.sendOffer(chat, senderId: viewerUid, price: price)`; `ChatSendException` → snackbar `"You can't message this member right now"`; generic → `'Couldn't send — try again.'`).
- The `_Composer` call site gains an optional `onOffer` (only when `viewerUid == chat.buyerId`):
  `_Composer(enabled: active, onSend: ..., onOffer: viewerUid == chat.buyerId ? () async { final price = await showOfferPriceDialog(context); if (price != null) _sendOffer(context, price); } : null)`
- `_Composer` (stateful) gains `final VoidCallback? onOffer;` and, when non-null and enabled, a gold button between the field and the send button:

```dart
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
                          blurRadius: 0),
                    ],
                  ),
                  child: const Icon(Icons.currency_peso,
                      size: 24, color: UmColors.ink),
                ),
              ),
            ),
```

  Import `../widgets/offer_price_dialog.dart` in the thread screen.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/widget_test.dart`
Expected: PASS. The `testWidgets('thread composer sends a text message')` test still passes — the composer gained a button but `find.byType(TextField)` still matches exactly one field, and `Icons.send` still unique.

- [ ] **Step 6: Analyze + commit**

```bash
flutter analyze   # No issues found
git add lib/widgets/offer_price_dialog.dart lib/chats/chat_thread_screen.dart test/widget_test.dart
git commit -m "feat(chat): offer dialog and buyer-side offer sending
- Neubrutalist whole-peso offer dialog; buyer-only gold affordance; offers land as offer blocks on the thread"
```

---

### Task 7: Chats list screen + navigation from detail

**Files:**
- Create: `lib/chats/chats_screen.dart`
- Delete: `lib/home/chats_placeholder.dart`
- Modify: `lib/home/app_shell.dart` (real `ChatsScreen`, wire `chatStore` + member/listings stores)
- Modify: `lib/home/listing_detail_screen.dart` (gains `chatStore`; real Chat open + Make-an-offer flow; remove the coming-soon snackbar; `_PinnedListing`'s tap-to-detail now compiles — add it here)
- Modify: `test/widget_test.dart` (remove the old coming-soon test; add navigation tests)

**Interfaces:**
- Consumes: `ChatStore`, `MemberStore`, `ListingStore`, `ChatThreadScreen` (Task 5), `showOfferPriceDialog` (Task 6), `formatRelativeTime` (Task 5), `ChatOpenException`.
- Produces: `class ChatsScreen extends StatelessWidget { const ChatsScreen({required this.viewerUid, required this.chatStore, required this.memberStore, required this.listingsStore}); }`
- `ListingDetailScreen` gains `{required this.chatStore}` (`ChatStore`) and pushes the thread after open/offer; its `_comingSoon` is deleted.

- [ ] **Step 1: Write the failing widget tests**

```dart
  // Replace the OLD test 'chat and offer actions are inert with a
  // coming-soon note' (delete it) with:

  testWidgets('Chats tab lists conversations with names, previews, and times',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(_app(
      auth: auth, members: members, listings: listings, chats: chats));
    auth.emit(_student);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();

    chats.chats['l1_seller-1'] = _sampleChat();
    chats.emitList();
    await tester.pumpAndSettle();

    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('J. Dela Cruz'), findsOneWidget); // other member name
  });
```

  Note the row needs the OTHER participant's member doc: emit it before settling (`members.emit(Member(uid: 'seller-1', email: 'j.delacruz.000000@umindanao.edu.ph', displayName: 'J. Dela Cruz'))` — emit BEFORE `chats.emitList()` so the row subscribes first; both orders are safe because per-row `StreamBuilder` subscribes at first build and `members.emit` then `await tester.pump()` delivers).

```dart
  testWidgets('empty chats show the empty state', (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(_app(
      auth: auth, members: members, listings: listings, chats: chats));
    auth.emit(_student);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();

    chats.emitList(); // empty list
    await tester.pumpAndSettle();
    expect(find.textContaining('No conversations yet'), findsOneWidget);
  });

  testWidgets('tapping a chat row opens the thread', (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(_app(
      auth: auth, members: members, listings: listings, chats: chats));
    auth.emit(_student);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();

    final chat = _sampleChat();
    chats.chats[chat.id] = chat;
    chats.emitList();
    members.emit(const Member(
      uid: 'seller-1',
      email: 'j.delacruz.000000@umindanao.edu.ph',
      displayName: 'J. Dela Cruz',
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('J. Dela Cruz'));
    await tester.pumpAndSettle();
    expect(find.text('Say hi — or send an offer.'), findsOneWidget); // thread
  });

  testWidgets('detail Chat opens the thread; offer sends an offer message',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    listings.listings = [
      const Listing(
        id: 'l1',
        sellerId: 'seller-1',
        title: 'Dorm lamp',
        description: 'USB powered.',
        price: 300,
        category: 'dorm essentials',
        condition: 'like new',
      ),
    ];
    await tester.pumpWidget(_app(
      auth: auth, members: members, listings: listings, chats: chats));
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    // Thread open (chat created via the fake).
    expect(chats.chats.containsKey('l1_test-uid'), isTrue);
    expect(find.text('Say hi — or send an offer.'), findsOneWidget);

    // Back to detail, then make an offer.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make an offer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '250');
    await tester.tap(find.text('Send offer'));
    await tester.pumpAndSettle();

    expect(chats.messages['l1_test-uid'], hasLength(1));
    expect(chats.messages['l1_test-uid']!.single.type, 'offer');
    expect(chats.messages['l1_test-uid']!.single.price, 250.0);
    expect(find.text('OFFER'), findsOneWidget); // landed in the thread
  });

  testWidgets('opening a chat against a blocked pair shows a snackbar',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore()..failOpen = true;
    listings.listings = [
      const Listing(
        id: 'l1',
        sellerId: 'seller-1',
        title: 'Dorm lamp',
        description: '',
        price: 300,
        category: 'dorm essentials',
        condition: 'like new',
      ),
    ];
    await tester.pumpWidget(_app(
      auth: auth, members: members, listings: listings, chats: chats));
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.text("You can't start a chat with this member right now"),
        findsOneWidget);
    // still on the detail screen
    expect(find.text('Make an offer'), findsOneWidget);

    // Let the snackbar timer expire.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('opening a chat on a sold listing explains the listing is gone',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore()
      ..failOpen = true
      ..openFailure = ChatOpenFailure.listingInactive;
    listings.listings = [
      const Listing(
        id: 'l1',
        sellerId: 'seller-1',
        title: 'Dorm lamp',
        description: '',
        price: 300,
        category: 'dorm essentials',
        condition: 'like new',
        status: 'sold',
      ),
    ];
    await tester.pumpWidget(_app(
      auth: auth, members: members, listings: listings, chats: chats));
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.text('This listing is no longer available'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
```

  The OLD coming-soon test is deleted; the OLD detail tests that assert 'Chats are coming soon' no longer exist. Keep 'viewing your own listing hides the chat/offer bar' unchanged.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `ChatsScreen` undefined / old coming-soon behavior gone (compile + runtime failures).

- [ ] **Step 3: Implement `lib/chats/chats_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
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
  });

  final String viewerUid;
  final ChatStore chatStore;
  final MemberStore memberStore;
  final ListingStore listingsStore;

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
                Text('Conversations',
                    style: Theme.of(context).textTheme.headlineMedium),
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
    final border = Border.all(color: UmColors.ink, width: 2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: UmColors.surface,
            border: border,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: UmColors.ink, offset: Offset(4, 4), blurRadius: 0),
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
        Text('Conversations', style: Theme.of(context).textTheme.headlineMedium),
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
        Text('Conversations', style: Theme.of(context).textTheme.headlineMedium),
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
              const Icon(Icons.forum_outlined,
                  size: 48, color: UmColors.mutedForeground),
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
```

- [ ] **Step 4: Update the shell**

In `lib/home/app_shell.dart` (inside `_AppShellState`): replace the `ChatPlaceholder` child with `ChatsScreen(viewerUid: widget.member.uid, chatStore: widget.chatStore, memberStore: widget.memberStore, listingsStore: widget.listingsStore)`; delete `lib/home/chats_placeholder.dart`; update imports.

- [ ] **Step 5: Rewire the detail screen (`lib/home/listing_detail_screen.dart`)**

- Constructor gains `required this.chatStore` (`ChatStore`); add field + import `../data/chat_store.dart`.
- Replace `_comingSoon` with:

```dart
  Future<void> _openChat(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final Chat chat;
    try {
      chat = await chatStore.openChatWithBuyer(
        listing: listing,
        buyerUid: viewerId,
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
        ..showSnackBar(
            const SnackBar(content: Text('Couldn\'t start the chat — try again.')));
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
      ),
    ));
  }

  Future<void> _makeOffer(BuildContext context) async {
    final price = await showOfferPriceDialog(context);
    if (price == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final Chat chat;
    try {
      chat = await chatStore.openChatWithBuyer(
        listing: listing,
        buyerUid: viewerId,
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
        ..showSnackBar(
            const SnackBar(content: Text('Couldn\'t start the chat — try again.')));
      return;
    }
    try {
      await chatStore.sendOffer(chat, senderId: viewerId, price: price);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Couldn\'t send the offer — try again.')));
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
      ),
    ));
  }
```

  - The owner bar and `_ActionBar` calls become `onChat: () => _openChat(context), onOffer: () => _makeOffer(context)`.
- Import `../chats/chat_thread_screen.dart` and `../widgets/offer_price_dialog.dart`; drop the old snackbar text.
- Also update `_HomeScreen`'s call site of `ListingDetailScreen` (in `lib/home/home_screen.dart`) to pass `chatStore: widget.chatStore` (the field added in Task 3).
- AND add the pinned-snippet tap in the thread (Task 5 deferred): in `lib/chats/chat_thread_screen.dart` `_PinnedListing`, enable `onTap` to push `ListingDetailScreen(listing: listing, memberStore: memberStore, listingsStore: listingsStore, chatStore: chatStore, viewerId: viewerUid)` (import `../home/listing_detail_screen.dart`).

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/widget_test.dart`
Expected: PASS — new navigation tests, all prior detail tests (own-listing bar, sold sticker, etc.), and the full suite.

- [ ] **Step 7: Analyze + commit**

```bash
flutter analyze   # No issues found
git add lib/chats/chats_screen.dart lib/home/app_shell.dart lib/home/listing_detail_screen.dart lib/home/home_screen.dart lib/chats/chat_thread_screen.dart test/widget_test.dart
git rm lib/home/chats_placeholder.dart
git commit -m "feat(chat): conversation list, detail Chat/Offer actions live
- ChatsScreen with member rows, previews, relative times, empty/skeleton states; detail Chat opens the thread, Make an offer dialogs + sends an offer then opens the thread; blocked/sold opens map to snackbars; pinned snippet taps to the listing detail"
```

---

### Task 8: Indexes + ADR 0009

**Files:**
- Modify: `firestore.indexes.json`
- Create: `docs/adr/0009-deterministic-chat-ids.md`

**Interfaces:** none (infra/docs).

- [ ] **Step 1: Add the two chats composite indexes**

In `firestore.indexes.json`, append inside the `"indexes"` array (after the notifications entry):

```json
    {
      "collectionGroup": "chats",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "buyerId", "order": "ASCENDING" },
        { "fieldPath": "lastMessageAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "chats",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "sellerId", "order": "ASCENDING" },
        { "fieldPath": "lastMessageAt", "order": "DESCENDING" }
      ]
    }
```

Verify: `python -c "import json; json.load(open('firestore.indexes.json', encoding='utf-8'))"` (or `Get-Content firestore.indexes.json | ConvertFrom-Json` on Windows) — must parse.

- [ ] **Step 2: Write ADR 0009**

Create `docs/adr/0009-deterministic-chat-ids.md` (match the format of the existing ADRs — title line, context, decision, consequences):

```markdown
# 0009: Deterministic chat ids

**Status:** Accepted

## Context

A Chat is born only from a Listing and pairs its seller with exactly one buyer (`chats/{id}`, ADR 0007); the create rule requires `buyerId == request.auth.uid`, so chat creation is buyer-initiated and the buyer + listing fix the chat's identity. The app needs find-or-create semantics from the Listing's detail screen — re-tapping Chat must reopen the same thread, never duplicate it.

## Decision

The chat document id is deterministic: `{listingId}_{buyerId}`. Opening a chat is a direct `get` of `chats/{listingId}_{buyerId}` followed by a create only when the document does not exist, so find-or-create is idempotent with no race and no listingId+buyerId lookup query (and no index for it).

The conversation list ("my chats") deliberately avoids `participants.<uid>` map-key equality: Firestore cannot index map keys generically — the required composite index hard-codes the concrete key, which would mean one index per user. Instead the list runs two plain-field equality queries (`buyerId == uid`, `sellerId == uid`, each ordered by `lastMessageAt`) and merges them client-side; a chat belongs to exactly one side because the create rule forbids `buyerId == sellerId`.

## Consequences

- Duplicate chats are structurally impossible; the id is safe to embed in URLs/deep links later.
- The seller's uid is visible in chat document ids (buyer ids already are, by rule) — no PII is exposed beyond what the rules already publish.
- Reversing this is expensive: migrating chat ids means rewriting document ids and their message subcollection paths, so any future change must keep a migration story.
- The deterministic-id property is what makes the two-query list correct (a chat appears under exactly one of buyerId/sellerId).
```

- [ ] **Step 3: Verify + commit**

```bash
flutter analyze   # No issues found (nothing Dart changed)
flutter test      # full suite green
git add firestore.indexes.json docs/adr/0009-deterministic-chat-ids.md
git commit -m "chore(chat): composite indexes for the conversation list + ADR 0009
- buyerId/sellerId + lastMessageAt composites; ADR records the deterministic chat id and the two-query list (map-key equality is not generically indexable)"
```

---

## Self-Review Notes

Resolved during planning (no open items):
- Thread offers: rendering offer blocks ships in Task 5 (data may already contain offers), the buyer-side affordance + dialog in Task 6.
- The pinned snippet's tap-to-detail moves to Task 7 (it needs the detail screen's `chatStore` from that task).
- The fake's message bookkeeping mirrors the batch write (message + chat-doc preview/timestamp, then emit).
- Existing sell-flow test still passes: the CTA switches tabs and `onPublished` returns to Home; 'Recent listings' re-appears.
- `usePortraitPhone` lives inside `main()` in `test/widget_test.dart` — new tests that need it must be declared inside `main()` too (it is a local function).