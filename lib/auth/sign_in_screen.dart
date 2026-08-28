import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/brutal_dialog.dart';
import '../widgets/nbr_button.dart';
import 'auth_service.dart';
import 'um_email_policy.dart';

/// The auth gate (DESIGN.md screen 5, ADR 0001/0008): maroon hero panel
/// with brutal stickers and an ink-bordered card carrying the Google sign-in
/// button. Accounts whose address fails the UM student format are refused.
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
      if (!mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Not a student address',
        message:
            '“${e.email}” is not a UM student address. Student addresses look like $umStudentEmailExample — initials + surname + 6-digit ID.',
      );
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
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
                    const SizedBox(height: 8),
                    _SignInCard(
                      busy: _busy,
                      onSignIn: _signIn,
                    ),
                    const SizedBox(height: 20),
                    _TrustStickers(),
                    const SizedBox(height: 12),
                    Text(
                      'Peer-to-peer • No checkout • Meet on campus',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: UmColors.mutedForeground,
                      ),
                    ),
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
      decoration: const BoxDecoration(
        color: UmColors.primary,
        border: Border(bottom: BorderSide(color: UmColors.ink, width: 3)),
        boxShadow: [
          BoxShadow(color: UmColors.ink, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main maroon content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.rotate(
                  angle: -0.04,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: UmColors.gold,
                      border: Border.all(color: UmColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                            color: UmColors.ink,
                            offset: UmShadows.small,
                            blurRadius: 0),
                      ],
                    ),
                    child: Text(
                      'Ga',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: UmColors.ink,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'UM Marketplace',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    height: 1.05,
                    letterSpacing: -0.5,
                    color: UmColors.onPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: UmColors.surface,
                    border: Border.all(color: UmColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                          color: UmColors.ink,
                          offset: Offset(3, 3),
                          blurRadius: 0),
                    ],
                  ),
                  child: Text(
                    'The campus marketplace for University of Mindanao students.',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      height: 1.35,
                      color: UmColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Brutal stickers — overlapping the hero edge
          Positioned(
            right: 16,
            top: 18,
            child: Transform.rotate(
              angle: 0.08,
              child: SvgPicture.asset(
                'assets/stickers/starburst.svg',
                width: 64,
                height: 64,
              ),
            ),
          ),
          Positioned(
            right: 22,
            bottom: -18,
            child: Transform.rotate(
              angle: -0.06,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: UmColors.goldSoft,
                  border: Border.all(color: UmColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                        color: UmColors.ink,
                        offset: Offset(3, 3),
                        blurRadius: 0),
                  ],
                ),
                child: Text(
                  'VERIFIED ONLY',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: UmColors.ink,
                  ),
                ),
              ),
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
    required this.onSignIn,
  });

  final bool busy;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          decoration: BoxDecoration(
            color: UmColors.surface,
            border: Border.all(color: UmColors.ink, width: 2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                  color: UmColors.ink,
                  offset: UmShadows.card,
                  blurRadius: 0),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: UmColors.gold,
                      border: Border.all(color: UmColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.verified_user,
                        size: 18, color: UmColors.ink),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Sign in to start trading',
                        style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: UmColors.onSurface)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Only verified University of Mindanao students can join. Use your school Google account.',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  height: 1.45,
                  color: UmColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.center,
                child: NbrButton(
                  label: busy ? 'Opening Google…' : 'Sign in with Google',
                  icon: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: UmColors.mutedForeground),
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
              ),
            ],
          ),
        ),
        // Overlapping bag sticker peeking over the card
        Positioned(
          right: -6,
          top: -14,
          child: Transform.rotate(
            angle: 0.07,
            child: SvgPicture.asset(
              'assets/stickers/bag.svg',
              width: 48,
              height: 48,
            ),
          ),
        ),
        Positioned(
          left: -8,
          bottom: -12,
          child: Transform.rotate(
            angle: -0.09,
            child: SvgPicture.asset(
              'assets/stickers/tag.svg',
              width: 44,
              height: 44,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrustStickers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: Icons.menu_book_outlined, label: 'Textbooks'),
      (icon: Icons.devices_outlined, label: 'Gadgets'),
      (icon: Icons.bed_outlined, label: 'Dorm'),
    ];
    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: UmColors.goldSoft,
                  border: Border.all(color: UmColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(item.icon, size: 20, color: UmColors.primary),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: UmColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
