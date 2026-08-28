# Chats + Offers — Design Spec

- **Date:** 2026-08-28
- **Status:** approved (design review), pending user spec review
- **Stage:** DESIGN.md §6 screen 6 (Chats) + reactivation of the detail-screen action bar, plus the v1 bottom navigation shell (DESIGN.md §5)
- **Depends on:** ADR 0002 (no in-app payments), ADR 0007 (data model — `chats/{id}` + `chats/{id}/messages/{msgId}`), ADR 0003 (blocked pairs, moderation), drafted `firestore.rules` chat section (already complete — no rules changes needed)

## 1. Scope

**In scope**

- New `ChatStore` data layer over the drafted chat rules (find-or-create chat, message streams, text + offer sends, atomic bookkeeping).
- Bottom navigation shell with three tabs — Home, Sell, Chats — per DESIGN.md §5 (Profile tab lands with the Profile stage).
- Chats list screen (DESIGN.md screen 6, first half): rows with other participant, last-message preview, relative time.
- Chat thread screen (DESIGN.md screen 6, second half): pinned product snippet card, message list, composer, offer-typed messages with a price, sold/hidden-listing banner.
- Detail-screen rewire: "Chat" and "Make an offer" become real actions (the "Chats are coming soon" stub disappears).
- New composite Firestore index; `ListingStore` gains a live single-listing stream.
- ADR 0009 documenting the deterministic chat-id scheme (surprising and hard to reverse — AGENTS.md ADR criteria).
- Tests: data round-trips + widget scenarios via fakes (no Firebase in tests).

**Out of scope (deferred deliberately)**

- Unread markers on the conversation list (per design decision — they land with the Notification center stage, ADR 0005).
- Rating prompt in the thread after a Listing flips to Sold (ADR 0004 stretch, per DESIGN.md screen 6).
- Chat media, message editing/deletion, typing indicators.
- Push notifications for new messages (ADR 0005 — a later stage).
- Block/Report/Moderation UI (ADR 0003 — later stages).

## 2. Data layer — `lib/data/chat_store.dart`

### 2.1 Chat identity: deterministic ids

A chat is born only from a Listing and pairs its seller with **one** buyer (ADR 0007; rule: `buyerId == request.auth.uid` at create). To guarantee exactly one chat per (listing, buyer) pair with no duplicate-creation races, the chat **document id is deterministic**: `'{listingId}_{buyerId}'`.

- Lookup is a direct doc read (`chats/{listingId}_{buyerId}`) — no query, no extra index.
- Find-or-create is get-then-set; the create path satisfies the drafted create rule (buyerId == auth.uid, participants map of exactly the two uids, both `true`, listing active, not a blocked pair).
- Idempotent: re-tapping Chat on the same Listing reopens the same chat.
- Documented in ADR 0009.

### 2.2 Models

```dart
class Chat {
  final String id;             // '{listingId}_{buyerId}'
  final String listingId;
  final String sellerId;
  final String buyerId;
  final Set<String> participants; // exactly {sellerId, buyerId}
  final String lastMessagePreview; // '…' text truncated to 60 chars, or 'Offer: ₱250'
  final DateTime? lastMessageAt;
}

class ChatMessage {
  final String id;
  final String senderId;
  final String type;        // 'text' | 'offer'  (rules reject anything else)
  final String text;
  final double? price;      // offer messages only, > 0 (rule)
  final DateTime? createdAt;
}
```

Both have `fromDoc(id, data)` factories mirroring the rule-validated shape. Fields are exactly those the rules enforce so writes from the app and reads from the rules agree (participants map equality on every message — rule line 201).

### 2.3 `ChatStore` interface (injected, fake-able)

```dart
abstract interface class ChatStore {
  /// My conversations, most recent activity first (limit 50).
  Stream<List<Chat>> myChatsStream(String uid);

  /// All messages of a chat, oldest first (realtime).
  Stream<List<ChatMessage>> chatMessagesStream(String chatId);

  /// Find-or-create (deterministic id). Returns the chat; surfaces rule
  /// failures (blocked pair, inactive listing) as typed errors the UI maps.
  Future<Chat> openChatWithBuyer({required Listing listing, required String buyerUid});

  /// Sends a text message; atomic with chat-doc bookkeeping. Takes the
  /// loaded [Chat] so the participants map in the message write is copied
  /// exactly from the chat doc (rule line 201) with no extra read.
  Future<void> sendText(Chat chat, {required String text});

  /// Sends an offer-typed message with a price; atomic with bookkeeping.
  Future<void> sendOffer(Chat chat, {required double price, String text = ''});
}
```

### 2.4 Firestore implementation details

- `openChatWithBuyer`: read `chats/{listingId}_{buyerId}`; if missing, set a doc shaped per the create rule (sellerId, buyerId, listingId from the Listing; participants map; `lastMessagePreview: ''`; `createdAt`/`updatedAt` server timestamps).
- **Error mapping (deterministic):** on a `PermissionDeniedException` from the create, read `listings/{listingId}` once — if its status is not `active` the UI shows *"This listing is no longer available"*; otherwise *"You can't start a chat with this member right now"* (blocked pair or rule rejection). No navigation happens in either case.
- Sending a message is a **`WriteBatch`**: (1) create the message doc under `chats/{chatId}/messages/` with `senderId == auth.uid`, `type`, `text`, `price` (offer only), and the **participants map copied exactly from the passed `Chat`** (rule line 201); (2) update the chat doc with `lastMessageAt = serverTimestamp()` and `lastMessagePreview` (text truncated to 60 chars; offer formatted `Offer: ₱250`). Batch = both-or-neither.
- **`myChatsStream` — two-query merge (no map-key index).** A `where('participants.<uid>', …)` query would need one composite index per concrete uid — Firestore has no wildcard for map keys (index suggestions hard-code the literal key, e.g. `participants.83239…`). Instead each chat doc's plain fields already carry the role split, so run two live queries and merge:
  1. `collection('chats').where('buyerId', isEqualTo: uid).orderBy('lastMessageAt', descending: true).limit(50)`
  2. `collection('chats').where('sellerId', isEqualTo: uid).orderBy('lastMessageAt', descending: true).limit(50)`
  A chat can never match both (buyerId ≠ sellerId per the create rule), so the merged result is a straight concat re-sorted by `lastMessageAt` descending, capped at 50. Merge re-runs whenever either query emits.
- `chatMessagesStream`: `collection('chats').doc(chatId).collection('messages').orderBy('createdAt', ascending: true).snapshots()`.

### 2.5 Indexes — `firestore.indexes.json`

Add two plain-field composites (no map-key fields; map-key equality would require one index per concrete uid):

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

No field overrides. No rules changes.

### 2.6 `ListingStore` extension

`ListingStore` gains `Stream<Listing?> listingChanges(String id)` (get-then-listen on `listings/{id}`), so the thread can watch status (sold/hidden → banner + disabled composer) and render the pinned snippet. All existing fakes gain an implementation.

## 3. App shell & navigation — `lib/home/app_shell.dart`

- `MemberGate` hands off to `AppShell(member, memberStore, listingsStore, chatStore, onSignOut)` instead of `HomeScreen`.
- Constructor threading: `UmMarketplaceApp` gains a `chatStore` parameter, passed `AuthGate → MemberGate → AppShell` (alongside the existing stores), and from there to `HomeScreen → ListingDetailScreen` and `ChatsScreen → ChatThreadScreen`.
- `AppShell` = `SafeArea` > `Column`:
  1. **Maroon brand band** — the existing `UM MARKETPLACE` header moves out of `HomeScreen` into the shell so it is consistent across tabs (the notification bell lands here later, ADR 0005).
  2. **`Expanded(IndexedStack(...))`** — Home, Sell, Chats tab bodies; IndexedStack preserves the Sell draft and scroll positions when switching tabs.
  3. **Bottom nav bar** (DESIGN.md §5): white fill, 2 dp ink top border, three items — Home (`Icons.home_outlined`), Sell (`Icons.add_box_outlined`), Chats (`Icons.chat_bubble_outline`); active = maroon icon+label on a `goldSoft` pill; inactive `mutedForeground`; 24 dp outlined icons; ≥ 48 dp touch targets. Profile tab is added when the Profile stage lands.
- `HomeScreen` loses its own maroon header (shell owns it); its "Sell something" CTA **switches to the Sell tab** instead of pushing a route. Sign-out stays in the Home member card.
- `SellScreen` internals stay as-is, hosted as tab content (its own Scaffold nests fine).
- Threads are pushed routes (full-screen), not tabs.

## 4. Chats list — `lib/chats/chats_screen.dart`

- Header: the shell's maroon brand band serves as the screen header (consistent with Home); the body starts with a `Conversations` section title, mirroring Home's `Recent listings`.
- `StreamBuilder` on `myChatsStream(viewerUid)`; three states: loading skeleton (static muted blocks, matching the feed skeleton), empty state (outline icon in an ink-bordered square + "No conversations yet — tap Chat on a listing to start one"), and rows.
- Row (ink border, 4 dp hard shadow, 8 dp radius, mechanical press on tap): other participant's gold-initial avatar + display name (per-row `MemberStore.memberChanges` lookup), `lastMessagePreview` below, `relative_time` top-right. No listing thumbnail, no unread sticker (deferred).
- Row tap → push `ChatThreadScreen`.
- `relative_time` helper (`lib/home/relative_time.dart`, mirroring `money_format.dart`): `2m`, `3h`, `yesterday`, `Aug 12`, `12 Aug 2024`.

## 5. Chat thread — `lib/chats/chat_thread_screen.dart`

Pushed route (its own `Scaffold` with `SafeArea` — it sits above the shell) with `(chat, viewerUid, chatStore, memberStore, listingsStore)`.

- **Pinned product snippet card** (top, ink-bordered): listing photo (or placeholder), title, price; tappable → listing detail while the listing is active. From `listingChanges(listingId)`.
- **Message list**: reversed `ListView` (newest at bottom), auto-scroll to the latest on arrival. Bubbles: own = maroon fill/white text right-aligned; theirs = white fill/ink border left-aligned; 8 dp radius, hard 2–3 dp shadows. **Offer** messages render as a gold-fill (`UmColors.gold`) block carrying black ink with an "OFFER" sticker and `₱250` — never white text on gold (DESIGN.md §2). Sender avatars are not needed inside the thread (two-party).
- **Composer** (bottom, above safe area): ink-bordered `TextField` + send button (mechanical press). Buyer additionally gets a gold **Make an offer** affordance → dialog with a whole-peso price field (`> 0`, error text per §5 inputs) → `sendOffer` → the offer lands on the thread.
- **Sold/hidden listing** (status ≠ `active`): maroon-bordered banner *"This listing is no longer active"* + composer disabled (the message rule already refuses writes; the banner makes the refusal visible). The thread itself remains readable.
- **Send failures**: `sendText`/`sendOffer` are fire-and-forget from the UI with a snackbar on error (blocked pair → "You can't message this member right now"; other permission errors → generic retry message). No retry loop in v1.

## 6. Detail-screen rewire — `lib/home/listing_detail_screen.dart`

- Gains `chatStore` (threaded: `MemberGate → AppShell → HomeScreen → ListingDetailScreen`).
- **Chat** → `openChatWithBuyer` → push `ChatThreadScreen`.
- **Make an offer** → price dialog (share the same dialog widget as the thread) → `openChatWithBuyer` + `sendOffer` → push `ChatThreadScreen`.
- Errors from open (blocked pair, listing no longer active) → snackbar, no navigation.
- The "Chats are coming soon" stub and its test are removed. The own-listing "This is your listing" bar is unchanged.

## 7. Testing

New fakes alongside the existing ones in `test/widget_test.dart`:

- `FakeChatStore`: in-memory maps of chats/messages; `openChatWithBuyer` honors the deterministic-id rule; failure injection (`failOpens`, `failSends`) for blocked/inactive cases. `FakeListingsStore` gains `listingChanges`; `FakeMemberStore` already resolves arbitrary uids.

Scenarios:

1. Shell: bottom nav renders 3 tabs; switching tabs swaps bodies; "Sell something" CTA switches to the Sell tab; Sell draft survives a tab switch (IndexedStack).
2. Chats list: rows show other member's name + preview (`Offer: ₱250` for offers); empty state; skeleton state.
3. Thread: renders text messages and a gold offer block; pinned snippet shows photo/title/price; composer appends a text message; buyer offer dialog validates (`0` → error) and sends a priced offer.
4. Sold listing thread: banner shown, composer disabled, messages still readable.
5. Detail: Chat opens the thread (chat created via fake); Make an offer creates the chat + sends the offer + opens the thread; blocked-pair open shows a snackbar and stays on detail.
6. Data units: `Chat.fromDoc`/`ChatMessage.fromDoc` round-trips (incl. offer price); deterministic id = `{listingId}_{buyerId}`; preview truncation at 60 chars.
7. Chats list includes both buyer-side and seller-side conversations (merged two-query semantics) with the merged result sorted by `lastMessageAt` descending.
8. Regression: own-listing bar still hides actions; existing feed/sell/auth/banned tests keep passing.

Gate before commit: `flutter analyze` clean + full `flutter test` green.

## 8. Documentation

- **ADR 0009** — *Deterministic chat ids*: chat doc id is `{listingId}_{buyerId}`; rationale (one chat per listing–buyer pair enforced by the rules' buyerId == auth.uid shape; idempotent find-or-create; no listingId+buyerId lookup index needed) and reversibility cost (any migration must rewrite existing chat doc ids and their message paths). Also records the *two-query conversation list* decision: `participants.<uid>` map-key equality cannot be indexed generically (Firestore index suggestions hard-code the concrete key — one index per user), so the list merges `buyerId` and `sellerId` equality queries instead.
- This spec lives at `docs/superpowers/specs/2026-08-28-chats-offers-design.md`.

## 9. Open questions / flagged ambiguities

None — navigation entry point (3-tab bottom nav) and unread-marker deferral were resolved in the design session.