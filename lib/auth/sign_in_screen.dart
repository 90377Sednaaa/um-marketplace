import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/brutal_dialog.dart';
import '../widgets/nbr_button.dart';
import '../widgets/um_logo.dart';
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 36,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SignInCard(busy: _busy, onSignIn: _signIn),
                              const SizedBox(height: 16),
                              _CampusTrustCard(),
                              const SizedBox(height: 16),
                              _CampusCategories(),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _LoginFooter(),
                        ],
                      ),
                    ),
                  );
                },
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const UmMark(size: 44),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: UmColors.surface,
                    border: Border.all(color: UmColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                        color: UmColors.ink,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    'STUDENT EXCHANGE',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: UmColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'UM Marketplace',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 34,
                height: 1.05,
                letterSpacing: -1.0,
                color: UmColors.onPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The campus marketplace for University of Mindanao students.',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
                height: 1.4,
                color: UmColors.goldSoft,
              ),
            ),
          ],
        ),
      ),
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
          padding: const EdgeInsets.all(20),
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
                        fontSize: 17,
                        color: UmColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Only verified University of Mindanao students can join. Use your school Google account (@umindanao.edu.ph).',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w400,
                  fontSize: 13.5,
                  height: 1.45,
                  color: UmColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 20),
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
              width: 44,
              height: 44,
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
              width: 40,
              height: 40,
            ),
          ),
        ),
      ],
    );
  }
}

class _CampusTrustCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: _TrustItem(
                  icon: LucideIcons.mailCheck500,
                  title: '@umindanao',
                  subtitle: 'School email',
                ),
              ),
              Container(width: 2, height: 36, color: UmColors.ink),
              const Expanded(
                child: _TrustItem(
                  icon: LucideIcons.handshake500,
                  title: '₱0 Fees',
                  subtitle: 'Direct chat',
                ),
              ),
              Container(width: 2, height: 36, color: UmColors.ink),
              const Expanded(
                child: _TrustItem(
                  icon: LucideIcons.mapPin500,
                  title: 'On-Campus',
                  subtitle: 'Safe meetups',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: UmColors.goldSoft,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: UmColors.ink, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.shieldCheck500,
                  size: 14,
                  color: UmColors.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Matina • Bolton • Tagum • Peñaplata',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.4,
                      color: UmColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: UmColors.primary),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            fontSize: 11.5,
            color: UmColors.ink,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w500,
            fontSize: 10,
            color: UmColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _CampusCategories extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const categories = [
      (icon: LucideIcons.bookOpen500, label: 'Textbooks'),
      (icon: LucideIcons.shirt500, label: 'Uniforms'),
      (icon: LucideIcons.smartphone500, label: 'Gadgets'),
      (icon: LucideIcons.calculator500, label: 'Calculators'),
      (icon: LucideIcons.bed500, label: 'Dorm Gear'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.sparkles500,
              size: 14,
              color: UmColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'WHAT UMIANS TRADE',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                letterSpacing: 0.8,
                color: UmColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final cat in categories)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: UmColors.surface,
                  border: Border.all(color: UmColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: UmColors.ink,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, size: 14, color: UmColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      cat.label,
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                        color: UmColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
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
