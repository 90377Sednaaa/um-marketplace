# AGENTS.md

## Project state

- `um_marketplace` is an early-stage Flutter app: `lib/main.dart` is still the unmodified Flutter starter counter demo. There is no architecture yet — one file, no routing, state management, or data-layer packages.
- The product design is complete and lives in the repo — `DESIGN.md` (visual spec), `CONTEXT.md` (domain glossary), and `docs/adr/0001–0007` (architecture decisions). Treat these as the source of truth for intent; the code has not caught up yet.
- Git repository hosted at https://github.com/90377Sednaaa/um-marketplace (public). Default branch: `main`; no CI workflows configured yet.

## Commands

```sh
flutter pub get                      # required after editing pubspec.yaml
flutter analyze                      # static analysis + lints (flutter_lints ^6.0.0)
flutter test                         # whole widget-test suite
flutter test test/widget_test.dart   # single test file
flutter run                          # launch on connected Android device/emulator
```

There is no build/codegen step and no custom task runner; the commands above are the entire workflow.

## Git workflow: commit and push after every completed task

- Whenever a task is finished and verified (e.g. `flutter analyze` and `flutter test` pass, or the requested change is confirmed working), commit the changes and push to the remote `main` branch — do not wait to be asked.
- Use clear, conventional commit messages describing what changed and why.
- Verification must pass before committing: fix any failures first, never commit a broken tree.
- If there is nothing to commit (no changes), skip silently.

## Android is the only platform

- The only platform folder is `android/`. `ios/`, `web/`, `windows/`, `macos/`, and `linux/` do not exist, so targets like `flutter run -d chrome` or `-d windows` fail. Add one with `flutter create --platforms=<name> .` before attempting it. (`analysis_options.yaml` excludes those directories even though they are absent.)
- `android/app/build.gradle.kts` uses placeholder values with explicit TODOs: `applicationId`/namespace `com.example.um_marketplace`, debug signing for release builds. Renaming the application ID later affects installs and any future Firebase/Play registration — surface it before doing it casually.

## Tests are coupled to the starter UI

- `test/widget_test.dart` asserts the stock counter behavior (finds `'0'`, taps `Icons.add`, expects `'1'`). Rewriting `main.dart` without updating this test in the same change breaks `flutter test`.

## Design documentation

- `DESIGN.md` — visual spec: neubrutalist campus edition, UM palette, components, v1 screens. Source of truth for UI intent.
- `CONTEXT.md` — domain glossary (Student, UM Address, Listing, Offer, Sold, Chat, Rating, …). It is a glossary **only**: no specs, no implementation details, no scratch space. Terms resolve during design sessions (e.g. via the `grill-with-docs` skill) and get captured inline as they crystallize.
- `docs/adr/0001–0007` — architecture decision records; each one explains a decision a future reader would otherwise question. Append a new ADR only when a decision is hard to reverse, surprising without context, or a genuine trade-off; never edit an old ADR in place except to mark it superseded (status + pointer to the new ADR).

## Firebase: MCP available, Android wired to `um-marketplace-a4aa2`

- `opencode.json` enables the official Firebase MCP server (`npx -y firebase-tools@15.28.1 mcp` — pinned, not `@latest`; timeout 60 s). Its tools appear prefixed as `firebase_*` and reuse the user's Firebase CLI login — prefer them for inspecting projects/Firestore/Auth over raw CLI guesses.
- The Flutter app's Android build IS wired to Firebase (project `um-marketplace-a4aa2`, app id `1:39811841253:android:baf8983bd618fdae1de80c`, package `com.example.um_marketplace`): `android/app/google-services.json` + Google Services Gradle plugin 4.4.2 + `firebase_core` in `pubspec.yaml`, initialized via `Firebase.initializeApp()` in `lib/main.dart`.
- `firebase.json` and `.firebaserc` exist and set the active project to `um-marketplace-a4aa2` (alias `default`), so the MCP server boots with a project already selected. They currently contain no deployable resource config (no Firestore/Storage rules, no Hosting, no Functions).
- Still absent: iOS/web platform folders, service-specific plugins (Auth, Firestore), and any Firebase services beyond the core Android wiring — the ADRs define the intended architecture (Auth gate per ADR 0001, Firestore model per ADR 0007, FCM + Functions per ADR 0005), but none of it is implemented yet. Add those before planning work that needs them.

## Push notifications (ADR 0005): deployed; billing guardrail deferred — read before any public launch

- **Status: deployed and live.** The project is on the **Blaze** plan (upgraded from Spark — required because Cloud Functions cannot deploy on the free plan). Three 2nd-gen Node 20 functions are ACTIVE in `asia-southeast1` on `um-marketplace-a4aa2`: `onMessageCreated` (chat messages + offers → notify the other participant), `onListingSold` (→ notify chat buyers), `onRatingCreated` (→ notify the ratee). Delivery writes `notifications/{id}` docs (feeds the in-app center) and FCM-pushes to `members/{uid}/devices/{token}`, pruning dead tokens. Unit coverage: `cd functions && npm test`.
- **Known first-deploy quirk:** a first 2nd-gen functions deploy needs a few minutes for Eventarc service-agent permissions to propagate — retry the deploy if you see "Permission denied while using the Eventarc Service Agent".
- **Artifact retention:** deployed with `--force`, which set a cleanup policy deleting container images older than 1 day in `asia-southeast1` (prevents a small growing monthly bill). Redeploy with plain `firebase deploy --only functions` — never downgrade/revert the policy; re-set with `firebase deploy --only functions --force` if it ever warns.
- **End-to-end verification is still manual:** CI proves the app (flutter test) and the payload logic (npm test), but not device reception — after any function change, smoke-test on a real device: two students chat/offer → seller's phone gets the push; mark a listing sold → buyers get it; rate after sold → ratee gets it; kill the app and repeat (background delivery).
- **Cost reality:** effectively ₱0 at this scale (Functions free tier ~2M invocations/mo; Firestore 50K reads / 20K writes per day). It is **metered, not capped** — anomalies (runaway script, scraper) could accrue.
- **Before any PUBLIC launch, install the billing hard-stop guardrail (user decision, deferred):** (1) Console → Google Cloud Billing → Budgets: ~₱100 budget, email alerts, enable alerts to a Pub/Sub topic named `billing-alerts` (use the console's one-click subscription grant). (2) Add + deploy an `onBillingAlert` Pub/Sub-triggered function (standard "stop billing with a Cloud Function" pattern; parser unit-testable like `payload.js`) that detaches the billing account on threshold — freezing the project (even reads) within minutes of the tripwire. Budget alerts alone are notifications and never stop spending.
