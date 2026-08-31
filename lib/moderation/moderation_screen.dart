import 'package:flutter/material.dart';

import '../data/listing_store.dart';
import '../data/member_store.dart';
import '../data/report_store.dart';
import '../home/relative_time.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal_app_bar.dart';
import '../widgets/brutal_dialog.dart';

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
  });

  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ReportStore reportStore;

  Future<void> _hideListing(BuildContext context, Report report) async {
    try {
      if (report.listingId != null) {
        await listingsStore.hideListing(report.listingId!);
      }
      await reportStore.resolveReport(report.id);
      if (!context.mounted) return;
      await showBrutalSuccessDialog(
        context,
        title: 'Listing hidden',
        message: 'Listing hidden.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BrutalAppBar(
              title: 'MODERATION',
              leadingIcon: Icons.admin_panel_settings_outlined,
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
                                Icons.verified_outlined,
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
  });

  final Report report;
  final MemberStore memberStore;
  final VoidCallback? onHide;
  final VoidCallback? onBan;

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
          Row(
            children: [
              if (onHide != null)
                _ActionPill(
                  label: 'Hide listing',
                  fill: UmColors.surface,
                  labelColor: UmColors.ink,
                  onTap: onHide!,
                ),
              if (onHide != null && onBan != null)
                const SizedBox(width: 10),
              if (onBan != null)
                _ActionPill(
                  label: 'Ban user',
                  fill: UmColors.destructive,
                  labelColor: UmColors.onPrimary,
                  onTap: onBan!,
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
  });

  final String label;
  final Color fill;
  final Color labelColor;
  final VoidCallback onTap;

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
            child: Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: widget.labelColor,
              ),
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
            prefixIcon: const Icon(Icons.search, color: UmColors.ink),
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
  });

  final String title;
  final String body;
  final String confirmLabel;

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
            style: const TextStyle(
              color: UmColors.destructive,
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
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: UmColors.muted,
                border: Border.all(color: UmColors.ink, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }
}