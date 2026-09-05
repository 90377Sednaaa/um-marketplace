import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../chats/chats_screen.dart';
import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/notification_store.dart';
import '../data/rating_store.dart';
import '../data/report_store.dart';
import '../notifications/notification_center_screen.dart';
import '../profile/profile_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal_page_route.dart';
import '../widgets/um_logo.dart';
import 'home_screen.dart';
import 'sell_screen.dart';

/// The app shell (DESIGN.md §5): maroon brand band, an IndexedStack of the
/// four v1 tabs — Home, Sell, Chats, Profile — and the flat brutal
/// bottom nav (3dp top border, dividers, gold active block).
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.member,
    required this.memberStore,
    required this.listingsStore,
    required this.chatStore,
    required this.ratingStore,
    required this.reportStore,
    required this.notificationStore,
    required this.onSignOut,
  });

  final Member member;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final RatingStore ratingStore;
  final ReportStore reportStore;
  final NotificationStore notificationStore;
  final Future<void> Function() onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  AnimationController? _tabController;

  AnimationController get _controller => _tabController ??= AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    value: 1.0,
  );

  Animation<double> get _fadeAnimation =>
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _BrandBand(
              viewerUid: widget.member.uid,
              notificationStore: widget.notificationStore,
            ),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: IndexedStack(
                  index: _index,
                  children: [
                    HomeScreen(
                      member: widget.member,
                      memberStore: widget.memberStore,
                      listingsStore: widget.listingsStore,
                      chatStore: widget.chatStore,
                      ratingStore: widget.ratingStore,
                      reportStore: widget.reportStore,
                      onSellRequested: () => _onTabSelected(1),
                    ),
                    SellScreen(
                      sellerId: widget.member.uid,
                      sellerDisplayName: widget.member.displayName,
                      listingsStore: widget.listingsStore,
                      onPublished: () => _onTabSelected(0),
                    ),
                    ChatsScreen(
                      viewerUid: widget.member.uid,
                      chatStore: widget.chatStore,
                      memberStore: widget.memberStore,
                      listingsStore: widget.listingsStore,
                      ratingStore: widget.ratingStore,
                      reportStore: widget.reportStore,
                    ),
                    ProfileScreen(
                      member: widget.member,
                      memberStore: widget.memberStore,
                      listingsStore: widget.listingsStore,
                      chatStore: widget.chatStore,
                      ratingStore: widget.ratingStore,
                      reportStore: widget.reportStore,
                      onSignOut: widget.onSignOut,
                      onSellRequested: () => _onTabSelected(1),
                    ),
                  ],
                ),
              ),
            ),
            _BottomNav(index: _index, onSelected: _onTabSelected),
          ],
        ),
      ),
    );
  }
}

/// The maroon brand band with the notification bell (DESIGN.md screen 1:
/// "the notification bell lives in the Home app bar, never in the nav")
/// and its live unread gold sticker.
class _BrandBand extends StatelessWidget {
  const _BrandBand({required this.viewerUid, required this.notificationStore});

  final String viewerUid;
  final NotificationStore notificationStore;

  void _openCenter(BuildContext context) {
    Navigator.of(context).push(
      BrutalPageRoute<void>(
        builder: (_) => NotificationCenterScreen(
          ownerId: viewerUid,
          notificationStore: notificationStore,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: UmColors.primary,
        border: Border(bottom: BorderSide(color: UmColors.ink, width: 3)),
        boxShadow: [
          BoxShadow(color: UmColors.ink, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const UmMark(size: 32),
                const SizedBox(width: 10),
                Text(
                  'UM MARKETPLACE',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.2,
                    color: UmColors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StreamBuilder<List<AppNotification>>(
            stream: notificationStore.notificationsStream(viewerUid),
            builder: (context, snapshot) {
              final notifications = snapshot.data;
              final unread = notifications == null
                  ? 0
                  : notifications.where((n) => !n.read).length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _BellButton(onTap: () => _openCenter(context)),
                  if (unread > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: UmColors.destructive,
                          border: Border.all(color: UmColors.ink, width: 1.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            color: UmColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BellButton extends StatefulWidget {
  const _BellButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<_BellButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.linear,
        transform: Matrix4.translationValues(
          _pressed ? 2 : 0,
          _pressed ? 2 : 0,
          0,
        ),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: UmColors.gold,
          border: Border.all(color: UmColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: _pressed
              ? null
              : const [
                  BoxShadow(
                    color: UmColors.ink,
                    offset: UmShadows.small,
                    blurRadius: 0,
                  ),
                ],
        ),
        child: const Icon(LucideIcons.bell500, size: 22, color: UmColors.ink),
      ),
    );
  }
}

/// DESIGN.md §5 bottom navigation — flat brutal: white bar, 3dp ink top
/// border + 2dp vertical dividers, active = gold block with 2dp border.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      (label: 'HOME', icon: LucideIcons.house500),
      (label: 'SELL', icon: LucideIcons.squarePlus500),
      (label: 'CHATS', icon: LucideIcons.messageCircle500),
      (label: 'PROFILE', icon: LucideIcons.user500),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: UmColors.surface,
        border: Border(top: BorderSide(color: UmColors.ink, width: 3)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: i == items.length - 1
                        ? BorderSide.none
                        : const BorderSide(color: UmColors.ink, width: 2),
                  ),
                ),
                child: _NavItem(
                  label: items[i].label,
                  icon: items[i].icon,
                  active: i == index,
                  onTap: () => onSelected(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? UmColors.ink : UmColors.mutedForeground;
    final bg = widget.active ? UmColors.gold : Colors.transparent;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.linear,
        transform: Matrix4.translationValues(
          _pressed ? 2 : 0,
          _pressed ? 2 : 0,
          0,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.active ? UmColors.ink : Colors.transparent,
            width: 2,
          ),
          boxShadow: widget.active && !_pressed
              ? const [
                  BoxShadow(
                    color: UmColors.ink,
                    offset: UmShadows.small,
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.8,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
