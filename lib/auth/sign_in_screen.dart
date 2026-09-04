import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../widgets/brutal_dialog.dart';
import '../widgets/nbr_button.dart';
import 'auth_service.dart';
import 'um_email_policy.dart';

/// The auth gate (DESIGN.md screen 5, ADR 0001/0008): unified brutal canvas
/// with the iconic gold "Ga" badge, ink-bordered Google sign-in card,
/// student domain note, and minimalist campus footer. Accounts whose address
/// fails the UM student format are refused.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.authService.signInWithGoogle();
      // Success is observed through userChanges; the gate swaps screens.
    } on UmEmailRejectedException catch (e) {
      if (mounted) setState(() => _busy = false);
      if (!mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Not a student address',
        message:
            '“${e.email}” is not a UM student address. Student addresses look like $umStudentEmailExample — initials + surname + 6-digit ID.',
      );
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      if (mounted) setState(() => _busy = false);
      if (!mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Sign-in failed',
        message: 'Could not sign in. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UmColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),
                            const _AppBadge(),
                            const SizedBox(height: 20),
                            const _AppHeader(),
                            const SizedBox(height: 36),
                            _SignInCard(busy: _busy, onSignIn: _signIn),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 28, bottom: 8),
                          child: _LoginFooter(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AppBadge extends StatelessWidget {
  const _AppBadge();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.04,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: UmColors.gold,
          border: Border.all(color: UmColors.ink, width: 3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: UmColors.ink,
              offset: UmShadows.card,
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          'Ga',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            fontSize: 34,
            letterSpacing: 1.2,
            color: UmColors.ink,
          ),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'UM Marketplace',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            fontSize: 32,
            height: 1.1,
            letterSpacing: -0.8,
            color: UmColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The campus marketplace for University of Mindanao students.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            height: 1.4,
            color: UmColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.busy, required this.onSignIn});

  final bool busy;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: UmColors.ink, offset: UmShadows.card, blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NbrButton(
            label: busy ? 'Opening Google…' : 'Sign in with Google',
            icon: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: UmColors.mutedForeground,
                    ),
                  )
                : SvgPicture.asset(
                    'assets/logos/google_g.svg',
                    width: 20,
                    height: 20,
                  ),
            fill: UmColors.surface,
            labelColor: UmColors.ink,
            stretch: true,
            onPressed: busy ? null : onSignIn,
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: UmColors.goldSoft,
                border: Border.all(color: UmColors.ink, width: 1.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.shieldCheck500,
                    size: 15,
                    color: UmColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '@umindanao.edu.ph accounts only',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.2,
                        color: UmColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  const _LoginFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Exclusively for University of Mindanao Students',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.3,
            color: UmColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Peer-to-peer • Meet on campus',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w500,
            fontSize: 11,
            letterSpacing: 0.4,
            color: UmColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
