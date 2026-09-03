import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SignInCard(busy: _busy, onSignIn: _signIn),
                    const SizedBox(height: 22),
                    _HowItWorksSection(),
                    const SizedBox(height: 18),
                    _CampusMeetupBanner(),
                    const SizedBox(height: 16),
                    _LoginFooter(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: UmColors.primary,
            border: Border(bottom: BorderSide(color: UmColors.ink, width: 3)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main maroon content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.rotate(
                          angle: -0.04,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: UmColors.gold,
                              border: Border.all(color: UmColors.ink, width: 2),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                  color: UmColors.ink,
                                  offset: UmShadows.small,
                                  blurRadius: 0,
                                ),
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
                        Transform.rotate(
                          angle: 0.08,
                          child: SvgPicture.asset(
                            'assets/stickers/starburst.svg',
                            width: 56,
                            height: 56,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: UmColors.surface,
                        border: Border.all(color: UmColors.ink, width: 2),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: UmColors.ink,
                            offset: Offset(3, 3),
                            blurRadius: 0,
                          ),
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
              Positioned(
                right: 18,
                bottom: -13,
                child: Transform.rotate(
                  angle: -0.05,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: UmColors.goldSoft,
                      border: Border.all(color: UmColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: UmColors.ink,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      'VERIFIED ONLY',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w800,
                        fontSize: 9.5,
                        letterSpacing: 0.8,
                        color: UmColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Neubrutalist Gold Ticker Tape Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: const BoxDecoration(
            color: UmColors.gold,
            border: Border(bottom: BorderSide(color: UmColors.ink, width: 3)),
            boxShadow: [
              BoxShadow(
                color: UmColors.ink,
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  '⚡ @umindanao.edu.ph ONLY ⚡ 0% FEES ⚡ ON-CAMPUS MEETUPS ⚡',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.6,
                    color: UmColors.ink,
                  ),
                ),
              ),
            ],
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
                blurRadius: 0,
              ),
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
                    child: const Icon(
                      LucideIcons.badgeCheck500,
                      size: 18,
                      color: UmColors.ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sign in to start trading',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: UmColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: UmColors.goldSoft,
                  border: Border.all(color: UmColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.mail500,
                      size: 16,
                      color: UmColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use your UMindanao Gmail account',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              color: UmColors.ink,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Must end in @umindanao.edu.ph to join',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w500,
                              fontSize: 10.5,
                              color: UmColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: NbrButton(
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

class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        number: '01',
        icon: LucideIcons.mailCheck500,
        title: '@umindanao',
        caption: 'UMindanao Gmail',
      ),
      (
        number: '02',
        icon: LucideIcons.messageSquare500,
        title: 'Direct Deal',
        caption: '₱0 fees • Chat 1-on-1',
      ),
      (
        number: '03',
        icon: LucideIcons.mapPin500,
        title: 'On-Campus',
        caption: 'Matina & Bolton',
      ),
    ];

    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: UmColors.gold,
              border: Border.all(color: UmColors.ink, width: 2),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: UmColors.ink,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              'HOW WE TRADE',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                letterSpacing: 0.8,
                color: UmColors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final step in steps)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 5,
                    ),
                    decoration: BoxDecoration(
                      color: UmColors.goldSoft,
                      border: Border.all(color: UmColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: UmColors.ink,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: UmColors.ink,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                step.number,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8.5,
                                  color: UmColors.gold,
                                ),
                              ),
                            ),
                            Icon(step.icon, size: 15, color: UmColors.primary),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            color: UmColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.caption,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
                            fontSize: 9,
                            color: UmColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CampusMeetupBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const campuses = ['Matina', 'Bolton', 'Tagum', 'Peñaplata'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: UmColors.gold,
                  border: Border.all(color: UmColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  LucideIcons.mapPin500,
                  size: 15,
                  color: UmColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SAFE CAMPUS MEETUPS',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.4,
                    color: UmColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final campus in campuses)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: UmColors.goldSoft,
                    border: Border.all(color: UmColors.ink, width: 1.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    campus,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 9.5,
                      color: UmColors.ink,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.shieldCheck500,
                size: 14,
                color: UmColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Meet in open areas: Cafeteria, Library, or Gym Quad. Inspect items before cash or GCash handoff.',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                    height: 1.35,
                    color: UmColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
        const SizedBox(height: 3),
        Text(
          'Exclusively for University of Mindanao Students',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w500,
            fontSize: 9.5,
            letterSpacing: 0.4,
            color: UmColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
