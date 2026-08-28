import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/nbr_button.dart';
import 'auth_service.dart';
import 'um_email_policy.dart';

/// The auth gate (DESIGN.md screen 5, ADR 0001/0008): maroon hero panel
/// with logo lockup and an ink-bordered card carrying the Google sign-in
/// button. Accounts whose address fails the UM student format are refused.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.signInWithGoogle();
      // Success is observed through userChanges; the gate swaps screens.
    } on UmEmailRejectedException catch (e) {
      setState(() => _error =
          '“${e.email}” is not a UM student address. Student addresses look '
          'like $umStudentEmailExample — initials + surname + 6-digit ID.');
    } catch (e) {
      // Log the real cause (e.g. a missing OAuth client config, an
      // unregistered SHA-1 fingerprint, or a non-UM Google account) — the
      // friendly copy below must never be the only trace.
      debugPrint('Google sign-in failed: $e');
      setState(() =>
          _error = 'Could not sign in. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroPanel(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _SignInCard(
                      busy: _busy,
                      error: _error,
                      onSignIn: _signIn,
                    ),
                    const SizedBox(height: 16),
                    const _FormatHint(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: UmColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.rotate(
            angle: -0.03,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: UmColors.gold,
                border: Border.all(color: UmColors.ink, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'UM',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: UmColors.ink,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'UM Marketplace',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 32,
              color: UmColors.onPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'The campus marketplace for University of Mindanao students.',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Color(0xFFF6E3D8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({
    required this.busy,
    required this.error,
    required this.onSignIn,
  });

  final bool busy;
  final String? error;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: UmColors.ink,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sign in to start trading', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Only verified University of Mindanao students can join. '
            'Use your school Google account.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: UmColors.mutedForeground,
                ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: NbrButton(
              label: busy ? 'Opening Google…' : 'Sign in with Google',
              icon: Icon(
                Icons.g_mobiledata,
                size: 26,
                color: busy ? UmColors.mutedForeground : UmColors.ink,
              ),
              fill: UmColors.surface,
              labelColor: UmColors.ink,
              onPressed: busy ? null : onSignIn,
            ),
          ),
          const SizedBox(height: 12),
          if (error != null) _ErrorBox(message: error!),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.destructive, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: UmColors.destructive,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
      ),
    );
  }
}

class _FormatHint extends StatelessWidget {
  const _FormatHint();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: UmColors.goldSoft,
          border: Border.all(color: UmColors.ink, width: 2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Student addresses look like $umStudentEmailExample',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: UmColors.ink,
              ),
        ),
      ),
    );
  }
}