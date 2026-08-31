import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/notification_store.dart';
import '../home/relative_time.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal_app_bar.dart';

/// Notification center (DESIGN.md screen 8): pushed from the Home bell;
/// lists the member's notifications with unread rows marked by a gold
/// NEW sticker; tapping reads. Event generation lands with the FCM +
/// Functions stage (ADR 0005) — until then the list is read-only.
class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({
    super.key,
    required this.ownerId,
    required this.notificationStore,
  });

  final String ownerId;
  final NotificationStore notificationStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BrutalAppBar(
              title: 'NOTIFICATIONS',
              leadingIcon: LucideIcons.bell500,
            ),
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: notificationStore.notificationsStream(ownerId),
                builder: (context, snapshot) {
                  final notifications = snapshot.data;
                  if (notifications == null) {
                    return const _NotificationsSkeleton();
                  }
                  if (notifications.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.bellOff500,
                              size: 48,
                              color: UmColors.mutedForeground,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nothing here yet — offers, messages, sold '
                              'items, and ratings will land here.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final notification in notifications)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _NotificationRow(
                            notification: notification,
                            onTap: notification.read
                                ? null
                                : () =>
                                    notificationStore.markRead(notification.id),
                          ),
                        ),
                    ],
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

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  static const Map<String, IconData> _typeIcons = {
    'offer': LucideIcons.handCoins500,
    'message': LucideIcons.messageCircle500,
    'sold': LucideIcons.tag500,
    'rating': LucideIcons.star500,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: UmColors.surface,
          border: Border.all(color: UmColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: UmColors.ink,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: UmColors.goldSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _typeIcons[notification.type] ?? LucideIcons.bell500,
                size: 20,
                color: UmColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: UmColors.mutedForeground,
                          fontSize: 13,
                        ),
                  ),
                  if (notification.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      formatRelativeTime(notification.createdAt!),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: UmColors.mutedForeground,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!notification.read)
              Transform.rotate(
                // −2° sticker energy (DESIGN.md §4)
                angle: -0.035,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: UmColors.gold,
                    border: Border.all(color: UmColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: UmColors.ink,
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

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 84,
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