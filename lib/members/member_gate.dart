import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../auth/auth_service.dart';
import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../data/report_store.dart';
import '../data/notification_store.dart';
import '../data/messaging_service.dart';
import 'package:google_fonts/google_fonts.dart';

import '../home/app_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal_loader.dart';
import '../widgets/nbr_button.dart';
import '../widgets/um_logo.dart';

/// Resolves the Member Account right after Google sign-in (ADR 0007/0008):
/// creates `members/{uid}` if missing, then routes to the app shell — or
/// the banned screen when the Admin has banned the account (ADR 0003).
class MemberGate extends StatefulWidget {
  const MemberGate({
    super.key,
    required this.authUser,
    required this.authService,
    required this.memberStore,
    required this.listingsStore,
    required this.chatStore,
    required this.ratingStore,
    required this.reportStore,
    required this.notificationStore,
    required this.messagingService,
  });

  final AuthUser authUser;
  final AuthService authService;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final RatingStore ratingStore;
  final ReportStore reportStore;
  final NotificationStore notificationStore;
  final MessagingService messagingService;

  @override
  State<MemberGate> createState() => _MemberGateState();
}

class _MemberGateState extends State<MemberGate> {
  bool _ensured = false;

  void _ensureMemberAccount() {
    if (_ensured) return;
    _ensured = true;
    // First stream emission is null while the member document does not
    // exist yet; create it (idempotent get-then-set) so the stream follows
    // with the real member. Safe after app restarts too.
    widget.memberStore.ensureMemberAccount(widget.authUser);
    // Register the device for FCM once the account exists (ADR 0005).
    widget.messagingService.registerForMember(widget.authUser.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Member?>(
      stream: widget.memberStore.memberChanges(widget.authUser.uid),
      builder: (context, snapshot) {
        final member = snapshot.data;
        if (member == null) {
          _ensureMemberAccount();
          return const _MemberSplash();
        }
        if (member.banned) {
          return BannedScreen(onSignOut: widget.authService.signOut);
        }
        return AppShell(
          member: member,
          memberStore: widget.memberStore,
          listingsStore: widget.listingsStore,
          chatStore: widget.chatStore,
          ratingStore: widget.ratingStore,
          reportStore: widget.reportStore,
          notificationStore: widget.notificationStore,
          onSignOut: () async {
            await widget.messagingService.unregister();
            await widget.authService.signOut();
          },
        );
      },
    );
  }
}

class _MemberSplash extends StatelessWidget {
  const _MemberSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: UmColors.primary,
        child: Stack(
          children: [
            // Subtle brutal grid dots
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: CustomPaint(painter: _GridPainter()),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const UmMark(size: 72),
                  const SizedBox(height: 28),
                  const BrutalLoader(size: 56, stroke: 3),
                  const SizedBox(height: 18),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: UmColors.surface,
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
                      'LOADING MARKET',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: UmColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = UmColors.gold
      ..style = PaintingStyle.fill;
    const gap = 22.0;
    const r = 1.2;
    for (double x = gap; x < size.width; x += gap) {
      for (double y = gap; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shown when the member account carries the banned flag (ADR 0003).
class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: UmColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: const Text(
                'UM MARKETPLACE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 1.2,
                  color: UmColors.onPrimary,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: UmColors.surface,
                      border: Border.all(color: UmColors.destructive, width: 2),
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
                      children: [
                        const Icon(
                          LucideIcons.ban500,
                          size: 44,
                          color: UmColors.destructive,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'This account has been banned',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your membership was reviewed by the Admin. '
                          'If you believe this is a mistake, '
                          'reach out through your university.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: UmColors.mutedForeground),
                        ),
                        const SizedBox(height: 16),
                        NbrButton(
                          label: 'Sign out',
                          fill: UmColors.surface,
                          labelColor: UmColors.ink,
                          onPressed: onSignOut,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}