import 'package:flutter/material.dart';

import '../chats/chats_screen.dart';
import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../profile/profile_screen.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'sell_screen.dart';

/// The app shell (DESIGN.md §5): maroon brand band, an IndexedStack of the
/// four v1 tabs — Home, Sell, Chats, Profile — and the neubrutalist
/// bottom nav.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.member,
    required this.memberStore,
    required this.listingsStore,
    required this.chatStore,
    required this.onSignOut,
  });

  final Member member;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final Future<void> Function() onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _BrandBand(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  HomeScreen(
                    member: widget.member,
                    memberStore: widget.memberStore,
                    listingsStore: widget.listingsStore,
                    chatStore: widget.chatStore,
                    onSignOut: widget.onSignOut,
                    onSellRequested: () => setState(() => _index = 1),
                  ),
                  SellScreen(
                    sellerId: widget.member.uid,
                    listingsStore: widget.listingsStore,
                    onPublished: () => setState(() => _index = 0),
                  ),
                  ChatsScreen(
                    viewerUid: widget.member.uid,
                    chatStore: widget.chatStore,
                    memberStore: widget.memberStore,
                    listingsStore: widget.listingsStore,
                  ),
                  ProfileScreen(
                    member: widget.member,
                    memberStore: widget.memberStore,
                    listingsStore: widget.listingsStore,
                    chatStore: widget.chatStore,
                  ),
                ],
              ),
            ),
            _BottomNav(
              index: _index,
              onSelected: (i) => setState(() => _index = i),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandBand extends StatelessWidget {
  const _BrandBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
    );
  }
}

/// DESIGN.md §5 bottom navigation: white bar with a 2 dp ink top border;
/// the active item sits on a `goldSoft` pill with maroon icon + label,
/// inactive items are `mutedForeground`.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      (label: 'Home', icon: Icons.home_outlined),
      (label: 'Sell', icon: Icons.add_box_outlined),
      (label: 'Chats', icon: Icons.chat_bubble_outline),
      (label: 'Profile', icon: Icons.person_outline),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: UmColors.surface,
        border: Border(top: BorderSide(color: UmColors.ink, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _NavItem(
                label: items[i].label,
                icon: items[i].icon,
                active: i == index,
                onTap: () => onSelected(i),
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
    final color = widget.active ? UmColors.primary : UmColors.mutedForeground;
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
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.active ? UmColors.goldSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: TextStyle(
                fontWeight: widget.active ? FontWeight.w700 : FontWeight.w600,
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}