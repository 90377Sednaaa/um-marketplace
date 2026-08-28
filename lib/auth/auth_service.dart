import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'um_email_policy.dart';

/// A signed-in member — the domain view of a Firebase Auth user.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  /// The Firebase Auth uid — the key of the Member Account document.
  final String uid;
  final String email;
  final String displayName;
}

/// Thrown when the Google account's address fails the UM student format
/// gate (ADR 0001). No Firebase session is ever created in that case.
class UmEmailRejectedException implements Exception {
  const UmEmailRejectedException(this.email);

  final String email;

  @override
  String toString() => 'UmEmailRejectedException($email)';
}

/// Authentication surface the UI depends on. Injected so widget tests can
/// substitute a fake and never touch Firebase.
abstract interface class AuthService {
  /// Emits the current member, or null while signed out.
  Stream<AuthUser?> get userChanges;

  /// Signs in with Google. Throws [UmEmailRejectedException] when the
  /// chosen account is not a UM student address; returns quietly when the
  /// user cancels the account chooser.
  Future<void> signInWithGoogle();

  Future<void> signOut();
}

/// Real implementation on top of Firebase Auth + google_sign_in.
///
/// Google Sign-In is the only provider (ADR 0008): University of Mindanao
/// runs Google Workspace, so a Google account *is* proof of inbox
/// ownership — no verification code needed. The format gate still applies.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<void>? _googleInit;

  /// google_sign_in v7 requires `initialize` exactly once, awaited before
  /// any other call on the plugin. In debug (qa/bypass) the hostedDomain
  /// gate is lifted so any Gmail can QA without a UM Workspace account.
  Future<void> _ensureGoogleInitialized() =>
      _googleInit ??= GoogleSignIn.instance.initialize(
        hostedDomain: kDebugMode ? null : umDomain,
      );

  @override
  Stream<AuthUser?> get userChanges =>
      _auth.authStateChanges().map(_toAuthUser);

  @override
  Future<void> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      // Canceling the chooser, being interrupted, or UI being unavailable
      // are non-errors: the user simply did not pick an account.
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
        case GoogleSignInExceptionCode.uiUnavailable:
          return;
        default:
          rethrow;
      }
    }

    // Gate BEFORE any Firebase session exists: a staff/alumni/non-UM
    // account must never become a member. Bypassed in debug so QA can
    // use any Gmail (firestore.rules.qa relaxes the server side).
    if (!kDebugMode && !isValidUmStudentEmail(account.email)) {
      await GoogleSignIn.instance.signOut();
      throw UmEmailRejectedException(account.email);
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google returned no ID token for ${account.email}.');
    }
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  @override
  Future<void> signOut() async {
    await _ensureGoogleInitialized();
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  AuthUser? _toAuthUser(User? user) {
    if (user == null) return null;
    final email = (user.email ?? '').trim().toLowerCase();
    final displayName = isValidUmStudentEmail(email)
        ? displayNameFromUmEmail(email)
        : (user.displayName ?? email);
    return AuthUser(
      uid: user.uid,
      email: email,
      displayName: displayName,
    );
  }
}