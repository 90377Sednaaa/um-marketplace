# AGENTS.md

## Project state

- `um_marketplace` is an early-stage Flutter app: `lib/main.dart` is still the unmodified Flutter starter counter demo. There is no architecture yet — one file, no routing, state management, or data-layer packages.
- Not a git repository: no branches, history, or CI workflows exist.

## Commands

```sh
flutter pub get                      # required after editing pubspec.yaml
flutter analyze                      # static analysis + lints (flutter_lints ^6.0.0)
flutter test                         # whole widget-test suite
flutter test test/widget_test.dart   # single test file
flutter run                          # launch on connected Android device/emulator
```

There is no build/codegen step and no custom task runner; the commands above are the entire workflow.

## Android is the only platform

- The only platform folder is `android/`. `ios/`, `web/`, `windows/`, `macos/`, and `linux/` do not exist, so targets like `flutter run -d chrome` or `-d windows` fail. Add one with `flutter create --platforms=<name> .` before attempting it. (`analysis_options.yaml` excludes those directories even though they are absent.)
- `android/app/build.gradle.kts` uses placeholder values with explicit TODOs: `applicationId`/namespace `com.example.um_marketplace`, debug signing for release builds. Renaming the application ID later affects installs and any future Firebase/Play registration — surface it before doing it casually.

## Tests are coupled to the starter UI

- `test/widget_test.dart` asserts the stock counter behavior (finds `'0'`, taps `Icons.add`, expects `'1'`). Rewriting `main.dart` without updating this test in the same change breaks `flutter test`.

## Firebase: MCP available, app not wired up

- `opencode.json` enables the official Firebase MCP server (`npx -y firebase-tools@latest mcp`, timeout 60 s). Its tools appear prefixed as `firebase_*` and reuse the user's Firebase CLI login — prefer them for inspecting projects/Firestore/Auth over raw CLI guesses.
- The Flutter app itself has no Firebase integration yet: no `firebase.json`, `.firebaserc`, or `google-services.json`, and no `firebase_core` (or other Firebase) packages in `pubspec.yaml`. Do not assume plugins are installed when planning Firebase work.
