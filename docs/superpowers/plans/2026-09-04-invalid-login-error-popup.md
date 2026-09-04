# Invalid Login Error Pop-up & Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a neo-brutalist spring pop-in dialog animation, enforce strict client-side student address validation on login with error pop-up, and add an error guard with sign-out fallback in MemberGate to prevent indefinite loading loops.

**Architecture:** Neo-brutalist spring dialog animation using `showGeneralDialog` with `ScaleTransition` (`Curves.easeOutBack`) and `FadeTransition`; `FirebaseAuthService` strict email validation throwing `UmEmailRejectedException`; `SignInScreen` error dialog presentation; `MemberGate` guard catching invalid sessions and Firestore failures to sign out cleanly and surface the pop-in error dialog.

**Tech Stack:** Flutter, Dart, Firebase Auth, Cloud Firestore, Google Fonts, Lucide Icons, flutter_test.

## Global Constraints

- UM student email format: `^[a-z]\.[a-z]+\.\d{6}@umindanao\.edu\.ph$` case-insensitive.
- Pop-in animation: 220ms duration, `ScaleTransition` from `0.78` to `1.0` with `Curves.easeOutBack`, combined with `FadeTransition`.
- Neo-brutalist styling: 2dp/3dp ink borders, solid hard shadows (no blur), `UmColors.surface`, `UmColors.destructive`, `UmColors.gold`.
- Zero analyzer warnings (`flutter analyze`).
- All existing and new tests must pass (`flutter test`).

---

### Task 1: Pop-in Animation for Brutal Dialogs

**Files:**
- Modify: `lib/widgets/brutal_dialog.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- `Future<void> showBrutalErrorDialog(BuildContext context, {required String title, required String message})`
- `Future<void> showBrutalSuccessDialog(BuildContext context, {required String title, required String message})`

- [ ] **Step 1: Write test for pop-in dialog animation in widget_test.dart**

Add a test in `test/widget_test.dart` asserting that `showBrutalErrorDialog` displays with `ScaleTransition` and `FadeTransition`:

```dart
testWidgets('showBrutalErrorDialog renders with pop-in scale and fade transition', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showBrutalErrorDialog(
              context,
              title: 'Error Title',
              message: 'Error body message.',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pump(); // Start of animation
  expect(find.byType(ScaleTransition), findsWidgets);
  expect(find.byType(FadeTransition), findsWidgets);

  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('Error Title'), findsOneWidget);

  await tester.pumpAndSettle();
  expect(find.text('Error Title'), findsOneWidget);
  expect(find.text('Error body message.'), findsOneWidget);

  await tester.tap(find.text('Got it'));
  await tester.pumpAndSettle();
  expect(find.text('Error Title'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails or needs implementation**

Run: `flutter test test/widget_test.dart -n "showBrutalErrorDialog renders with pop-in scale and fade transition"`

- [ ] **Step 3: Implement showBrutalGeneralDialog with pop-in transition in lib/widgets/brutal_dialog.dart**

Update `lib/widgets/brutal_dialog.dart` to use `showGeneralDialog` with `ScaleTransition` (`Curves.easeOutBack`) and `FadeTransition`:

```dart
Future<T?> showBrutalGeneralDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        builder(dialogContext),
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInBack,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.78, end: 1.0).animate(curved),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}
```

And update `showBrutalErrorDialog` and `showBrutalSuccessDialog` to call `showBrutalGeneralDialog`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart -n "showBrutalErrorDialog renders with pop-in scale and fade transition"`
Expected: PASS

- [ ] **Step 5: Commit Task 1**

```bash
git add lib/widgets/brutal_dialog.dart test/widget_test.dart
git commit -m "feat(widgets): add pop-in spring animation to brutal dialogs"
```

---

### Task 2: Strict Sign-in Email Gate & Error Dialog Presentation

**Files:**
- Modify: `lib/auth/auth_service.dart`
- Modify: `lib/auth/sign_in_screen.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- `AuthService.signInWithGoogle()` throws `UmEmailRejectedException` when email is invalid.

- [ ] **Step 1: Write test verifying invalid login triggers pop-in error dialog on sign-in screen**

Add a test in `test/widget_test.dart`:

```dart
testWidgets('signing in with invalid account triggers error pop-up dialog', (tester) async {
  final fakeAuth = _FakeAuthService(
    throwOnSignIn: const UmEmailRejectedException('invalid.student@gmail.com'),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildUmTheme(),
      home: SignInScreen(authService: fakeAuth),
    ),
  );

  await tester.tap(find.text('Sign in with Google'));
  await tester.pumpAndSettle();

  expect(find.text('Not a student address'), findsOneWidget);
  expect(find.textContaining('invalid.student@gmail.com'), findsOneWidget);
  expect(find.text('Got it'), findsOneWidget);

  await tester.tap(find.text('Got it'));
  await tester.pumpAndSettle();
  expect(find.text('Not a student address'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it executes against SignInScreen**

Run: `flutter test test/widget_test.dart -n "signing in with invalid account triggers error pop-up dialog"`

- [ ] **Step 3: Update lib/auth/auth_service.dart to enforce strict student email gate**

In `lib/auth/auth_service.dart`, remove the `!kDebugMode` condition that allowed non-student emails to proceed:

```dart
    if (!isValidUmStudentEmail(account.email)) {
      await GoogleSignIn.instance.signOut();
      throw UmEmailRejectedException(account.email);
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart -n "signing in with invalid account triggers error pop-up dialog"`
Expected: PASS

- [ ] **Step 5: Commit Task 2**

```bash
git add lib/auth/auth_service.dart lib/auth/sign_in_screen.dart test/widget_test.dart
git commit -m "fix(auth): enforce strict student email validation and surface pop-in error dialog"
```

---

### Task 3: MemberGate Guard & Escape Hatch

**Files:**
- Modify: `lib/members/member_gate.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- `MemberGate` checks `isValidUmStudentEmail(widget.authUser.email)` and catches errors during account resolution.
- `_MemberSplash` includes a fallback sign-out button.

- [ ] **Step 1: Write test for MemberGate rejecting invalid account and signing out**

Add test in `test/widget_test.dart`:

```dart
testWidgets('MemberGate rejects non-student AuthUser and signs out cleanly', (tester) async {
  bool signedOut = false;
  final fakeAuth = _FakeAuthService();
  fakeAuth.onSignOut = () => signedOut = true;

  final invalidUser = const AuthUser(
    uid: 'invalid-uid',
    email: 'random.user@gmail.com',
    displayName: 'Random User',
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: buildUmTheme(),
      home: MemberGate(
        authUser: invalidUser,
        authService: fakeAuth,
        memberStore: _FakeMemberStore(),
        listingsStore: _FakeListingStore(),
        chatStore: _FakeChatStore(),
        ratingStore: _FakeRatingStore(),
        reportStore: _FakeReportStore(),
        notificationStore: _FakeNotificationStore(),
        messagingService: _FakeMessagingService(),
      ),
    ),
  );

  await tester.pumpAndSettle();
  expect(signedOut, isTrue);
  expect(find.text('Not a student address'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart -n "MemberGate rejects non-student AuthUser and signs out cleanly"`

- [ ] **Step 3: Implement invalid user guard and error handling in lib/members/member_gate.dart**

In `lib/members/member_gate.dart`:
1. In `_MemberGateState.initState()`, check `if (!isValidUmStudentEmail(widget.authUser.email))`:
   - Call `widget.authService.signOut()`.
   - Show `showBrutalErrorDialog` with title `'Not a student address'`.
2. In `_ensureMemberAccount()`, wrap `widget.memberStore.ensureMemberAccount` in `try/catch` with a timeout. If it throws, sign out and show error dialog.
3. In `_MemberSplash`, add a sign-out button so user can cancel if connection hangs.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart -n "MemberGate rejects non-student AuthUser and signs out cleanly"`
Expected: PASS

- [ ] **Step 5: Commit Task 3**

```bash
git add lib/members/member_gate.dart test/widget_test.dart
git commit -m "feat(members): guard MemberGate against invalid sessions with sign-out and error pop-up"
```

---

### Task 4: Full Verification & Integration Test Run

- [ ] **Step 1: Run flutter analyze**

Run: `flutter analyze`
Expected: 0 issues found.

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 3: Git push to main**

Run: `git push origin main`
Expected: Successfully pushed to origin/main.
