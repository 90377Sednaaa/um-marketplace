# Moderation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship DESIGN.md screen 9 — member-side Report actions, an Admin Moderation screen (open reports with hide-listing + ban-user, member lookup), and the ban → auto-hide flow — plus the two production-correctness fixes discovered while checking the rules: the Admin currently **cannot ban** (the members update rule is self-only with `banned` immutable) and shipped screens read other members' docs, which the members read rule denies (names must be denormalized).

**Architecture:** Store-interface pattern as everywhere. `ReportStore` for reports (the drafted `reports/{id}` create/read rules need no changes — only the members-update rule gains an admin ban branch). Display names move onto the documents that already flow across boundary: `sellerDisplayName` on listings, `buyerName`/`sellerName` on chats — both validated at create via `get()` against member docs, which keeps full UM emails private (members read stays self/Admin). `update()` semantics confirmed from official docs: `request.resource.data` is the merged future document, so equality checks in the existing update rules are sound; the admin ban branch uses `diff().affectedKeys().hasOnly(['banned'])`.

**Tech Stack:** Flutter/Dart, `cloud_firestore` (no new deps), existing neubrutalist tokens/components. Rules changes are server-side only (`firestore.rules`), no Firebase emulator in this repo — rule changes are verified by careful re-read + the full Dart suite staying green.

**Spec:** Design approved 2026-08-28 (chat); data contract per `firestore.rules` (members/listings/chats/reports blocks), CONTEXT.md (Report/Block/Ban/Admin), ADR 0003.

## Global Constraints

- **TDD:** failing test first, watch it fail, implement, verify green; every commit keeps `flutter analyze` clean + the full suite green.
- **Commit per task**, push after all tasks (AGENTS.md).
- **No new pub dependencies.**
- **Broadcast-stream convention:** settle, then emit; snackbar tests pump `Duration(seconds: 5)` + settle at the end.
- **`usePortraitPhone`** for tall screens (local helper inside `main()` in `test/widget_test.dart`).
- **Copy strings introduced here:** `Report listing` / `Report this chat`, `Reason (required)`, `Submit report`, `Report submitted — thanks for keeping the marketplace safe.`, `Moderation`, `Open reports`, `Find a member`, `Hide listing`, `Ban user`, `This member is now banned…` — keep them exact for the tests.
- Rules semantics: `request.resource.data` on updates = merged future doc; missing-field access errors, use `.get('field', default)` when a field may be absent.

---

### Task 1: Rules — admin ban, denormalized-name validation, reports index

**Files:**
- Modify: `firestore.rules`
- Modify: `firestore.indexes.json`

No Dart changes in this task; verification = JSON validity + full suite still green.

- [ ] **Step 1: Members update gains the admin ban branch**

In `firestore.rules`, replace the members update block:

```js
      // Self-only. Immutable: uid, email, isAdmin, banned. Mutable:
      // displayName, blocked (self-managed Block list), timestamps.
      // Admin (ADR 0003): may change ONLY the banned flag (ban/unban) —
      // diff().affectedKeys() is the supported way to say "only these
      // fields changed" against update() semantics.
      allow update: if signedIn()
        && ((request.auth.uid == uid
             && request.resource.data.uid == uid
             && request.resource.data.email == resource.data.email
             && request.resource.data.isAdmin == resource.data.isAdmin
             && request.resource.data.banned == resource.data.banned)
            || (isAdminEmail(request.auth.token.email)
                && request.resource.data.diff(resource.data)
                     .affectedKeys().hasOnly(['banned'])
                && request.resource.data.banned is bool));
```

- [ ] **Step 2: Listings create validates the denormalized seller name**

In `firestore.rules`, the listings create rule (after the `price > 0` line) gains:

```js
        && request.resource.data.sellerDisplayName is string
        && request.resource.data.sellerDisplayName
             == get(/databases/$(database)/documents/members/$(request.auth.uid))
                  .data.displayName;
```

- [ ] **Step 3: Chats create validates both participant names**

In `firestore.rules`, the chats create rule (after the `!isBlockedPair(...)` line) gains:

```js
        && request.resource.data.buyerName
             == get(/databases/$(database)/documents/members/$(request.auth.uid))
                  .data.displayName
        && request.resource.data.sellerName
             == get(/databases/$(database)/documents/members/$(request.resource.data.sellerId))
                  .data.displayName;
```

- [ ] **Step 4: Reports composite index**

In `firestore.indexes.json`, add inside `"indexes"`:

```json
    {
      "collectionGroup": "reports",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
```

- [ ] **Step 5: Verify + commit**

```bash
Get-Content firestore.indexes.json | ConvertFrom-Json | Out-Null   # JSON OK
flutter test    # full suite still green (rules are server-side; no Dart changed)
git add firestore.rules firestore.indexes.json
git commit -m "chore(mod): rules grant Admin ban, validate denormalized names
- members update gains an admin branch changing ONLY 'banned' (diff-based);
  listings create requires sellerDisplayName == member doc; chats create
  requires buyerName/sellerName == member docs; reports status+createdAt
  composite index"
```

---

### Task 2: Data layer — names, ReportStore, ban/hide/search + fakes

**Files:**
- Modify: `lib/data/listing_store.dart`, `lib/data/chat_store.dart`, `lib/data/member_store.dart`
- Create: `lib/data/report_store.dart`
- Modify: `lib/home/sell_screen.dart` (sellerDisplayName param), `lib/home/app_shell.dart` (passes it)
- Modify: `test/data_test.dart`, `test/widget_test.dart` (fakes)

**Interfaces:**
- Produces:
  - `Listing` gains `final String sellerDisplayName;` (fromDoc reads `data['sellerDisplayName'] ?? ''`); `ListingDraft` gains `required this.sellerDisplayName` + `'sellerDisplayName': sellerDisplayName` in `toData()`.
  - `Chat` gains `final String buyerName; final String sellerName;` (fromDoc defaults `''`). `FirestoreChatStore.openChatWithBuyer` gains `required String buyerDisplayName` and writes `'buyerName': buyerDisplayName, 'sellerName': listing.sellerDisplayName`.
  - `abstract interface class ReportStore { Stream<List<Report>> openReportsStream(); Future<void> submitReport({required String reporterId, required String reason, String? reportedUid, String? listingId, String? chatId}); Future<void> resolveReport(String reportId); }`
  - `class Report { final String id; final String reporterId; final String status; final String reason; final String? reportedUid; final String? listingId; final String? chatId; final DateTime? createdAt; Report.fromDoc(...); }` + `class FirestoreReportStore implements ReportStore`
  - `MemberStore` gains `Stream<List<Member>> searchMembers(String displayNamePrefix)` and `Future<void> setBanned(String uid, bool banned)`.
  - `ListingStore` gains `Future<int> hideAllListingsOf(String sellerId)` (returns count hidden).
- Consumes: existing models/rules shapes.

- [ ] **Step 1: Write the failing unit tests** (append to `test/data_test.dart`, add the report_store import)

```dart
  group('names on documents', () {
    test('Listing.fromDoc reads sellerDisplayName', () {
      final listing = Listing.fromDoc('l1', {'sellerDisplayName': 'J. Dela Cruz'});
      expect(listing.sellerDisplayName, 'J. Dela Cruz');
    });

    test('Chat.fromDoc reads participant names', () {
      final chat = Chat.fromDoc('l1_b1', {
        'listingId': 'l1',
        'sellerId': 's1',
        'buyerId': 'b1',
        'participants': {'s1': true, 'b1': true},
        'buyerName': 'B. One',
        'sellerName': 'J. Dela Cruz',
      });
      expect(chat.buyerName, 'B. One');
      expect(chat.sellerName, 'J. Dela Cruz');
    });
  });

  group('Report', () {
    test('fromDoc reads the rule-validated fields', () {
      final report = Report.fromDoc('r1', {
        'reporterId': 'b1',
        'status': 'open',
        'reason': 'Scam listing',
        'listingId': 'l1',
        'reportedUid': 's1',
        'createdAt': Timestamp.fromDate(DateTime(2026, 8, 28, 12)),
      });
      expect(report.reporterId, 'b1');
      expect(report.status, 'open');
      expect(report.reason, 'Scam listing');
      expect(report.listingId, 'l1');
      expect(report.reportedUid, 's1');
    });

    test('fromDoc allows chat reports', () {
      final report = Report.fromDoc('r2', {
        'reporterId': 'b1',
        'status': 'open',
        'reason': 'Hostile messages',
        'chatId': 'l1_b1',
      });
      expect(report.chatId, 'l1_b1');
      expect(report.listingId, isNull);
      expect(report.reportedUid, isNull);
    });
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/data_test.dart` — FAIL (undefined symbols).

- [ ] **Step 3: Implement the data layer**

`lib/data/listing_store.dart`: add `final String sellerDisplayName;` to `Listing` (default `''` in the const constructor, read in fromDoc) and `required this.sellerDisplayName` on `ListingDraft` with `'sellerDisplayName': sellerDisplayName,` in `toData()`. Add to `ListingStore`:

```dart
  /// Admin: hides every active listing of a member (the ban flow uses it
  /// so a banned member's listings disappear, CONTEXT: Ban). Returns the
  /// number of listings hidden.
  Future<int> hideAllListingsOf(String sellerId);
```

and in `FirestoreListingsStore`:

```dart
  @override
  Future<int> hideAllListingsOf(String sellerId) async {
    final snapshot = await _firestore
        .collection('listings')
        .where('sellerId', isEqualTo: sellerId)
        .where('status', isEqualTo: 'active')
        .get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': 'hidden',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return snapshot.docs.length;
  }
```

  (The `sellerId == x AND status == 'active'` query needs a composite — add `sellerId` ASC + `status` ASC to `firestore.indexes.json` in this task.)

`lib/data/chat_store.dart`: `Chat` gains `this.buyerName = ''`, `this.sellerName = ''` + fromDoc reads; `openChatWithBuyer` gains `required String buyerDisplayName` and the create set gains `'buyerName': buyerDisplayName, 'sellerName': listing.sellerDisplayName,`.

`lib/data/member_store.dart`: `MemberStore` gains:

```dart
  /// Admin: member lookup by display-name prefix (ADRs 0003/0007 names are
  /// public-safe; the full UM email stays admin/self-only).
  Stream<List<Member>> searchMembers(String displayNamePrefix);

  /// Admin: flips the banned flag (the rules restrict the change to the
  /// banned field only).
  Future<void> setBanned(String uid, bool banned);
```

Firestore impls: `searchMembers` = `members.where('displayName', '>=', prefix).where('displayName', '<', prefix + '\uf8ff').limit(20).snapshots()`; `setBanned` = `doc.update({'banned': banned, 'updatedAt': FieldValue.serverTimestamp()})` (admin; the rules allow it).

Create `lib/data/report_store.dart` (Report + ReportStore + FirestoreReportStore; open stream = `reports.where('status', isEqualTo: 'open').orderBy('createdAt', descending: true).snapshots()`; submit = `add({reporterId, status: 'open', reason, if reportedUid != null, if listingId != null, if chatId != null, createdAt})`; resolve = `update({'status': 'resolved'})`).

`lib/home/sell_screen.dart`: constructor gains `required this.sellerDisplayName`; `_publish` passes `sellerDisplayName: widget.sellerDisplayName` into the `ListingDraft`.

`lib/home/app_shell.dart`: `SellScreen(... sellerDisplayName: widget.member.displayName, ...)`.

- [ ] **Step 4: Extend the fakes**

`test/widget_test.dart`:
- `FakeListingsStore`: `final hiddenFor = <String>[];` + `hideAllListingsOf` flips active→hidden in `listings` and records; `createListing` unchanged; add `sellerDisplayName` to any `ListingDraft`? No — the fake's `drafts` records drafts as sent.
- `FakeMemberStore`: add `final knownMembers = <String, Member>{};` and `final bannedUids = <String, bool>{};` + `searchMembers` returns a broadcast stream filtered from `knownMembers` (emit via a controller, `emitSearch(query)`), and `setBanned` records + emits to the uid's controller.
- Add `FakeReportStore` as in Task 4's test prep (defined here so later tasks compile):

```dart
class FakeReportStore implements ReportStore {
  final reports = <Report>[];
  final _openController = StreamController<List<Report>>.broadcast();
  final submitted = <Map<String, dynamic>>[];

  @override
  Stream<List<Report>> openReportsStream() => _openController.stream;

  void emitOpen() => _openController.add(List.of(reports));

  @override
  Future<void> submitReport({
    required String reporterId,
    required String reason,
    String? reportedUid,
    String? listingId,
    String? chatId,
  }) async {
    submitted.add({
      'reporterId': reporterId,
      'reason': reason,
      'reportedUid': reportedUid,
      'listingId': listingId,
      'chatId': chatId,
    });
    reports.add(Report(
      id: 'r${reports.length}',
      reporterId: reporterId,
      status: 'open',
      reason: reason,
      reportedUid: reportedUid,
      listingId: listingId,
      chatId: chatId,
      createdAt: DateTime(2026, 8, 28, 12),
    ));
    emitOpen();
  }

  @override
  Future<void> resolveReport(String reportId) async {
    reports.removeWhere((r) => r.id == reportId);
    emitOpen();
  }
}
```

  Also add `sellerDisplayName`/`buyerName`/`sellerName` where fakes construct listings/chats used by the UI tests.

- [ ] **Step 5: Run + analyze + commit**

```bash
flutter test      # green (new unit tests + existing suite)
flutter analyze   # clean
git add -A
git commit -m "feat(mod): denormalized names, ReportStore, ban/search/hide APIs
- Listing/chat docs carry display names (rules-validated); ReportStore +
  open/submit/resolve over the drafted reports rules; MemberStore member
  search + setBanned; ListingStore.hideAllListingsOf for the ban flow;
  fakes + unit tests; sellerDisplayName flows through the Sell screen"
```

  (Also add the `listings: sellerId + status` composite index in this commit.)

---

### Task 3: Name-flow swap — strips, chat rows, thread headers read document names

**Files:**
- Modify: `lib/home/listing_detail_screen.dart`, `lib/chats/chats_screen.dart`, `lib/chats/chat_thread_screen.dart`
- Modify: `test/widget_test.dart`

**Interfaces:** none new — replaces cross-member `memberChanges` reads with document fields (`listing.sellerDisplayName`, `chat.buyerName`/`chat.sellerName`). Members keep their docs private (emails stay PII-protected); the Admin screen (Task 5) still uses member reads legitimately.

- [ ] **Step 1: Update the affected widget tests**

The tests that used `members.emit(Member(uid: 'seller-1'...))` to name a seller/chat partner must now seed the denormalized fields instead:
- `'the seller strip resolves the member with trust cues'` → the listing seeds `sellerDisplayName: 'J. Dela Cruz'`; remove the `members.emit` for the name (keep the member emit if the strip still shows anything member-derived — it no longer does; the strip shows name from the listing + universal badge + live ratings).
- `'Chats tab lists conversations with names, previews, and times'` and `'tapping a chat row opens the thread'` → `sampleChat()` seeds `sellerName: 'J. Dela Cruz'` (or pass a named chat); drop the `members.emit` there.
- `'thread renders the pinned listing and messages'` → `sampleChat()`'s seller name shows in the header; assert it.
- Keep the `'a missing seller document falls back to a generic name'` test but repoint it: with no `sellerDisplayName` the strip falls back to `'UM student'` (the generic fallback remains as a safe default).
- The moderation-row Profile test keeps `members.emit(isAdmin: true)` (that's the viewer's own doc — self read is allowed and legit).

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/widget_test.dart` — the updated tests fail until the screens read document names.

- [ ] **Step 3: Swap the reads**

`lib/home/listing_detail_screen.dart` `_SellerStrip`:
- Replace the name `StreamBuilder<Member?>` with the listing field: `Text(listing.sellerDisplayName.isEmpty ? 'UM student' : listing.sellerDisplayName, ...)`. `_SellerStrip` gains `listing` (or `sellerDisplayName`) instead of the member stream; the member fetch is removed. The strip keeps the universal badge and the live rating stream.

`lib/chats/chats_screen.dart` `_ChatRow`:
- Avatar + name: `final otherName = viewerUid == chat.buyerId ? chat.sellerName : chat.buyerName;` → avatar initial from `otherName`, name text = `otherName.isEmpty ? 'UM student' : otherName`. Remove the two per-row `StreamBuilder<Member?>`s. `_ChatRow` drops the `memberStore` param.

`lib/chats/chat_thread_screen.dart` `_ThreadHeader`:
- Name = same side-pick over `chat.buyerName`/`chat.sellerName`; remove the `memberStore` stream. `_ThreadHeader` drops `memberStore`.

- [ ] **Step 4: Run the full suite**

Run: `flutter test` — green (fallback paths covered by `'UM student'` assertions).

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze   # clean
git add -A
git commit -m "feat(mod): read denormalized display names across boundaries
- Seller strips, chat rows and thread headers use listing/chat document
  names (validated at create by the rules) instead of cross-member reads,
  which the members read rule denies; generic fallbacks remain"
```

---

### Task 4: Member-side Report UI

**Files:**
- Modify: `lib/home/listing_detail_screen.dart`, `lib/chats/chat_thread_screen.dart`
- Create: `lib/widgets/report_dialog.dart`
- Modify: root threading (`lib/app.dart`, `lib/members/member_gate.dart`, `lib/home/app_shell.dart`, `lib/home/home_screen.dart`, `lib/home/browse_screen.dart`, `lib/profile/profile_screen.dart`, `lib/chats/chats_screen.dart`) — `ReportStore` joins the constructor bags threaded through every detail/thread push, exactly like `ratingStore` did.
- Modify: `test/widget_test.dart`

**Interfaces:**
- Produces: `Future<void> showReportDialog(BuildContext context, {required String reporterId, String? listingId, String? chatId, String? reportedUid})` in `lib/widgets/report_dialog.dart` (neubrutalist dialog: `Reason (required)` text field with validation → `Submit report`; pops true on submit). The callers then call `ReportStore.submitReport(...)` and snackbar `'Report submitted — thanks for keeping the marketplace safe.'` (errors → generic retry snackbar).
- `ListingDetailScreen` + `ChatThreadScreen` gain `required this.reportStore` (also `HomeScreen`/`BrowseScreen`/`ProfileScreen`/`ChatsScreen` for the pushes, `AppShell`/`MemberGate`/`UmMarketplaceApp`/`main.dart`).

- [ ] **Step 1: Write the failing widget tests**

```dart
  testWidgets('detail screen submits a listing report',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'l1',
          sellerId: 'seller-1',
          title: 'Dorm lamp',
          description: '',
          price: 300,
          category: 'dorm essentials',
          condition: 'like new',
          sellerDisplayName: 'J. Dela Cruz',
        ),
      ];
    final reports = FakeReportStore();
    await tester.pumpWidget(_app(
      auth: auth, members: members, listings: listings, reports: reports));
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Selling stolen notes');
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(reports.submitted, hasLength(1));
    expect(reports.submitted.single['listingId'], 'l1');
    expect(reports.submitted.single['reportedUid'], 'seller-1');
    expect(find.textContaining('Report submitted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('thread header submits a chat report',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    final reports = FakeReportStore();
    await tester.pumpWidget(threadApp(chats, listings, members, reports: reports));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Harassment');
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(reports.submitted, hasLength(1));
    expect(reports.submitted.single['chatId'], 'l1_buyer-1');
    expect(reports.submitted.single['reportedUid'], 'seller-1');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
```

  (`threadApp` gains a `FakeReportStore? reports` param passed to the thread; `_app` gains `FakeReportStore? reports` → `UmMarketplaceApp.reportStore`.)

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/widget_test.dart` — compile/behavior failures.

- [ ] **Step 3: Implement**

`lib/widgets/report_dialog.dart`: `showReportDialog` — `Dialog` with ink border; title `Report listing` / `Report this chat` (param `title`); body copy: listing → `This flags the listing for the Admin (ADR 0003).`; chat → `This flags the conversation for the Admin (ADR 0003).`; `TextField` (`Reason (required)`, maxLength 300) with inline error `Give a short reason.` on empty submit; buttons `Cancel` / `Submit report` (gold accent, disabled while empty). Pops `true` on valid submit.

`lib/home/listing_detail_screen.dart`: header band gains a trailing `IconButton` (`Icons.flag_outlined`, white, tooltip 'Report listing') visible always; onPressed → `showReportDialog(title: 'Report listing', reporterId: viewerId, listingId: listing.id, reportedUid: listing.sellerId)` → if confirmed: `await reportStore.submitReport(...)` → snackbar; catch → `'Couldn't submit the report — try again.'`. Import the dialog + report store.

`lib/chats/chat_thread_screen.dart`: `_ThreadHeader` gains a trailing flag `IconButton`; the thread resolves `otherUid` (already computed in build) and reports `chatId: chat.id, reportedUid: otherUid`; same dialog/snackbar pattern via the new `reportStore` field.

Threading: add `reportStore` to the constructor bags of `ListingDetailScreen`, `ChatThreadScreen`, `ChatsScreen`, `HomeScreen`, `BrowseScreen`, `ProfileScreen`, `AppShell`, `MemberGate`, `UmMarketplaceApp`; pass at every construction site; `main.dart` wires `FirestoreReportStore()`.

- [ ] **Step 4: Run + analyze + commit**

```bash
flutter test      # green
flutter analyze   # clean
git add -A
git commit -m "feat(mod): member-side report actions (listing + chat)
- Flag affordances on the detail header and thread header; reason dialog
  with validation; ReportStore wired from the root; success/error
  snackbars"
```

---

### Task 5: Admin Moderation screen + Profile gate

**Files:**
- Create: `lib/moderation/moderation_screen.dart`
- Modify: `lib/profile/profile_screen.dart` (gate navigates instead of snackbar)
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `ReportStore`, `MemberStore.searchMembers/setBanned`, `ListingStore.hideAllListingsOf`, `relative_time`.
- Produces: `class ModerationScreen extends StatelessWidget { const ModerationScreen({required this.memberStore, required this.listingsStore, required this.reportStore}); }` (pushed route; the Profile's admin row pushes it).

- [ ] **Step 1: Write the failing widget tests**

```dart
  testWidgets('the admin gate opens moderation with live reports',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final reports = FakeReportStore()
      ..reports.add(Report(
        id: 'r1',
        reporterId: 'buyer-1',
        status: 'open',
        reason: 'Stolen notes',
        listingId: 'l1',
        reportedUid: 'seller-1',
        createdAt: DateTime(2026, 8, 28, 12),
      ));
    await tester.pumpWidget(_app(
      auth: auth, members: members, listings: listings, reports: reports));
    auth.emit(_student);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    members.emit(const Member(
      uid: 'test-uid',
      email: 'l.murillo.546842@umindanao.edu.ph',
      displayName: 'L. Murillo',
      isAdmin: true,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Moderation'));
    await tester.pumpAndSettle();

    expect(find.text('Open reports'), findsOneWidget);
    expect(find.text('Stolen notes'), findsOneWidget);
    expect(find.text('Listing: l1'), findsOneWidget);
    expect(find.text('Hide listing'), findsOneWidget);
    expect(find.text('Ban user'), findsOneWidget);
  });

  testWidgets('hiding a listing resolves the report',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    // same setup as above, then:
    await tester.tap(find.text('Hide listing'));
    await tester.pumpAndSettle();

    expect(listings.hiddenFor, ['l1']);
    expect(reports.reports, isEmpty); // resolved, left the inbox
    expect(find.text('Open reports'), findsOneWidget);
    expect(find.text('Stolen notes'), findsNothing);
  });

  testWidgets('banning a user hides their listings and resolves the report',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    // setup; listings seeded with an active listing from 'seller-1';
    await tester.tap(find.text('Ban user'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ban'), findsOneWidget); // confirm dialog
    await tester.tap(find.text('Ban user').last); // dialog confirm
    await tester.pumpAndSettle();

    expect(members.bannedUids['seller-1'], isTrue);
    expect(listings.hiddenFor, contains('l1'));
    expect(reports.reports, isEmpty);
  });

  testWidgets('member lookup finds and bans a member',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    // setup; members.knownMembers['seller-1'] = Member(uid 'seller-1', name 'J. Dela Cruz');
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    members.emit(const Member(uid: 'test-uid', email: ..., displayName: 'L. Murillo', isAdmin: true));
    await tester.tap(find.text('Moderation'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Find a member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'J. Dela');
    await tester.pumpAndSettle();
    expect(find.text('J. Dela Cruz'), findsOneWidget);

    await tester.tap(find.text('Ban user'));
    await tester.pumpAndSettle();
    expect(members.bannedUids['seller-1'], isTrue);
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/widget_test.dart` — FAIL (ModerationScreen missing).

- [ ] **Step 3: Implement `lib/moderation/moderation_screen.dart`**

- Scaffold + column: maroon band `'MODERATION'` + back; body `ListView`:
  - `Open reports` section title + `StreamBuilder(openReportsStream)` → skeleton (3 muted rows) / empty (`No open reports — the inbox is clear.`) / rows.
  - Row (`_ReportRow`): ink-bordered card — reporter display name (`memberStore.memberChanges(report.reporterId)` — admin read is legal) + `Listing: {listingId}`/`Chat: {chatId}` caption + `reason` + relative time; actions row: `Hide listing` (secondary pill, only when `report.listingId != null`) and `Ban user` (destructive pill, only when `report.reportedUid != null`).
  - `Hide listing`: `listingsStore` update? — `hideAllListingsOf` hides by seller; for a single listing use a new thin path: `ListingStore.hideListing(String id)`? Simpler: reuse `hideAllListingsOf(reportedUid)` for both actions (ban does hide-all; hide-listing does hide-all for the seller too — pragmatic v1: hide-listing hides that seller's listings). To keep the API honest add `Future<void> hideListing(String listingId)` to `ListingStore` (admin update status → hidden; rules allow) and have the row call it; ban calls `hideAllListingsOf`. Both resolve the report after success.
  - `Ban user`: confirm dialog (`Ban @{name or uid}?` + copy "Their account loses access and their listings leave the marketplace. This can be undone.") → `setBanned(uid, true)` + `hideAllListingsOf(uid)` + `resolveReport(id)`; snackbar `'Member banned — listings hidden.'`; unban is available via member lookup card (`setBanned(uid, false)` on a banned member, snackbar `'Member unbanned.'`).
  - `Find a member` section title + search `TextField` (live prefix) + `StreamBuilder(searchMembers(query))` → member rows (`_MemberRow`: name + `Banned` pill when banned + `Ban user`/`Unban` pill; the underlying `Member` comes from `searchMembers`; banned state refreshes via the member changes stream for its row—or simpler: re-search on action).
- `lib/profile/profile_screen.dart`: the `_AdminRow` onTap pushes `ModerationScreen(memberStore: memberStore, listingsStore: listingsStore, reportStore: reportStore)` instead of the snackbar; `ProfileScreen` gains `required this.reportStore`.
- `ListingStore.hideListing(String listingId)` added to interface + Firestore impl (update status hidden) + Fake (`hiddenIds` list).

- [ ] **Step 4: Run + analyze + commit**

```bash
flutter test      # green
flutter analyze   # clean
git add -A
git commit -m "feat(mod): Admin moderation screen (screen 9)
- Live open-reports inbox with hide-listing and ban-user actions that
  resolve reports, confirm dialogs, member lookup by display name with
  ban/unban, and the ban → hide-all-active-listings flow (CONTEXT: Ban);
  the Profile admin row now opens the screen"
```

---

### Task 6: Full verification + push

- [ ] **Step 1:** `flutter analyze` (clean) + `flutter test` (full suite green).
- [ ] **Step 2:** `git push origin main`.

## Self-Review Notes

- **Rules are the contract:** verified against official docs that `request.resource.data` on `update()` is the merged future document, so the self-branch member/listing/chat update rules are sound as drafted; the new admin ban branch uses `diff().affectedKeys().hasOnly(['banned'])` to say "only the banned flag may change".
- **Name privacy:** full UM emails never leave the self/Admin read scope; only derived display names travel on listings/chats, validated at create by `get()` against member docs.
- **Ban gap fix:** the feed needs no read-rule change because the ban flow hides the member's active listings (admin batch), plus the new admin ban capability makes `setBanned` actually work in production.
- Composite indexes added in this stage: `reports` (status + createdAt), `listings` (sellerId + status) — both plain-field, matching the established pattern.