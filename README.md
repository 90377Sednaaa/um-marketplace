# UM Marketplace

A campus marketplace for **University of Mindanao** students to buy and sell to each other — textbooks, gadgets, org merch, dorm essentials, review materials. Built with Flutter and Firebase, styled as a neubrutalist "campus edition" (thick black borders, hard shadows, maroon and gold).

> **Status: early-stage.** The product is fully designed and documented in this repo (visual spec, domain glossary, architecture decisions) — the code is not there yet. `lib/main.dart` is still the Flutter starter counter.

## The product

- **Students only.** Membership requires a University of Mindanao email (`initial.surname.######@umindanao.edu.ph`) **and** proof you control that inbox — an account stays locked until a verification code is entered, so every user is a verified student by construction.
- **Listings, not shops.** Students list items with photos, price, condition, and category; buyers browse by category or search.
- **Chat from listings.** Every conversation starts from a listing's **Chat** or **Make an offer** button — there is no cold person-to-person messaging.
- **No money in the app.** Deals close in person on campus, settled in cash or GCash. The app just makes the introduction and records the outcome: sellers mark listings **Sold**.
- **Trust that is earned.** Buyers and sellers rate each other after a completed deal (ratings exist only between the actual parties). One admin moderates: reports, blocks, and bans.

## Design documentation

| Doc | What it is |
|---|---|
| [`DESIGN.md`](DESIGN.md) | Visual spec — colors, type, components, motion, and the 7 screens of v1 |
| [`CONTEXT.md`](CONTEXT.md) | Domain glossary — the project's shared language (Student, UM Address, Listing, Offer, Sold, Chat, …) |
| [`docs/adr/`](docs/adr/) | Architecture decision records `0001`–`0007`: email gate, no payments, single-admin moderation, deal-locked ratings, FCM push, embedded photos, Firestore data model |

If you only read two things: [`0001-student-email-gate`](docs/adr/0001-student-email-gate.md) and [`0002-no-in-app-payments`](docs/adr/0002-no-in-app-payments.md) — they explain the two decisions that make this app what it is.

## Tech stack

- **Flutter** — Android only (no `ios/`, `web/`, `windows/`, `macos/`, or `linux/` folders)
- **Firebase** project `um-marketplace-a4aa2`:
  - Auth — email/password with university-address verification (planned, ADR 0001)
  - Firestore — six-collection data model (ADR 0007); listing photos are embedded in documents (ADR 0006), so there is no Storage bucket and **no billing account** — by design
  - Cloud Messaging + Cloud Functions — push notifications, the project's only server-side piece (planned, ADR 0005)

## Running it

```sh
flutter pub get     # required after editing pubspec.yaml
flutter analyze
flutter test
flutter run         # needs a connected Android device/emulator
```

> ⚠️ `flutter run -d chrome` or `-d windows` fail — this repo only ships the `android/` platform folder.

## Repository layout

```
lib/              app code (starter counter — being replaced)
test/             widget tests
android/          Android platform wiring (Firebase-configured)
DESIGN.md         visual spec
CONTEXT.md        domain glossary
docs/adr/         architecture decision records
```

## What's next

The v1 core loop: Auth gate → Home feed → Listing detail → Sell flow → Chats → Profile → Admin area. Ratings and push notifications are scheduled as time-permitting stretches.