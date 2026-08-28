# UM Marketplace

A campus marketplace for **University of Mindanao** students to buy and sell to each other — textbooks, gadgets, org merch, dorm essentials, review materials. Built with Flutter + Firebase, styled as a neubrutalist **"campus edition"** (thick `2dp` ink borders, `4dp` hard shadows `blur 0`, flat maroon `#7C2D12` · gold `#FFC72C` · ink `#000`).

> **Status: v1 core loop shipped.** Auth gate → Home feed → Listing detail → Sell flow → Chats (listing-bound) → Profile (my listings + Sign out) → Admin moderation → Ratings → Notifications (bell + center + FCM pushes) are implemented, tested (`103` widget + unit tests), and wired to `um-marketplace-a4aa2` (Android). Design system is brutalized: `Space Grotesk 800/700` display + `Outfit 400/600` body via `google_fonts`, `2dp` borders, tiered shadows `3/4/6dp`, `Ga` gold sticker, `flutter_svg` stickers (`assets/stickers/` + `assets/logos/google_g.svg`), `BrutalLoader` square spinner.

## The product

- **Students only.** `initial.surname.######@umindanao.edu.ph` + Google Sign-In ownership proof (ADR `0001`/`0008`). Every usable account is a `Verified Student`; the login screen is a maroon brutal hero with `Ga` sticker + `VERIFIED ONLY` pill and a white ink-bordered card with the latest 4-color Google G via `flutter_svg`. No `Student addresses look like…` hint card — it was removed.
- **Listings, not shops.** `sellerId + title + price + category/condition + sellerDisplayName` denormalized (ADR `0007`), photos embedded as `Uint8List` in the doc (ADR `0006`, `kMaxListingPhotos=2` under 1 MiB). Home is lean: hero search `3dp` `999` pill `4dp` shadow + popular chips + 5 category tiles (`goldSoft` circle + maroon icon, `48dp` square `3dp` shadow, label `24dp` fixed height to align) + recent feed `2-col` `0.68` grid; `MemberCard` + `Sign out` were removed from Home and live only on Profile. FAB gold `56dp` brutal `+` on Home (`4dp` shadow, press `2,2`).
- **Chat from listings.** `chats/{listingId}_{buyerId}` deterministic (ADR `0009`), `participants:{seller:true,buyer:true}` + denormalized `buyerName/sellerName`. No cold DMs. `myChatsStream` merges `where buyerId==uid orderBy lastMessageAt` + `where sellerId==uid orderBy lastMessageAt` (50 each) via `mergeChatStreams` → 50 most recent. Blocked pairs cannot message; sold/hidden listings refuse `openChatWithBuyer`. Empty `Conversations` is brutal: `56dp` square icon `3dp` shadow + `NO CONVERSATIONS` `800 14` + `No conversations yet…` + gold `Browse listings` CTA.
- **No money in the app.** `Chat` + `Make an offer` (offer-typed message with `price`) only; `markSold` flips `status` to `sold` (terminal). Sold banner + `SOLD` sticker on hero photo.
- **Trust that is earned.** Ratings are deal-locked: `ratings/{listingId}_{raterUid}` only if `isCompletedDeal` (chat belongs to listing, listing `sold`, rater/ratee are buyer/seller). Displayed as `★ avg · trade count`. Admin (`l.murillo.546842@umindanao.edu.ph` `isAdmin`) sees `Moderation` row on Profile → `screen 9` inbox (`openReportsStream` status+createdAt) + `Ban`/`Hide listing` + member lookup.
- **Notifications.** In-app bell in brutal maroon band (`3dp` bottom border `0,4` shadow, `Ga` pill, gold `42dp` bell `2dp` square `3dp` shadow, red unread pill) → `NotificationCenter` (`ownerId+createdAt`). Functions (Blaze, `asia-southeast1`, Node 20, 2nd-gen) `onMessageCreated` / `onListingSold` / `onRatingCreated` write `notifications/{id}` + FCM to `members/{uid}/devices/{token}` with prune. Unit coverage `functions && npm test`.

## Design documentation

| Doc | What it is |
|---|---|
| [`DESIGN.md`](DESIGN.md) | Visual spec — dual type (`Space Grotesk` display `800/700` + `Outfit` body `400/600`), `2dp` borders `3/4/6dp` hard shadows `8dp` radius, flat brutal nav (`3dp` top border + `2dp` dividers, gold active `2dp` block `8dp` radius `800` uppercase), hero/search/category/product card/button/badge/empty specs, 9 screens |
| [`CONTEXT.md`](CONTEXT.md) | Domain glossary only (Student, UM Address, Verified Student, Member Account, Listing, Offer, Chat, Sold, Category, Rating, Notification, Report, Block, Ban, Admin) |
| [`docs/adr/`](docs/adr/) | `0001`–`0009`: student email gate, no payments, single-admin, deal-locked ratings, FCM, embedded photos, Firestore model, Google Sign-In only, deterministic chat id |
| [`assets/stickers/` + `assets/logos/`](pubspec.yaml) | `starburst.svg`, `tag.svg`, `bag.svg` (brutal `4dp` stroke) + `google_g.svg` (4-color G) via `flutter_svg` |

If you only read two: [`0001-student-email-gate`](docs/adr/0001-student-email-gate.md) + [`0002-no-in-app-payments`](docs/adr/0002-no-in-app-payments.md).

## Tech stack

- **Flutter `3.47` / Dart `3.13`** — Android only (`android/` only; `flutter create --platforms=<name> .` to add more)
- **Firebase `um-marketplace-a4aa2`** (`1:39811841253:android:baf8983bd618fdae1de80c` `com.example.um_marketplace`): `firebase_core 4.14` + `firebase_auth 6.6` + `google_sign_in 7.2` (ADR `0008`), `cloud_firestore 6.9` (six collections, `firestore.rules` allow `buyerId/sellerId/participants` for chats, `status/active||sellerId` for listings; `firestore.indexes.json` 8 indexes `status+createdAt` `sellerId+createdAt` `sellerId+status` `rateeId+createdAt` `reports status+createdAt` `chats buyerId/sellerId+lastMessageAt` `notifications ownerId+createdAt` — all `READY`), `firebase_messaging 16.6` + `functions` Node 20 (Blaze) `asia-southeast1` `onMessageCreated/onListingSold/onRatingCreated`
- **UI:** `google_fonts 6.2` (`Space Grotesk`/`Outfit`), `flutter_svg 2.2`, `image_picker 1.2` + `flutter_image_compress 2.5` (gallery → max `900`/`70` recompress `800`/`70` under `300KB`)
- **No Storage bucket** — photos live in docs (ADR `0006`)

## Running it

```sh
flutter pub get     # after pubspec.yaml + assets
flutter analyze     # flutter_lints 6.0.0
flutter test        # 103 tests: widget + data_test + um_email_policy_test
flutter run         # Android device/emulator (chrome/windows fail — no platform folder)
cd functions && npm test   # Functions payload logic
firebase deploy --only firestore  # rules + indexes (8, all READY)
firebase deploy --only functions  # 3 pushes (first needs Eventarc SA propagation, retry)
```

> After a fresh `firestore:indexes` deploy, four indexes show `CREATING` for ~1–5 min — re-run `firebase firestore:indexes --pretty` until all `READY`, then cold-restart the app (listeners don't auto-retry `FAILED_PRECONDITION`).

## Repository layout

```
lib/
  app.dart                 MaterialApp + AuthGate
  main.dart                Firebase.initializeApp + UmMarketplaceApp
  auth/                    sign_in_screen.dart (Ga hero + brutal card + Svg google_g) + um_email_policy + auth_service
  members/member_gate.dart MemberGate + _MemberSplash (Ga 42pt + BrutalLoader 56 + grid dots) + BannedScreen
  home/ app_shell.dart (maroon band + flat brutal nav + FAB) + home_screen.dart (lean) + sell_screen.dart + browse_screen.dart + listing_detail_screen.dart + listing_card.dart
  chats/ chats_screen.dart (brutal NO CONVERSATIONS) + chat_thread_screen.dart (pinned listing + bubbles + composer + rating prompt)
  profile/profile_screen.dart (IdentityCard + RatingCard + AdminRow + Sign out top + My listings NO LISTINGS)
  notifications/notification_center_screen.dart
  moderation/moderation_screen.dart
  data/ member_store + listing_store + chat_store + rating_store + report_store + notification_store + messaging_service
  theme/app_theme.dart     UmColors + UmShadows (3/4/6) + Space Grotesk/Outfit ThemeData
  widgets/ nbr_button.dart (Align vs SizedBox fix for huge shadow) + brutal_loader.dart + brutal_dialog.dart (error/success pop-ups) + report/offer dialogs
test/ data_test.dart + um_email_policy_test.dart + widget_test.dart (103)
assets/ stickers/{starburst,tag,bag}.svg  logos/google_g.svg  images/um-seal.png
functions/ index.js + payload.js (3 triggers) + test/
firestore.rules  firestore.indexes.json  firebase.json  .firebaserc  android/app/google-services.json
DESIGN.md  CONTEXT.md  docs/adr/0001-0009
```

## What's next

Core loop is done and brutalized. Before public launch: (1) billing hard-stop (`≈₱100` Budgets → Pub/Sub `billing-alerts` → `onBillingAlert` detaches billing — deferred by user choice), (2) manual device smoke test for pushes (chat/offer, sold, rating, background), (3) Play `applicationId` rename + release signing (see `android/app/build.gradle.kts` TODOs), (4) add `ios`/`web` if needed.
