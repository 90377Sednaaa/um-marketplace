# AGENTS.md

## Project state

- `um_marketplace` is **v1 shipped** (not starter): `lib/main.dart` boots `Firebase.initializeApp` + `UmMarketplaceApp` (`lib/app.dart` → `AuthGate` → `MemberGate` → `AppShell` 4-tab `IndexedStack`). Architecture is layered: `theme/` (`UmColors`/`UmShadows`/`ThemeData` Space Grotesk 800/700 + Outfit 400/600 via `google_fonts`) + `data/` (`member/listing/chat/rating/report/notification/messaging` stores, injectable fakes for tests) + `widgets/` (`NbrButton` brutal `4dp` shadow, `BrutalLoader`/`BrutalDialog`, report/offer dialogs) + `auth/home/chats/profile/moderation/notifications/members`.
- Product design lives in `DESIGN.md` (dual type, flat brutal nav `3dp` top + `2dp` dividers, hero/search/category/product card/button/badge/empty, 9 screens), `CONTEXT.md` (glossary only), `docs/adr/0001–0009` (email gate, no payments, admin, ratings, FCM, embedded photos, Firestore model, Google Sign-In only, deterministic chat id). Treat as source of truth; code now matches (lean Home, `Ga` sticker, `flutter_svg` stickers, `BrutalLoader`).
- Git `https://github.com/90377Sednaaa/um-marketplace` public `main`; recent history is brutal overhaul + firestore `PERMISSION_DENIED` fix (`buyerId/sellerId`) + auth `Ga` + loading `Ga` + error pop-ups. No CI yet.

## Commands

```sh
flutter pub get                      # after pubspec.yaml + assets/stickers + assets/logos
flutter analyze                      # flutter_lints ^6.0.0
flutter test                         # 103 tests (widget + data_test + um_email_policy_test)
flutter test test/widget_test.dart   # single file
flutter run                          # Android device/emulator only
cd functions && npm test              # Functions payload.js unit tests
firebase deploy --only firestore      # rules + 8 indexes (sellerId+createdAt etc) — wait CREATING→READY
firebase deploy --only functions      # 3 pushes asia-southeast1 Node20 2nd-gen — retry on Eventarc SA propagation
firebase firestore:indexes --pretty  # poll until all READY
```

No build/codegen; these are the entire workflow.

## Git workflow: commit and push after every completed task

- Whenever verified (`flutter analyze` + `flutter test` pass, or requested change confirmed), commit and push to `main` — do not wait to be asked.
- Conventional messages (`feat:`, `fix:` etc) describing what/why.
- Never commit broken tree; fix first.
- Skip silently if nothing to commit.

## Branches: `main` is production, `qa/bypass` is dev/QA

- `main` — production, strict UM gate (`lib/auth/auth_service.dart:60,90` `isValidUmStudentEmail` + `firestore.rules:101` `isUmAddress`). Never deploy `firestore.rules.qa` to prod.
- `qa/bypass` — development workspace (branched from `main`, `kDebugMode`-gated bypass `lib/auth/auth_service.dart:60,90` `hostedDomain: null` + client gate lifted). `flutter run` (debug) any Gmail can QA publish/chat; `flutter build apk --release` stays gated. Extra file `firestore.rules.qa` (relaxed `isUmAddress` → `email.size()>0`) for live Firestore QA — deploy via `copy firestore.rules.qa firestore.rules && firebase deploy --only firestore` and revert with `git checkout main -- firestore.rules && firebase deploy --only firestore` before release. Safe to merge `qa/bypass` → `main` (bypass is debug-only, `firestore.rules` unchanged unless you copy).
- **Merge/deploy truth:** safe to merge to `main`: `lib/auth/auth_service.dart` (kDebugMode), `firestore.rules.qa`, `AGENTS.md`. **Never** merge a relaxed `firestore.rules` (isQaMember) to `main` nor `firebase deploy --only firestore` while `firestore.rules` is the QA copy — prod must always deploy the strict `firestore.rules:101` `isUmAddress`.

## Android is the only platform

- Only `android/` exists; `ios/`, `web/`, `windows/`, `macos/`, `linux/` do not — `flutter run -d chrome/windows` fails. Add via `flutter create --platforms=<name> .` (`analysis_options.yaml` excludes them even when absent).
- `android/app/build.gradle.kts` has `TODO` placeholders: `applicationId`/namespace `com.example.um_marketplace`, debug signing for release. Renaming affects installs and Firebase/Play — surface before doing casually.

## Tests are comprehensive (no longer starter-coupled)

- `test/widget_test.dart` `103` tests: auth gate (`Ga` not `l.murillo` email), `Sign in with Google` → `Verified UM student`, `Recent listings`, bottom nav `HOME/SELL/CHATS/PROFILE` uppercase, `SELL` CTA, sell draft persistence, `Publish listing` `Give it a short title` inline, chats/threads/offers, sold/banner, blocked, search/browse/category chips + `Browse` pills + filters, `Popular search` chips, `Profile` identity + `My listings` `SOLD`/`Mark as sold`, moderation `Reports`, notifications bell, FCM register/unregister, `kMaxListingPhotos=2`, `Uint8List` round-trip.
- `test/data_test.dart` + `test/um_email_policy_test.dart` cover `isValidUmStudentEmail` (`^[a-z]\.[a-z]+\.\d{6}@umindanao\.edu\.ph$` case-insensitive), `displayNameFromUmEmail`, `formatPesos`, `chat/helpers` (`chatIdFor`, `Chat.fromDoc`, `chatPreview`, `mergeChatStreams`), `formatRelativeTime`, `filterListings`, `Rating.fromDoc`/`ratingSummaryText`, `Listing.fromDoc`, `Report.fromDoc`, `AppNotification.fromDoc`.
- Updating `main.dart`/`SignInScreen`/`Home`/`AppShell`/`Sell`/`Chats`/`Profile` now requires updating `widget_test.dart` in the same change (e.g. `Ga` vs `UM`, `HOME` vs `Home`, `SELL` vs `Sell something` on Home, `Sign out` now on `PROFILE` top not Home, error dialogs not inline `SnackBar` for some paths).

## Design documentation

- `DESIGN.md` — neubrutalist campus edition, UM palette, dual type (`Space Grotesk`/`Outfit`), borders `2dp`/`3dp`, shadows `3/4/6dp` `0` blur, `8dp` radius + `999` pills, stickers (`Ga`, `starburst`/`bag`/`tag` `4dp` stroke via `flutter_svg`), 9 screens. Source of truth for UI.
- `CONTEXT.md` — glossary only (Student, UM Address, Verified Student, Member Account, Listing, Offer, Chat, Sold, Category, Rating, Notification, Report, Block, Ban, Admin). Captured via `grill-with-docs`.
- `docs/adr/0001–0009` — hard-to-reverse decisions; never edit old in place (mark superseded + pointer). `assets/stickers/` + `assets/logos/google_g.svg` are the brutal sticker system.

## Firebase: MCP available, Android wired to `um-marketplace-a4aa2`

- `opencode.json` Firebase MCP (`npx -y firebase-tools@15.28.1 mcp`, pinned, 60s) reuses CLI login — prefer `firebase_*` tools over raw CLI guesses.
- Android wired (project `um-marketplace-a4aa2`, app `1:39811841253:android:baf8983bd618fdae1de80c`, `com.example.um_marketplace`): `android/app/google-services.json` + GMS `4.4.2` + `firebase_core` + `firebase_auth` + `google_sign_in` + `cloud_firestore` + `firebase_messaging` + `image_picker`/`flutter_image_compress` + `google_fonts` + `flutter_svg`, `Firebase.initializeApp()` in `lib/main.dart`.
- `firebase.json` + `.firebaserc` set `default` to `um-marketplace-a4aa2`; `firestore.rules` (buyerId/sellerId/participants for chats, `status/active||sellerId` for listings) + `firestore.indexes.json` (8 `READY`: `listings status+createdAt`, `sellerId+createdAt`, `sellerId+status`, `ratings rateeId+createdAt`, `reports status+createdAt`, `chats buyerId/sellerId+lastMessageAt`, `notifications ownerId+createdAt`) are deployed. Functions too — not absent.
- Still absent: `ios`/`web` folders, Storage bucket (by design — photos in docs ADR `0006`), Hosting.

## Push notifications (ADR 0005): deployed; billing guardrail deferred — read before any public launch

- **Status: deployed and live.** Blaze plan (Spark → Blaze for Functions). Three 2nd-gen Node 20 `asia-southeast1` `ACTIVE`: `onMessageCreated` (chat+offer → other participant), `onListingSold` (→ chat buyers), `onRatingCreated` (→ ratee). Writes `notifications/{id}` + FCM to `members/{uid}/devices/{token}` prune. Unit coverage `cd functions && npm test`.
- **First-deploy quirk:** Eventarc SA needs minutes to propagate — retry on `Permission denied while using the Eventarc Service Agent`.
- **Artifact retention:** deployed `--force` sets 1-day image cleanup `asia-southeast1`. Redeploy plain `firebase deploy --only functions`.
- **End-to-end verification manual:** `flutter test` + `npm test` prove logic, not device reception — smoke on real device after any function change: two students chat/offer → seller push; sold → buyers; rate after sold → ratee; kill app + repeat background.
- **Cost:** ~₱0 at scale (Functions 2M/mo, Firestore 50K reads/20K writes per day) but **metered, not capped**.
- **Before PUBLIC launch, install guardrail (deferred):** (1) Google Cloud Billing → Budgets `≈₱100` + email + Pub/Sub `billing-alerts` (one-click grant). (2) Add + deploy `onBillingAlert` Pub/Sub function (stop-billing pattern, parser unit-testable) detaches billing → freeze within minutes. Budget alerts alone never stop spending.
- **After fresh `firestore:indexes` deploy:** four indexes `CREATING` ~1–5 min — poll `firebase firestore:indexes --pretty` until all `READY`, then cold-restart app (listeners don't auto-retry `FAILED_PRECONDITION`).
