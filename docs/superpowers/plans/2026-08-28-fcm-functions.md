# Notifications Stage 2: FCM + Cloud Functions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver real push notifications + in-app notification generation (ADR 0005): four Cloud Functions that write `notifications/{id}` documents (feeding the existing notification center) and send FCM pushes to device tokens, plus the Flutter-side token lifecycle (permission, channel, device docs, token refresh, sign-out cleanup) — then deploy to `um-marketplace-a4aa2`.

**Architecture:** Node 20 + CommonJS JavaScript Cloud Functions (firebase-functions v2 triggers, firebase-admin SDK — no build step). Pure logic (`payload.js`: content builders, peso formatting, prune decision) is unit-tested with node:test (built into Node — no harness, no emulator). Device tokens live at `members/{uid}/devices/{token}` (doc id = FCM token) with a small self-owned rules block; Functions write the notification docs via the Admin SDK (bypasses rules) so the stage-1 notification center becomes live. Flutter uses `firebase_messaging` only — no `flutter_local_notifications` (foreground pushes are intentionally banner-less; the center stream updates anyway).

**Tech Stack:** Node 20 + npm (installed: node v24, npm 11, firebase CLI 15.28.1), `firebase-functions` v6 + `firebase-admin` v13, Flutter `firebase_messaging` (the one new pub dependency), existing `cloud_firestore` Admin SDK.

**Spec:** ADR 0005 (push notifications via FCM + Functions), CONTEXT (Notification), DESIGN.md screen 8 (center — already built in stage 1), drafted `notifications/{id}` + `members/{id}` rules.

## Global Constraints

- **TDD**: functions logic tests first (node:test), Flutter side via the fake + widget tests; every commit keeps `flutter analyze` clean + `flutter test` green AND `cd functions && npm test` green once functions exist.
- **Commit per task**, push after all tasks (AGENTS.md).
- **Only ONE new pub dependency** (`firebase_messaging`). NO other Flutter deps. Functions deps are npm-only.
- **No emulator standing up** — offline unit tests only (per approved choice). End-to-end phone push remains a manual user smoke test; the plan's gates prove deploy success + unit coverage, not device reception.
- **Deploy is approved**: the executor runs `firebase deploy --only functions,firestore:rules` at the end (the user's CLI login is wired; project `um-marketplace-a4aa2`).
- Copy strings (exact — used in tests and center rows): `New offer on your listing`, `New message`, `Listing sold`, `You got a rating`, bodies per `payload.js` below.
- Firestore rules style: `rules_version = '2'`; `signedIn()`, `isVerifiedMember(uid)`, `isAdminEmail(email)` already exist in `firestore.rules`.
- FCM token doc id is the token itself (allowed characters; direct-doc delete for pruning — no query).
- Foreground messages: `FirebaseMessaging.onMessage` listener is a documented no-op (center is stream-fed).

---

### Task 1: Functions scaffold + payload logic + unit tests

**Files:**
- Create: `functions/package.json`, `functions/index.js`, `functions/payload.js`, `functions/deliver.js`, `functions/test/payload.test.js`, `functions/.gitignore` (`node_modules/`, `*.log`)
- Modify: `firebase.json` (add `firestore` + `functions` keys), `firestore.rules` (devices block)

**Interfaces:**
- Produces (exact names later tasks/tests rely on):
  - `functions/payload.js`:
    - `formatPesos(number|string)` → `'₱250'`, `'₱1,250'` (whole pesos, thousands separators — mirrors the Dart `formatPesos`)
    - `messagePayload({type, senderName, listingTitle, price})` → `{type: 'message'|'offer', title, body}`
      - offer: `{type: 'offer', title: 'New offer on your listing', body: '₱250 for "Dorm lamp"'}`
      - message: `{type: 'message', title: 'New message', body: 'J. Dela Cruz wrote on "Dorm lamp"'}`
    - `soldPayload({listingTitle})` → `{type: 'sold', title: 'Listing sold', body: '"Dorm lamp" was marked sold.'}`
    - `ratingPayload({stars, raterName, listingTitle})` → `{type: 'rating', title: 'You got a rating', body: '★4 from B. One on "Dorm lamp".'}` (stars is int 1–5)
    - `shouldPruneToken(errorCode)` → `true` for `'messaging/unregistered-device'` and `'messaging/invalid-argument'`, else `false`
  - `functions/deliver.js`: `async function deliver({recipientUid, payload, db})` — skips when the member doc is missing or `banned === true`; otherwise (1) writes `notifications/{autoId}` `{ownerId, type, title, body, read: false, createdAt: FieldValue.serverTimestamp()}` via `db`; (2) FCM-sends to every `members/{recipientUid}/devices/{token}` doc with `{token, notification: {title, body}, android: {notification: {channelId: 'deals'}, priority: 'high'}}`; (3) on send failure deletes the device doc when `shouldPruneToken(err.code)`. `db` is injected (callers pass `getFirestore()`).
  - `functions/index.js`: `exports.onMessageCreated` (chat message trigger, offer+text), `exports.onListingSold` (listings update trigger, transition to sold), `exports.onRatingCreated` (rating trigger). Blocked-pair check: read the recipient member doc; skip when `blocked[senderUid] === true` (message trigger only).

- [ ] **Step 1: package.json + firebase.json + rules**

`functions/package.json`:

```json
{
  "name": "um-marketplace-functions",
  "version": "1.0.0",
  "private": true,
  "description": "Cloud Functions for UM Marketplace (ADR 0005): notifications via FCM.",
  "main": "index.js",
  "engines": { "node": "20" },
  "scripts": { "test": "node --test test/" },
  "dependencies": {
    "firebase-admin": "^13.0.0",
    "firebase-functions": "^6.0.0"
  }
}
```

`functions/.gitignore`:

```
node_modules/
*.log
```

`firebase.json` (replace the current empty/partial config — preserve any existing keys; the file currently has no deployable config):

```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": {
    "source": "functions",
    "runtime": "nodejs20"
  }
}
```

`firestore.rules` — inside the existing `members/{uid}` match block, before its closing brace, add:

```js
      // FCM device tokens: doc id = token, self-managed. Functions (Admin
      // SDK) read these and prune dead tokens; the app upserts on sign-in
      // / refresh and deletes its doc on sign-out (ADR 0005).
      match /devices/{token} {
        allow create: if signedIn()
          && request.auth.uid == uid
          && request.resource.data.token == token
          && request.resource.data.ownerId == uid;
        allow read, update, delete: if signedIn()
          && request.auth.uid == uid
          && request.resource.data.token == token
          && request.resource.data.ownerId == uid;
      }
```

  Note: `uid` is the wire-level variable from the parent `match /members/{uid}` — it is in scope inside the sub-match.

- [ ] **Step 2: Write the failing unit tests** — `functions/test/payload.test.js`

```js
const { test } = require('node:test');
const assert = require('node:assert/strict');

const {
  formatPesos,
  messagePayload,
  soldPayload,
  ratingPayload,
  shouldPruneToken,
} = require('../payload');

test('formatPesos mirrors the app formatter', () => {
  assert.equal(formatPesos(0), '₱0');
  assert.equal(formatPesos(250), '₱250');
  assert.equal(formatPesos(1250), '₱1,250');
  assert.equal(formatPesos(1234567), '₱1,234,567');
  assert.equal(formatPesos('249.9'), '₱250');
});

test('messagePayload builds offer and text payloads', () => {
  const offer = messagePayload({
    type: 'offer',
    senderName: 'B. One',
    listingTitle: 'Dorm lamp',
    price: 250,
  });
  assert.equal(offer.type, 'offer');
  assert.equal(offer.title, 'New offer on your listing');
  assert.equal(offer.body, '₱250 for "Dorm lamp"');

  const text = messagePayload({
    type: 'message',
    senderName: 'J. Dela Cruz',
    listingTitle: 'Dorm lamp',
  });
  assert.equal(text.type, 'message');
  assert.equal(text.title, 'New message');
  assert.equal(text.body, 'J. Dela Cruz wrote on "Dorm lamp"');
});

test('soldPayload and ratingPayload', () => {
  assert.deepEqual(soldPayload({ listingTitle: 'Dorm lamp' }), {
    type: 'sold',
    title: 'Listing sold',
    body: '"Dorm lamp" was marked sold.',
  });
  assert.deepEqual(
    ratingPayload({ stars: 4, raterName: 'B. One', listingTitle: 'Dorm lamp' }),
    {
      type: 'rating',
      title: 'You got a rating',
      body: '★4 from B. One on "Dorm lamp".',
    },
  );
});

test('shouldPruneToken only prunes dead-registration errors', () => {
  assert.equal(shouldPruneToken('messaging/unregistered-device'), true);
  assert.equal(shouldPruneToken('messaging/invalid-argument'), true);
  assert.equal(shouldPruneToken('messaging/third-party-auth-error'), false);
  assert.equal(shouldPruneToken(undefined), false);
});
```

- [ ] **Step 3: Run to verify they fail**

Run: `cd functions && npm install && npm test`
Expected: FAIL — `Cannot find module '../payload'` (it doesn't exist yet).

- [ ] **Step 4: Implement `functions/payload.js`**

```js
// Pure notification-content builders (ADR 0005). Kept free of Firebase
// imports so node:test can cover them offline.

function formatPesos(amount) {
  const digits = Math.round(Number(amount)).toString();
  let out = '₱';
  for (let i = 0; i < digits.length; i++) {
    out += digits[i];
    const remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 === 0) out += ',';
  }
  return out;
}

function messagePayload({ type, senderName, listingTitle, price }) {
  if (type === 'offer') {
    return {
      type: 'offer',
      title: 'New offer on your listing',
      body: `${formatPesos(price)} for "${listingTitle}"`,
    };
  }
  return {
    type: 'message',
    title: 'New message',
    body: `${senderName} wrote on "${listingTitle}"`,
  };
}

function soldPayload({ listingTitle }) {
  return {
    type: 'sold',
    title: 'Listing sold',
    body: `"${listingTitle}" was marked sold.`,
  };
}

function ratingPayload({ stars, raterName, listingTitle }) {
  return {
    type: 'rating',
    title: 'You got a rating',
    body: `★${stars} from ${raterName} on "${listingTitle}".`,
  };
}

// FCM send failures that mean the token is dead — the device doc is
// pruned then (ADR 0005).
function shouldPruneToken(errorCode) {
  return (
    errorCode === 'messaging/unregistered-device' ||
    errorCode === 'messaging/invalid-argument'
  );
}

module.exports = {
  formatPesos,
  messagePayload,
  soldPayload,
  ratingPayload,
  shouldPruneToken,
};
```

- [ ] **Step 5: Implement `functions/deliver.js`**

```js
// Shared delivery (ADR 0005): notification doc (feeds the in-app center)
// + FCM push to every device token + dead-token pruning. `db` and the
// messaging instance are injected by callers for testability.
const { FieldValue } = require('firebase-admin/firestore');
const { shouldPruneToken } = require('./payload');

/**
 * Writes the member's notification doc and pushes it to all their device
 * tokens, pruning dead ones. Returns the number of pushes attempted.
 */
async function deliver({ recipientUid, payload, db, messaging }) {
  const memberRef = db.collection('members').doc(recipientUid);
  const memberSnap = await memberRef.get();
  const member = memberSnap.data();
  if (!member || member.banned === true) return 0;

  await db.collection('notifications').add({
    ownerId: recipientUid,
    type: payload.type,
    title: payload.title,
    body: payload.body,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  const devices = await db
    .collection('members')
    .doc(recipientUid)
    .collection('devices')
    .get();

  let attempted = 0;
  await Promise.all(
    devices.docs.map(async (doc) => {
      const token = doc.data().token;
      if (!token) return;
      attempted += 1;
      try {
        await messaging.send({
          token,
          notification: { title: payload.title, body: payload.body },
          android: {
            priority: 'high',
            notification: { channelId: 'deals' },
          },
        });
      } catch (err) {
        if (shouldPruneToken(err.code)) {
          await doc.ref.delete();
        }
      }
    }),
  );
  return attempted;
}

module.exports = { deliver };
```

- [ ] **Step 6: Implement `functions/index.js`**

```js
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

const {
  messagePayload,
  soldPayload,
  ratingPayload,
} = require('./payload');
const { deliver } = require('./deliver');

// A chat message (text or offer) notifies the OTHER participant.
// Offer messages carry the price; the sender name comes from the chat's
// denormalized names (ADR 0007 — no member reads). Blocked senders are
// skipped (CONTEXT: Block).
exports.onMessageCreated = onDocumentCreated(
  'chats/{chatId}/messages/{msgId}',
  async (event) => {
    const message = event.data.data();
    if (!message || !message.senderId) return;
    const chatSnap = await db.collection('chats').doc(event.params.chatId).get();
    const chat = chatSnap.data();
    if (!chat) return;

    const recipientUid =
      message.senderId === chat.buyerId ? chat.sellerId : chat.buyerId;
    if (!recipientUid || recipientUid === message.senderId) return;

    const recipientSnap = await db.collection('members').doc(recipientUid).get();
    const recipient = recipientSnap.data();
    if (!recipient || recipient.banned === true) return;
    const blocked = recipient.blocked ?? {};
    if (blocked[message.senderId] === true) return;

    const listingSnap = await db.collection('listings').doc(chat.listingId).get();
    const listingTitle = listingSnap.data()?.title ?? 'a listing';

    const senderName =
      message.senderId === chat.buyerId ? chat.buyerName : chat.sellerName;

    const payload =
      message.type === 'offer'
        ? messagePayload({
            type: 'offer',
            senderName,
            listingTitle,
            price: message.price,
          })
        : messagePayload({ type: 'message', senderName, listingTitle });

    await deliver({ recipientUid, payload, db, messaging });
  },
);

// A listing flipping to sold (CONTEXT: Sold) notifies every buyer who had
// a chat on it.
exports.onListingSold = onDocumentUpdated(
  'listings/{listingId}',
  async (event) => {
    const before = event.data.before.data() ?? {};
    const after = event.data.after.data() ?? {};
    if (before.status === 'sold' || after.status !== 'sold') return;

    const chats = await db
      .collection('chats')
      .where('listingId', '==', event.params.listingId)
      .get();

    const payload = soldPayload({ listingTitle: after.title ?? 'a listing' });
    await Promise.all(
      chats.docs.map(async (chatDoc) => {
        const chat = chatDoc.data();
        if (!chat?.buyerId) return;
        await deliver({
          recipientUid: chat.buyerId,
          payload,
          db,
          messaging,
        });
      }),
    );
  },
);

// A rating notifies the ratee (ADR 0004/0005).
exports.onRatingCreated = onDocumentCreated(
  'ratings/{ratingId}',
  async (event) => {
    const rating = event.data.data();
    if (!rating || !rating.rateeId || rating.rateeId === rating.raterId) return;

    const raterSnap = await db.collection('members').doc(rating.raterId).get();
    const raterName = raterSnap.data()?.displayName ?? 'a member';

    const listingSnap = await db.collection('listings').doc(rating.listingId).get();
    const listingTitle = listingSnap.data()?.title ?? 'a listing';

    const payload = ratingPayload({
      stars: rating.stars,
      raterName,
      listingTitle,
    });
    await deliver({ recipientUid: rating.rateeId, payload, db, messaging });
  },
);
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cd functions && npm test`
Expected: PASS (all 4 tests).

- [ ] **Step 8: Verify the Flutter side is untouched + commit**

```bash
cd ..   # repo root
flutter analyze   # No issues found
flutter test      # full suite still green (rules are server-side)
git add firebase.json firestore.rules functions/
git commit -m "feat(functions): FCM + notifications backend (ADR 0005)

- Four Cloud Functions (message/offer, listing sold, rating) writing
  owner-gated notification docs and FCM pushes with dead-token pruning;
  blocked senders and banned recipients skipped; pure payload builders
  unit-tested with node:test; devices subcollection rules; firebase.json
  gains functions + firestore config"
```

---

### Task 2: Flutter-side FCM wiring

**Files:**
- Modify: `pubspec.yaml` (via `flutter pub add firebase_messaging`), `android/app/src/main/AndroidManifest.xml`
- Create: `lib/data/messaging_service.dart`
- Modify: `lib/main.dart`, `lib/app.dart`, `lib/members/member_gate.dart`
- Modify: `test/widget_test.dart` (FakeMessagingService + wiring tests)

**Interfaces:**
- Produces:
  - `abstract interface class MessagingService { Future<void> registerForMember(String uid); Future<void> unregister(); }`
  - `class FirestoreMessagingService implements MessagingService` — wraps `FirebaseMessaging`:
    - `registerForMember(uid)`: `requestPermission()` (no-op result beyond Android 13+), `createNotificationChannel` for channel `deals` (`AndroidNotificationChannel('deals', 'Deals', importance: Importance.high)`), `getToken()` → upsert `members/{uid}/devices/{token}` `{token, ownerId: uid, platform: 'android', createdAt: serverTimestamp}` (set with `SetOptions(merge: true)`), subscribe `onTokenRefresh` (re-upsert) and `onMessage` (documented no-op — foreground banner intentionally absent; the center stream updates).
    - `unregister()`: cancel subscriptions; if the current token is known, delete `members/{uid}/devices/{token}`; clear the token.
  - `class FakeMessagingService implements MessagingService` in `test/widget_test.dart` — `final registeredUids = <String>[]; int unregisterCalls = 0;` recording calls.
- Consumes: existing `MemberGate`/`AuthGate` threading pattern (one more store param, like `notificationStore`).

- [ ] **Step 1: Add the dependency + manifest changes**

```bash
flutter pub add firebase_messaging
```

In `android/app/src/main/AndroidManifest.xml`, above `<application>`:

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

and inside `<application>`, after the flutterEmbedding meta-data:

```xml
        <!-- FCM notifications use the 'deals' channel created at startup
             (ADR 0005). -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="deals" />
```

(The label/icon stay as-is; debug builds work for development pushes.)

- [ ] **Step 2: Write the failing wiring tests** (append to `test/widget_test.dart`)

```dart
  testWidgets('sign-in registers the device for FCM', (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final messaging = FakeMessagingService();
    await tester.pumpWidget(_app(
      auth: auth,
      members: members,
      listings: listings,
      messaging: messaging,
    ));
    auth.emit(_student);
    await tester.pumpAndSettle();

    expect(messaging.registeredUids, ['test-uid']);
  });

  testWidgets('sign-out unregisters before the auth session ends',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final messaging = FakeMessagingService();
    await tester.pumpWidget(_app(
      auth: auth,
      members: members,
      listings: listings,
      messaging: messaging,
    ));
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(messaging.unregisterCalls, 1);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
```

  Also update the `_app` helper: add `FakeMessagingService? messaging` → `messagingService: messaging ?? FakeMessagingService()`.

- [ ] **Step 3: Run to verify they fail**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `UmMarketplaceApp` has no `messagingService` param (compile error).

- [ ] **Step 4: Implement `lib/data/messaging_service.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// The FCM lifecycle surface (ADR 0005): register the device for a member
/// (permission, channel, token upsert, refresh), unregister on sign-out.
/// Widget tests inject a fake so the plugin is never touched in tests.
abstract interface class MessagingService {
  /// Call after the Member Account exists (MemberGate).
  Future<void> registerForMember(String uid);

  /// Call before signing out: cancels listeners and deletes the device doc.
  Future<void> unregister();
}

class FirestoreMessagingService implements MessagingService {
  FirestoreMessagingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _uid;
  String? _token;
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<String>? _refreshSub;

  Future<void> _upsertToken(String uid, String token) async {
    await _firestore
        .collection('members')
        .doc(uid)
        .collection('devices')
        .doc(token)
        .set(
      {
        'token': token,
        'ownerId': uid,
        'platform': 'android',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> registerForMember(String uid) async {
    _uid = uid;
    try {
      await _messaging.requestPermission();
    } catch (_) {
      // Permission request unavailable or denied — the center still works.
    }
    try {
      await _messaging.createNotificationChannel(
        const AndroidNotificationChannel(
          'deals',
          'Deals',
          importance: Importance.high,
        ),
      );
    } catch (_) {
      // Non-Android or channel already exists.
    }
    final token = await _messaging.getToken();
    _token = token;
    if (token != null) {
      await _upsertToken(uid, token);
    }
    _refreshSub ??= _messaging.onTokenRefresh.listen((refreshed) async {
      _token = refreshed;
      if (refreshed != null) {
        await _upsertToken(uid, refreshed);
      }
    });
    _messageSub ??= _messaging.onMessage.listen((_) {
      // Foreground banner intentionally absent (ADR 0005 stage cut): the
      // notification center is stream-fed and updates live instead.
    });
  }

  @override
  Future<void> unregister() async {
    await _messageSub?.cancel();
    await _refreshSub?.cancel();
    _messageSub = null;
    _refreshSub = null;
    final uid = _uid;
    final token = _token;
    _uid = null;
    _token = null;
    if (uid != null && token != null) {
      try {
        await _firestore
            .collection('members')
            .doc(uid)
            .collection('devices')
            .doc(token)
            .delete();
      } catch (_) {
        // Best-effort cleanup; the token record prunes itself server-side.
      }
    }
  }
}
```

  (Needs `import 'dart:async';` for `StreamSubscription`.)

- [ ] **Step 5: Thread it through the root**

`lib/main.dart`: import + pass `messagingService: FirestoreMessagingService()`; `lib/app.dart`: `UmMarketplaceApp` + `AuthGate` gain `required this.messagingService` (`MessagingService`), passed through both; `lib/members/member_gate.dart`: gains the param; call `widget.messagingService.registerForMember(widget.authUser.uid)` inside `_ensureMemberAccount` (after the `ensureMemberAccount` call — the account exists by then); replace the shell's `onSignOut` with:

```dart
onSignOut: () async {
  await widget.messagingService.unregister();
  await widget.authService.signOut();
},
```

- [ ] **Step 6: Run + analyze + commit**

```bash
flutter test      # green (2 new wiring tests + fake)
flutter analyze   # No issues found
cd functions && npm test   # still green (nothing changed)
git add -A
git commit -m "feat(notification): FCM lifecycle on Android (ADR 0005)

- firebase_messaging dep, POST_NOTIFICATIONS permission, 'deals' channel;
  MessagingService registers the device token doc on sign-in, upserts on
  refresh, deletes on sign-out; foreground pushes are banner-less by
  design (the center is stream-fed); fakes + wiring tests"
```

---

### Task 3: Deploy + push

- [ ] **Step 1: Local verification sweep**

```bash
flutter analyze                                  # No issues found
flutter test                                     # full suite green
cd functions && npm install --frozen-lockfile || npm install   # lockfile, then:
npm test                                         # functions tests green
cd ..
```

  (If `npm install` produced a `package-lock.json`, commit it in this task.)

- [ ] **Step 2: Deploy to the Firebase project**

```bash
firebase use um-marketplace-a4aa2    # already the active project per .firebaserc
firebase deploy --only functions,firestore:rules
```

  Expected: functions deploy with 3 functions (onMessageCreated, onListingSold, onRatingCreated) + rules update. Confirm success output; if a function fails to deploy, fix and redeploy. Do NOT deploy if the user's CLI login is not available — report instead.

- [ ] **Step 3: Post-deploy sanity (no device required)**

```bash
firebase functions:list     # 3 functions, state: ACTIVE
```

- [ ] **Step 4: Commit + push**

```bash
git add -A   # includes package-lock.json if generated
git commit -m "chore(functions): deploy FCM functions + device rules
- onMessageCreated/onListingSold/onRatingCreated ACTIVE on
  um-marketplace-a4aa2; notifications center now receives real events"
git push origin main
```

- [ ] **Step 5: Report the manual smoke test the user should run**

In the final summary, list: (1) fresh install on a device/emulator with a Google account → grant notification permission at sign-in; (2) two students chat → seller receives a system notification for the buyer's message and offer; (3) mark a listing sold → buyers in its chats get the sold push; (4) rate a deal after sold → ratee gets the rating push; (5) kill the app and repeat one flow (background delivery); (6) uninstall-free token-refresh sanity: none needed for first smoke.

## Self-Review Notes

- **Rules semantics:** the members devices sub-match uses `uid` from the parent match (in scope); the update rule also matches the same shape as create for the app's `set(merge:true)` refresh path.
- **`request.resource.data.token == token`** in the devices rules guards against writing somebody else's token under your own device doc id — the doc id constraint mirrors the app's `doc(token)` writes.
- **Blocked/banned:** both skip conditions read the recipient member doc once (`blocked[senderUid]` for messages only; `banned` for everyone) — cheap and matches ADR 0003.
- **Trees stay green at every commit:** Task 1 changes no Dart code; Task 2's app changes are covered by fakes; Task 3 deploys a fully-tested tree.
- **Known limitations (honest, in the plan):** foreground pushes show no system banner (stage cut, documented in code); no emulator-based integration tests; device reception verified by the user's manual smoke test, not by CI.
- If `firebase deploy` asks for a project that differs from `.firebaserc` (alias `default` → `um-marketplace-a4aa2`), trust `.firebaserc` and confirm via `firebase projects:list` before deploying.