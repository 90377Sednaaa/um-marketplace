import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/chat_store.dart';
import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/rating_store.dart';
import '../data/report_store.dart';
import '../home/listing_detail_screen.dart';
import '../home/relative_time.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal_app_bar.dart';
import '../widgets/brutal_dialog.dart';
import '../widgets/brutal_shimmer.dart';

/// Moderation (DESIGN.md screen 9, ADR 0003): the single Admin's console
/// — the open-reports inbox with hide-listing and ban-user actions, and
/// member lookup by display name. Unreachable for ordinary members (the
/// gate lives on the Admin's Profile row).
class ModerationScreen extends StatelessWidget {
  const ModerationScreen({
    super.key,
    required this.memberStore,
    required this.listingsStore,
    required this.reportStore,
    required this.chatStore,
    required this.ratingStore,
    required this.viewerId,
  });

  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ReportStore reportStore;
  final ChatStore chatStore;
  final RatingStore ratingStore;
  final String viewerId;

  Future<void> _hideListing(BuildContext context, Report report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Hide this listing?',
        body: 'The listing will be removed from the marketplace and the report '
            'will be cleared. This hides the content but does not ban the user.',
        confirmLabel: 'Hide listing',
        isDestructive: true,
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      if (report.listingId != null) {
        await listingsStore.hideListing(report.listingId!);
      }
      await reportStore.resolveReport(report.id);
      if (!context.mounted) return;
      await showBrutalSuccessDialog(
        context,
        title: 'Listing hidden',
        message: 'Listing hidden and report cleared.',
      );
    } catch (_) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Hide failed',
        message: 'Couldn\'t hide the listing — try again.',
      );
    }
  }

  Future<void> _dismissReport(BuildContext context, Report report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Dismiss this report?',
        body: 'Mark this report as spam or not actionable. The listing stays '
            'and the report will be cleared without hiding or banning.',
        confirmLabel: 'Dismiss',
        isDestructive: false,
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await reportStore.resolveReport(report.id);
      if (!context.mounted) return;
      await showBrutalSuccessDialog(
        context,
        title: 'Report dismissed',
        message: 'Report dismissed as spam.',
      );
    } catch (_) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Dismiss failed',
        message: 'Couldn\'t dismiss the report — try again.',
      );
    }
  }

  Future<void> _banMember(BuildContext context, Report report,
      {bool confirm = true}) async {
    final uid = report.reportedUid;
    if (uid == null) return;
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmDialog(
          title: 'Ban this member?',
          body: 'Their account loses access and their listings leave the '
              'marketplace. This can be undone from member lookup.',
          confirmLabel: 'Ban user',
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    try {
      await memberStore.setBanned(uid, true);
      await listingsStore.hideAllListingsOf(uid);
      await reportStore.resolveReport(report.id);
      if (!context.mounted) return;
      await showBrutalSuccessDialog(
        context,
        title: 'Member banned',
        message: 'Member banned — listings hidden.',
      );
    } catch (_) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Ban failed',
        message: 'Couldn\'t ban the member — try again.',
      );
    }
  }

  Future<void> _viewListing(BuildContext context, String listingId) async {
    try {
      final listing = await listingsStore.fetchListing(listingId);
      if (listing == null) {
        if (!context.mounted) return;
        await showBrutalErrorDialog(
          context,
          title: 'Not found',
          message: 'Listing not found — it may have been removed.',
        );
        return;
      }
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ListingDetailScreen(
            listing: listing,
            memberStore: memberStore,
            listingsStore: listingsStore,
            chatStore: chatStore,
            ratingStore: ratingStore,
            reportStore: reportStore,
            viewerId: viewerId,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Failed',
        message: 'Could not open listing — try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BrutalAppBar(
              title: 'MODERATION',
              leadingIcon: LucideIcons.shieldCheck500,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Open reports',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Report>>(
                    stream: reportStore.openReportsStream(),
                    builder: (context, snapshot) {
                      final reports = snapshot.data;
                      if (reports == null) {
                        return const _ReportsSkeleton();
                      }
                      if (reports.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: UmColors.surface,
                            border:
                                Border.all(color: UmColors.ink, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                LucideIcons.badgeCheck500,
                                size: 44,
                                color: UmColors.mutedForeground,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No open reports — the inbox is clear.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final report in reports)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ReportCard(
                                report: report,
                                memberStore: memberStore,
                                onHide: report.listingId != null
                                    ? () => _hideListing(context, report)
                                    : null,
                                onBan: report.reportedUid != null
                                    ? () =>
                                        _banMember(context, report)
                                    : null,
                                onView: report.listingId != null
                                    ? () => _viewListing(
                                        context, report.listingId!)
                                    : null,
                                onDismiss: () =>
                                    _dismissReport(context, report),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Find a member',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  _MemberSearch(
                    memberStore: memberStore,
                    listingsStore: listingsStore,
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

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.memberStore,
    required this.onHide,
    required this.onBan,
    required this.onView,
    required this.onDismiss,
  });

  final Report report;
  final MemberStore memberStore;
  final VoidCallback? onHide;
  final VoidCallback? onBan;
  final VoidCallback? onView;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final target = report.listingId != null
        ? 'Listing: ${report.listingId}'
        : 'Chat: ${report.chatId ?? '?'}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.reason,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 15),
                ),
              ),
              if (report.createdAt != null)
                Text(
                  formatRelativeTime(report.createdAt!),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: UmColors.mutedForeground,
                        fontSize: 11.5,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            target,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: UmColors.mutedForeground,
                ),
          ),
          const SizedBox(height: 2),
          StreamBuilder<Member?>(
            stream: memberStore.memberChanges(report.reporterId),
            builder: (context, snapshot) {
              return Text(
                'Reported by ${snapshot.data?.displayName ?? report.reporterId}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: UmColors.mutedForeground,
                      fontSize: 12,
                    ),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (onView != null)
                _ActionPill(
                  label: 'View listing',
                  fill: UmColors.goldSoft,
                  labelColor: UmColors.ink,
                  icon: LucideIcons.eye500,
                  onTap: onView!,
                ),
              if (onHide != null)
                _ActionPill(
                  label: 'Hide listing',
                  fill: UmColors.surface,
                  labelColor: UmColors.ink,
                  icon: LucideIcons.eyeOff500,
                  onTap: onHide!,
                ),
              if (onBan != null)
                _ActionPill(
                  label: 'Ban user',
                  fill: UmColors.destructive,
                  labelColor: UmColors.onPrimary,
                  icon: LucideIcons.ban500,
                  onTap: onBan!,
                ),
              _ActionPill(
                label: 'Dismiss',
                fill: UmColors.surface,
                labelColor: UmColors.mutedForeground,
                icon: LucideIcons.x500,
                onTap: onDismiss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatefulWidget {
  const _ActionPill({
    required this.label,
    required this.fill,
    required this.labelColor,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color fill;
  final Color labelColor;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_ActionPill> createState() => _ActionPillState();
}

class _ActionPillState extends State<_ActionPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: UmColors.ink,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            curve: Curves.linear,
            transform: Matrix4.translationValues(
              _pressed ? 0 : 3,
              _pressed ? 0 : 3,
              0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: widget.fill,
              border: Border.all(color: UmColors.ink, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 14, color: widget.labelColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: widget.labelColor,
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

class _MemberSearch extends StatefulWidget {
  const _MemberSearch({
    required this.memberStore,
    required this.listingsStore,
  });

  final MemberStore memberStore;
  final ListingStore listingsStore;

  @override
  State<_MemberSearch> createState() => _MemberSearchState();
}

class _MemberSearchState extends State<_MemberSearch> {
  final _query = TextEditingController();
  String _prefix = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _query,
          onChanged: (value) => setState(() => _prefix = value.trim()),
          decoration: InputDecoration(
            hintText: 'Display name…',
            prefixIcon: const Icon(LucideIcons.search500, color: UmColors.ink),
            filled: true,
            fillColor: UmColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: UmColors.ink, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: UmColors.ink, width: 2),
            ),
          ),
        ),
        if (_prefix.isNotEmpty)
          StreamBuilder<List<Member>>(
            stream: widget.memberStore.searchMembers(_prefix),
            builder: (context, snapshot) {
              final members = snapshot.data;
              if (members == null) {
                return const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(
                    child: Text('Searching…',
                        style: TextStyle(color: UmColors.mutedForeground)),
                  ),
                );
              }
              if (members.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Text(
                      'No members match.',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: UmColors.mutedForeground),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final member in members)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _MemberRow(
                        member: member,
                        store: widget.memberStore,
                        listingsStore: widget.listingsStore,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _MemberRow extends StatefulWidget {
  const _MemberRow({
    required this.member,
    required this.store,
    required this.listingsStore,
  });

  final Member member;
  final MemberStore store;
  final ListingStore listingsStore;

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  late Member _member = widget.member;
  bool _busy = false;

  Future<void> _toggleBan(BuildContext context) async {
    if (_busy) return;
    final banning = !_member.banned;
    if (banning) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmDialog(
          title: 'Ban this member?',
          body: '${_member.displayName}\'s account loses access and their '
              'listings leave the marketplace. This can be undone from '
              'this lookup.',
          confirmLabel: 'Ban user',
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await widget.store.setBanned(_member.uid, banning);
      if (banning) await widget.listingsStore.hideAllListingsOf(_member.uid);
      setState(() {
        _member = Member(
          uid: _member.uid,
          email: _member.email,
          displayName: _member.displayName,
          isAdmin: _member.isAdmin,
          banned: banning,
          blocked: _member.blocked,
        );
      });
      if (!context.mounted) return;
      await showBrutalSuccessDialog(
        context,
        title: banning ? 'Member banned' : 'Member unbanned',
        message: banning
            ? 'Member banned — listings hidden.'
            : 'Member unbanned.',
      );
    } catch (_) {
      if (!context.mounted) return;
      await showBrutalErrorDialog(
        context,
        title: 'Update failed',
        message: 'Couldn\'t update the member — try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UmColors.surface,
        border: Border.all(color: UmColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: UmColors.ink, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: UmColors.gold,
            child: Text(
              _member.displayName.isEmpty
                  ? '?'
                  : _member.displayName[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: UmColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _member.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_member.banned)
                  Text(
                    'Banned',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: UmColors.destructive,
                          fontSize: 11.5,
                        ),
                  ),
              ],
            ),
          ),
          _ActionPill(
            label: _member.banned ? 'Unban' : 'Ban user',
            fill: _member.banned ? UmColors.gold : UmColors.destructive,
            labelColor: UmColors.ink,
            onTap: () => _toggleBan(context),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.isDestructive = true,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: UmColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: UmColors.ink, width: 2),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: UmColors.onSurface,
        ),
      ),
      content: Text(body, style: Theme.of(context).textTheme.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: UmColors.ink, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: isDestructive ? UmColors.destructive : UmColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return BrutalShimmer(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: UmColors.surface,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        BrutalSkeletonBox(
                          height: 18,
                          width: 80,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        BrutalSkeletonBox(
                          height: 12,
                          width: 40,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const BrutalSkeletonBox(
                      height: 14,
                      width: 160,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        BrutalSkeletonBox(
                          height: 28,
                          width: 90,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                          hasBorder: true,
                        ),
                        SizedBox(width: 8),
                        BrutalSkeletonBox(
                          height: 28,
                          width: 80,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                          hasBorder: true,
                        ),
                      ],
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