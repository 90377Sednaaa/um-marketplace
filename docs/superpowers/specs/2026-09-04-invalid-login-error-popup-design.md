# Design Specification: Invalid Login Error Pop-up & Pop-in Animation

**Date:** 2026-09-04  
**Status:** Approved  
**Author:** Antigravity  

## 1. Overview
When a user attempts to log in using an invalid account (not conforming to the University of Mindanao student email format `^[a-z]\.[a-z]+\.\d{6}@umindanao\.edu\.ph$`), or when a cached session fails member account creation in Firestore, the app previously got trapped in an indefinite loading loop on the `LOADING MARKET` splash screen.

This specification details:
1. A neo-brutalist spring **pop-in animation** for error and alert dialogs.
2. A strict client-side sign-in format check in `AuthService` that triggers an immediate error dialog.
3. An active guard and escape hatch in `MemberGate` that detects non-student accounts or Firestore permission rejections, signs out cleanly, and surfaces the error dialog.

---

## 2. Pop-in Dialog Animation (`lib/widgets/brutal_dialog.dart`)

### 2.1 Dialog Transition
Rather than standard Flutter material fade, brutal dialogs (`showBrutalErrorDialog` and `showBrutalSuccessDialog`) will be presented via a shared helper `showBrutalGeneralDialog` built on `showGeneralDialog`.

### 2.2 Animation Specs
- **Transition Duration:** 220ms for forward animation (pop in), 180ms for reverse animation (dismiss).
- **Scale Animation:**
  - Range: `0.78` -> `1.0`.
  - Curve: `Curves.easeOutBack` (overshoots slightly at the end of entry for an energetic, physical bounce).
  - Reverse Curve: `Curves.easeInBack` (snaps slightly back before shrinking).
- **Opacity Animation:**
  - Range: `0.0` -> `1.0`.
  - Curve: `Curves.linear`.
- **Backdrop:** Semi-transparent barrier color `Colors.black54`.
- **Dismissibility:** Tapping outside or the action button pops the dialog cleanly.

---

## 3. Sign-in Error Handling (`lib/auth/auth_service.dart` & `lib/auth/sign_in_screen.dart`)

### 3.1 Pre-Authentication Email Gate
In `FirebaseAuthService.signInWithGoogle()`:
- The Google account is authenticated via `GoogleSignIn.instance.authenticate()`.
- The email is immediately validated using `isValidUmStudentEmail(account.email)`.
- If invalid:
  - Google session is signed out via `GoogleSignIn.instance.signOut()`.
  - Throws `UmEmailRejectedException(account.email)` without generating any Firebase Auth session or credentials.

### 3.2 Error Dialog Presentation on Sign-In Screen
In `SignInScreen._signIn()`:
- Catches `UmEmailRejectedException(e)`.
- Resets busy state (`_busy = false`).
- Invokes `showBrutalErrorDialog`:
  - **Title:** `Not a student address`
  - **Message:** `“${e.email}” is not a UM student address. Student addresses look like l.murillo.546842@umindanao.edu.ph — initials + surname + 6-digit ID.`
  - **Action:** `Got it` button.

---

## 4. MemberGate Guard & Escape Hatch (`lib/members/member_gate.dart`)

### 4.1 Cached/Invalid Session Detection
If an invalid account reaches `MemberGate` (for instance, an old session cached in Firebase Auth):
- In `initState()` / `build()`, check `isValidUmStudentEmail(widget.authUser.email)`.
- If invalid:
  - Invoke `widget.authService.signOut()`.
  - Display error pop-up or pass error information to the auth stream.

### 4.2 Firestore Failure & Timeout Handling
In `_ensureMemberAccount()`:
- Wrap `widget.memberStore.ensureMemberAccount(widget.authUser)` with error handling and a timeout (8 seconds).
- If Firestore throws a `FirebaseException` (e.g. `permission-denied` because the account is not an authorized UM address) or encounters a connection timeout:
  - Mark state as error.
  - Automatically sign out: `await widget.authService.signOut()`.
  - Surface `showBrutalErrorDialog` explaining the issue.

### 4.3 Splash Screen Escape Action
On `_MemberSplash`:
- After 4 seconds of waiting, display a clear fallback button: `Cancel & Sign Out`.
- Tapping this calls `widget.authService.signOut()`, allowing the user to return to the sign-in screen if their network hangs.

---

## 5. Testing & Verification

1. **Unit & Widget Tests (`test/widget_test.dart`)**:
   - Verify `showBrutalErrorDialog` scales and fades in correctly with pop-in curve.
   - Verify `SignInScreen` shows `Not a student address` error dialog when an invalid email is rejected.
   - Verify `MemberGate` kicks out an invalid user and signs out instead of looping infinitely.
2. **Regression Testing**:
   - Run `flutter analyze` to ensure zero lint errors.
   - Run `flutter test` to ensure all existing 120+ tests pass.
